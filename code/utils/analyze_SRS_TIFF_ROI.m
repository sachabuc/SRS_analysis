
function results = analyze_SRS_TIFF_ROI(filename, cfg)
% ANALYZE_SRS_TIFF_ROI
% Première analyse interactive d'un fichier TIFF SRS multipage.
%
% Fonctionnalités :
%   1. Lecture du TIFF et des métadonnées LabVIEW/ImageJ.
%   2. Réorganisation des pages en [Y X L Z].
%   3. Sélection manuelle d'une ROI background et d'une ROI signal.
%   4. Extraction des spectres moyens pour chaque position Z.
%   5. Soustraction du background.
%   6. Fit de 3 gaussiennes libres + fond linéaire.
%   7. Visualisation interactive des spectres avec un curseur Z.
%
% Utilisation :
%   results = analyze_SRS_TIFF_ROI;
%   results = analyze_SRS_TIFF_ROI(filename);
%   results = analyze_SRS_TIFF_ROI(filename, cfg);
%
% Configuration facultative :
%   cfg.pageOrder = 'auto';   % 'auto', 'LZ' ou 'ZL'
%   cfg.wavenumber = [];      % Axe Raman directement en cm-1
%   cfg.wl_ir_nm = [];        % Longueur d'onde du faisceau IR/Stokes
%   cfg.fitRange = [1050 1120];
%   cfg.nGauss = 3;
%
% Sortie :
%   results.spectrum_signal       [L x Z]
%   results.spectrum_bg           [L x Z]
%   results.spectrum_corrected    [L x Z]
%   results.fit.parameters        [Z x 3 x 3]
%   results.fit.fitted             [L x Z]
%   results.fit.components        [L x Z x 3]
%
% Convention :
%   Les données sont organisées en [Y X L Z].
%   T = 1 pour cette version.

if nargin < 1 || isempty(filename)
    [file, path] = uigetfile( ...
        {'*.tif;*.tiff', 'TIFF files (*.tif, *.tiff)'}, ...
        'Sélectionner une acquisition SRS');

    if isequal(file, 0)
        error('Aucun fichier sélectionné.');
    end

    filename = fullfile(path, file);
end

if nargin < 2 || isempty(cfg)
    cfg = struct();
end

%% ============================================================
% 1. CONFIGURATION
% =============================================================

cfg = setDefault(cfg, 'pageOrder', 'auto');
cfg = setDefault(cfg, 'wavenumber', []);
cfg = setDefault(cfg, 'wl_ir_nm', []);
cfg = setDefault(cfg, 'fitRange', [1050 1120]);
cfg = setDefault(cfg, 'nGauss', 3);
cfg = setDefault(cfg, 'showIndividualFits', true);

if cfg.nGauss < 1 || cfg.nGauss ~= round(cfg.nGauss)
    error('cfg.nGauss doit être un entier positif.');
end

fprintf('\n========================================\n');
fprintf(' Analyse SRS TIFF - ROI et fits spectraux\n');
fprintf('========================================\n');

%% ============================================================
% 2. LECTURE DU TIFF ET DES METADONNEES
% =============================================================

fprintf('\nLecture du fichier TIFF...\n');

info = imfinfo(filename);
nPages = numel(info);

if nPages < 1
    error('Le fichier TIFF ne contient aucune image.');
end

meta = extractSRSMetadata(info(1));

% Dimensions spatiales
nX = getMetaNumber(meta, {'X'}, info(1).Width);
nY = getMetaNumber(meta, {'Y'}, info(1).Height);

% Dimensions spectrale et Z
scanType = upper(char(getMetaValue(meta, ...
    {'scan_type'}, 'XYL')));

nL = getMetaNumber(meta, {'L'}, 1);
nZ = getMetaNumber(meta, {'Z'}, 1);

% Certaines métadonnées contiennent "N/A"
if nL < 1
    nL = 1;
end

if nZ < 1
    nZ = 1;
end

% Timepoints : on conserve uniquement T = 1
nT = getMetaNumber(meta, {'timepoints'}, 1);

fprintf('Type de scan : %s\n', scanType);
fprintf('Dimensions : X=%d, Y=%d, L=%d, Z=%d, T=%d\n', ...
    nX, nY, nL, nZ, nT);
fprintf('Nombre de pages TIFF : %d\n', nPages);

if nT > 1
    warning(['Acquisition avec %d timepoints détectée. ', ...
        'Seul T=1 sera conservé.'], nT);
end

%% ============================================================
% 3. DETERMINATION DE L'ORDRE DES PAGES
% =============================================================

if strcmpi(cfg.pageOrder, 'auto')

    % L'ordre de stockage est déduit directement du scan_type LabVIEW.
    % XYLZ : L varie avant Z ; XYZL : Z varie avant L.
    switch scanType
        case 'XYLZ'
            pageOrder = 'LZ';
        case 'XYZL'
            pageOrder = 'ZL';
        case 'XYL'
            pageOrder = 'LZ';
        case 'XYZ'
            pageOrder = 'ZL';
        otherwise
            error('scan_type non reconnu dans les métadonnées : %s', scanType);
    end

else
    pageOrder = upper(cfg.pageOrder);
end

if ~ismember(pageOrder, {'LZ', 'ZL'})
    error('pageOrder doit être ''auto'', ''LZ'' ou ''ZL''.');
end

fprintf('Ordre des pages utilisé : %s\n', pageOrder);

nPagesPerT = nL * nZ;

if nPages < nPagesPerT
    error(['Nombre de pages insuffisant : %d pages disponibles, ', ...
        '%d nécessaires pour L=%d et Z=%d.'], ...
        nPages, nPagesPerT, nL, nZ);
end

%% ============================================================
% 4. LECTURE DES IMAGES
% =============================================================

fprintf('\nChargement des images...\n');

% Format canonique : [Y X L Z]
data = zeros(nY, nX, nL, nZ, 'double');

for k = 1:nPagesPerT

    I = double(imread(filename, k));

    if ~isequal(size(I), [nY nX])
        error('Dimensions incorrectes pour la page TIFF %d.', k);
    end

    if strcmp(pageOrder, 'LZ')

        % L varie le plus rapidement
        [iL, iZ] = ind2sub([nL nZ], k);

    else

        % Z varie le plus rapidement
        [iZ, iL] = ind2sub([nZ nL], k);

    end

    data(:, :, iL, iZ) = I;

end

fprintf('Chargement terminé.\n');

%% ============================================================
% 5. AXE RAMAN
% =============================================================

wavenumber = getRamanAxis(meta, cfg, nL);

% Tri croissant de l'axe Raman
[wavenumber, sortIdx] = sort(wavenumber(:));

data = data(:, :, sortIdx, :);

if numel(wavenumber) ~= nL
    error('La taille de l''axe Raman ne correspond pas à L.');
end

fprintf('Axe Raman : %.2f à %.2f cm-1\n', ...
    min(wavenumber), max(wavenumber));

%% ============================================================
% 6. IMAGE DE REFERENCE ET SELECTION DES ROI
% =============================================================

manualROI = ~isempty(cfg.ROI_signal) && ...
            ~isempty(cfg.ROI_background);

if manualROI

    roi_signal = cfg.ROI_signal;
    roi_bg     = cfg.ROI_background;

    posSignal = [roi_signal(1), roi_signal(3), ...
             roi_signal(2)-roi_signal(1)+1, ...
             roi_signal(4)-roi_signal(3)+1];

    posBG = [roi_bg(1), roi_bg(3), ...
                 roi_bg(2)-roi_bg(1)+1, ...
                 roi_bg(4)-roi_bg(3)+1];

    referenceImage = mean(data(:,:,:,1), 3, 'omitnan');

    % Vérification des coordonnées
    roiList = {roi_signal, roi_bg};
    roiNames = {'signal', 'background'};

    for k = 1:2
        roi = roiList{k};

        if numel(roi) ~= 4 || any(~isfinite(roi)) || ...
           roi(1) < 1 || roi(3) < 1 || ...
           roi(2) > size(data,2) || ...
           roi(4) > size(data,1) || ...
           roi(1) > roi(2) || roi(3) > roi(4)

            error('Coordonnées invalides pour la ROI %s.', roiNames{k});
        end
    end

    % Création des masques
    maskSignal = false(size(data,1), size(data,2));
    maskBG     = false(size(data,1), size(data,2));

    maskSignal(roi_signal(3):roi_signal(4), ...
                   roi_signal(1):roi_signal(2)) = true;

    maskBG(roi_bg(3):roi_bg(4), ...
               roi_bg(1):roi_bg(2)) = true;

    fprintf('\nROI définies manuellement :\n');
    fprintf('  Signal     : [%d %d %d %d]\n', roi_signal);
    fprintf('  Background : [%d %d %d %d]\n', roi_bg);

else


    fprintf('\nSélection des ROI...\n');
    
    % Image moyenne sur L et Z
    referenceImage = mean(data, [3 4], 'omitnan');
    
    figROI = figure( ...
        'Name', 'Sélection des ROI', ...
        'NumberTitle', 'off', ...
        'Color', 'w');
    
    axROI = axes(figROI);
    
    imagesc(axROI, referenceImage);
    axis(axROI, 'image');
    colormap(axROI, parula(256));
    colorbar(axROI);
    
    xlabel(axROI, 'X (pixels)');
    ylabel(axROI, 'Y (pixels)');
    title(axROI, ...
        {'Sélectionner le ROI background', ...
        'Double-cliquer pour valider le rectangle'});
    
    % ROI background
    hBG = drawrectangle(axROI, ...
        'Color', 'cyan', ...
        'LineWidth', 1.5);
    
    wait(hBG);
    
    posBG = hBG.Position;
    
    title(axROI, ...
        {'Sélectionner le ROI signal', ...
        'Double-cliquer pour valider le rectangle'});
    
    % ROI signal
    hSignal = drawrectangle(axROI, ...
        'Color', 'red', ...
        'LineWidth', 1.5);
    
    wait(hSignal);
    
    posSignal = hSignal.Position;
    
    % Conversion des rectangles en masques
    maskBG = rectangleToMask(posBG, nY, nX);
    maskSignal = rectangleToMask(posSignal, nY, nX);
    
    if ~any(maskBG(:)) || ~any(maskSignal(:))
        error('Une des ROI est vide.');
    end
    
    if any(maskBG(:) & maskSignal(:))
        warning('Les deux ROI se chevauchent.');
    end
    
    nPixBG = nnz(maskBG);
    nPixSignal = nnz(maskSignal);
    
    fprintf('ROI background : %d pixels\n', nPixBG);
    fprintf('ROI signal : %d pixels\n', nPixSignal);

end

%% ============================================================
% 7. EXTRACTION DES SPECTRES POUR CHAQUE Z
% =============================================================

fprintf('\nExtraction des spectres...\n');

spectrumSignal = zeros(nL, nZ);
spectrumBG = zeros(nL, nZ);

for iz = 1:nZ

    currentData = data(:, :, :, iz);

    for iL = 1:nL

        currentImage = currentData(:, :, iL);

        spectrumSignal(iL, iz) = ...
            mean(currentImage(maskSignal), 'omitnan');

        spectrumBG(iL, iz) = ...
            mean(currentImage(maskBG), 'omitnan');

    end

end

% Soustraction du background
spectrumCorrected = spectrumSignal - spectrumBG;

%% ============================================================
% 8. FIT MULTI-GAUSSIEN
% =============================================================

fprintf('\nAjustement des spectres...\n');

fit = struct();

fit.parameters = nan(nZ, cfg.nGauss, 3);
fit.fitted = nan(nL, nZ);
fit.components = nan(nL, nZ, cfg.nGauss);

fit.R2 = nan(nZ, 1);
fit.RMSE = nan(nZ, 1);
fit.AUC = nan(nZ, 1);
fit.peakAmplitude = nan(nZ, 1);
fit.FWHM_total = nan(nZ, 1);
fit.success = false(nZ, 1);

fit.background = nan(nL, nZ);

for iz = 1:nZ

    y = spectrumCorrected(:, iz);

    try

        fitResult = fitCarbonateSpectrum( ...
            wavenumber, y, cfg);

        fit.parameters(iz, :, :) = fitResult.parameters;
        fit.fitted(:, iz) = fitResult.fitted;
        fit.components(:, iz, :) = fitResult.components;

        fit.R2(iz) = fitResult.R2;
        fit.RMSE(iz) = fitResult.RMSE;
        fit.AUC(iz) = fitResult.AUC;
        fit.peakAmplitude(iz) = fitResult.peakAmplitude;
        fit.FWHM_total(iz) = fitResult.FWHM_total;
        fit.success(iz) = true;

        fit.background(:, iz) = fitResult.background;

    catch ME

        warning('Fit échoué pour Z=%d : %s', iz, ME.message);

    end

end

fprintf('Fits terminés : %d/%d réussis.\n', ...
    nnz(fit.success), nZ);

%% ============================================================
% 8.bis ANALYSE STATISTIQUE DES FITS
% =============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('             ANALYSE STATISTIQUE DES FITS\n');
fprintf('============================================================\n');

% Positions Z pour lesquelles le fit a réussi
validFits = fit.success;
nValid = nnz(validFits);

fprintf('\nNombre de fits réussis : %d / %d (%.1f %%)\n', ...
    nValid, nZ, 100*nValid/max(nZ,1));

if nValid == 0
    warning('Aucun fit valide : analyse statistique impossible.');

else

    %% --------------------------------------------------------
    % 1. Statistiques globales
    % ---------------------------------------------------------

    metricNames = {'R2', 'RMSE', 'AUC', ...
                   'Peak amplitude', 'FWHM total'};

    metricData = { ...
        fit.R2(validFits), ...
        fit.RMSE(validFits), ...
        fit.AUC(validFits), ...
        fit.peakAmplitude(validFits), ...
        fit.FWHM_total(validFits)};

    fprintf('\n--- STATISTIQUES GLOBALES ---\n');
    fprintf('%-20s %12s %12s %12s %12s %8s\n', ...
        'Paramètre', 'Moyenne', 'Médiane', 'Std', 'SEM', 'N');

    for k = 1:numel(metricNames)

        values = metricData{k};
        values = values(isfinite(values));

        N = numel(values);

        if N == 0
            continue
        end

        avg = mean(values);
        med = median(values);
        sd = std(values);
        sem = sd/sqrt(N);

        fprintf('%-20s %12.4g %12.4g %12.4g %12.4g %8d\n', ...
            metricNames{k}, avg, med, sd, sem, N);

    end


    %% --------------------------------------------------------
    % 2. Statistiques des composantes gaussiennes
    % ---------------------------------------------------------

    fprintf('\n--- STATISTIQUES DES GAUSSIENNES ---\n');

    for iG = 1:cfg.nGauss

        % Extraction des paramètres :
        % colonne 1 = amplitude
        % colonne 2 = centre
        % colonne 3 = FWHM

        amplitudes = squeeze(fit.parameters(validFits, iG, 1));
        centers = squeeze(fit.parameters(validFits, iG, 2));
        widths = squeeze(fit.parameters(validFits, iG, 3));

        amplitudes = amplitudes(:);
        centers = centers(:);
        widths = widths(:);

        fprintf('\nGaussienne %d\n', iG);

        parameterNames = {'Amplitude', 'Centre (cm-1)', 'FWHM (cm-1)'};
        parameterData = {amplitudes, centers, widths};

        fprintf('%-18s %12s %12s %12s %12s %8s\n', ...
            'Paramètre', 'Moyenne', 'Médiane', 'Std', 'SEM', 'N');

        for k = 1:3

            values = parameterData{k};
            values = values(isfinite(values));

            N = numel(values);

            if N == 0
                continue
            end

            avg = mean(values);
            med = median(values);
            sd = std(values);
            sem = sd/sqrt(N);

            fprintf('%-18s %12.4g %12.4g %12.4g %12.4g %8d\n', ...
                parameterNames{k}, avg, med, sd, sem, N);

        end

    end


    %% --------------------------------------------------------
    % 3. Tableau récapitulatif pour chaque position Z
    % ---------------------------------------------------------

    fprintf('\n--- RESULTATS INDIVIDUELS SELON Z ---\n');

    fprintf('%5s %10s %12s %12s %12s %12s\n', ...
        'Z', 'Fit', 'R2', 'RMSE', 'AUC', 'FWHM');

    for iz = 1:nZ

        if fit.success(iz)

            fprintf('%5d %10s %12.4f %12.4g %12.4g %12.4f\n', ...
                iz, 'OK', ...
                fit.R2(iz), ...
                fit.RMSE(iz), ...
                fit.AUC(iz), ...
                fit.FWHM_total(iz));

        else

            fprintf('%5d %10s %12s %12s %12s %12s\n', ...
                iz, 'FAILED', '-', '-', '-', '-');

        end

    end

end

fprintf('\n============================================================\n');
fprintf('                 FIN DE L''ANALYSE\n');
fprintf('============================================================\n\n');

%% ============================================================
% 9. STRUCTURE DE SORTIE
% =============================================================

results = struct();

results.filename = filename;
results.metadata = meta;
results.scan_type = scanType;
results.pageOrder = pageOrder;

results.dimensions = struct( ...
    'X', nX, ...
    'Y', nY, ...
    'L', nL, ...
    'Z', nZ, ...
    'T', 1);

results.wavenumber = wavenumber;

results.data = data;

results.roi_signal = maskSignal;
results.roi_background = maskBG;

results.roi_position_signal = posSignal;
results.roi_position_background = posBG;

results.spectrum_signal = spectrumSignal;
results.spectrum_bg = spectrumBG;
results.spectrum_corrected = spectrumCorrected;

results.fit = fit;

%% ============================================================
% 10. INTERFACE GRAPHIQUE INTERACTIVE
% =============================================================

createInteractivePlot(results, referenceImage);

fprintf('\nAnalyse terminée.\n');

end


%% ============================================================
% FONCTIONS AUXILIAIRES
% =============================================================

function cfg = setDefault(cfg, field, value)

if ~isfield(cfg, field) || isempty(cfg.(field))
    cfg.(field) = value;
end

end


%% ------------------------------------------------------------
function meta = extractSRSMetadata(info)

meta = struct();

if ~isfield(info, 'ImageDescription')
    return
end

description = char(info.ImageDescription);

% Extraction du nombre de timepoints ImageJ
tokens = regexp(description, 'frames=(\d+)', ...
    'tokens', 'once');

if ~isempty(tokens)
    meta.timepoints = str2double(tokens{1});
else
    meta.timepoints = 1;
end

% Extraction du JSON LabVIEW
marker = 'Info=LABVIEW_RAMAN|';

idx = strfind(description, marker);

if isempty(idx)
    return
end

startIndex = idx(1) + length(marker);

jsonText = strtrim(description(startIndex:end));

endJSON = find(jsonText == '}', 1, 'last');

if ~isempty(endJSON)
    jsonText = jsonText(1:endJSON);
end

try

    labviewMeta = jsondecode(jsonText);

    fields = fieldnames(labviewMeta);

    for k = 1:numel(fields)
        meta.(fields{k}) = labviewMeta.(fields{k});
    end

catch ME

    warning('Impossible de décoder les métadonnées LabVIEW : %s', ...
        ME.message);

end

end


%% ------------------------------------------------------------
function value = getMetaValue(meta, names, defaultValue)

value = defaultValue;

for k = 1:numel(names)

    if isfield(meta, names{k})

        candidate = meta.(names{k});

        if ~isempty(candidate)
            value = candidate;
            return
        end

    end

end

end


%% ------------------------------------------------------------
function value = getMetaNumber(meta, names, defaultValue)

rawValue = getMetaValue(meta, names, defaultValue);

if isnumeric(rawValue) && isscalar(rawValue)

    value = double(rawValue);

elseif ischar(rawValue) || isstring(rawValue)

    value = str2double(rawValue);

else

    value = defaultValue;

end

if ~isfinite(value) || value < 1
    value = defaultValue;
end

value = round(value);

end


%% ------------------------------------------------------------
function wavenumber = getRamanAxis(meta, cfg, nL)

% Priorité 1 : axe Raman fourni directement
if ~isempty(cfg.wavenumber)
    wavenumber = cfg.wavenumber(:);
    if numel(wavenumber) ~= nL
        error('cfg.wavenumber doit contenir exactement L valeurs.');
    end
    return
end

% Bornes spectrales lues directement dans les métadonnées.
% On ne passe pas par getMetaNumber car cette fonction arrondit les valeurs,
% ce qui serait incorrect pour des longueurs d'onde décimales.
min_wl = getMetaScalar(meta, {'min_wl', 'Lambda_min_nm'}, NaN);
max_wl = getMetaScalar(meta, {'max_wl', 'Lambda_max_nm'}, NaN);

if ~isfinite(min_wl) || ~isfinite(max_wl)
    error(['Impossible de construire l''axe spectral : les métadonnées ', ...
        'doivent contenir min_wl et max_wl (ou Lambda_min_nm et ', ...
        'Lambda_max_nm).']);
end

% Longueurs d'onde échantillonnées
wavelengths_data = linspace(min_wl, max_wl, nL);

% Conversion en décalage Raman, avec lambda Stokes/IR fixé à 1031.3 nm
wavenumber_data = 1e7 ./ wavelengths_data - 1e7 ./ 1031.3;

wavenumber = wavenumber_data(:);

end


%% ------------------------------------------------------------
function value = getMetaScalar(meta, names, defaultValue)

value = defaultValue;

for k = 1:numel(names)
    if isfield(meta, names{k})
        candidate = meta.(names{k});

        if isnumeric(candidate) && isscalar(candidate)
            candidate = double(candidate);
        elseif ischar(candidate) || (isstring(candidate) && isscalar(candidate))
            candidate = str2double(candidate);
        else
            continue
        end

        if isfinite(candidate)
            value = candidate;
            return
        end
    end
end

end

%% ------------------------------------------------------------
function mask = rectangleToMask(position, nY, nX)

x1 = max(1, floor(position(1)));
y1 = max(1, floor(position(2)));

x2 = min(nX, ceil(position(1) + position(3)));
y2 = min(nY, ceil(position(2) + position(4)));

mask = false(nY, nX);

if x2 < x1 || y2 < y1
    return
end

mask(y1:y2, x1:x2) = true;

end


%% ------------------------------------------------------------
function result = fitCarbonateSpectrum(x, y, cfg)

x = x(:);
y = y(:);

valid = isfinite(x) & isfinite(y) & ...
    x >= cfg.fitRange(1) & x <= cfg.fitRange(2);

xFit = x(valid);
yFit = y(valid);

if numel(xFit) < 10
    error('Pas assez de points spectraux dans la zone de fit.');
end

nG = cfg.nGauss;

% Modèle :
% p = [A1 mu1 w1 A2 mu2 w2 ... B0 B1]

% Centres initiaux répartis sur la zone de fit
initialCenters = linspace(1075, 1100, nG);

if nG == 1
    initialCenters = mean(cfg.fitRange);
end

% Initialisation du fond
nEdge = max(2, round(0.1 * numel(yFit)));

xEdge = [xFit(1:nEdge); xFit(end-nEdge+1:end)];
yEdge = [yFit(1:nEdge); yFit(end-nEdge+1:end)];

pBackground = polyfit(xEdge - mean(xFit), yEdge, 1);

B1_0 = pBackground(1);
B0_0 = pBackground(2);

yBaseline = B0_0 + B1_0 .* (xFit - mean(xFit));

signalMax = max(yFit - yBaseline);

if ~isfinite(signalMax) || signalMax <= 0
    signalMax = max(abs(yFit));
end

if signalMax <= 0
    signalMax = 1;
end

% Initialisation des paramètres
p0 = zeros(1, 3*nG + 2);

lb = -inf(size(p0));
ub = inf(size(p0));

for i = 1:nG

    idx = 3*(i-1) + (1:3);

    p0(idx) = [signalMax/nG, initialCenters(i), 8];

    lb(idx) = [0, 1055, 1];
    ub(idx) = [10*signalMax, 1115, 60];

end

p0(end-1:end) = [B0_0, B1_0];

% Modèle de fit
model = @(p, xx) carbonateModel(p, xx, nG);

% Optimisation
if exist('lsqcurvefit', 'file') == 2

    try

        options = optimset( ...
            'Display', 'off', ...
            'MaxIter', 300, ...
            'MaxFunEvals', 3000);

        p = lsqcurvefit(model, p0, xFit, yFit, ...
            lb, ub, options);

    catch

        % Repli en cas d'erreur de lsqcurvefit
        p = boundedFitFminsearch( ...
            model, p0, xFit, yFit, lb, ub);

    end

else

    p = boundedFitFminsearch( ...
        model, p0, xFit, yFit, lb, ub);

end

% Trier les composantes par centre spectral
parameters = reshape(p(1:3*nG), 3, nG).';

[~, order] = sort(parameters(:, 2));

parameters = parameters(order, :);

% Reconstruire le vecteur de paramètres trié
pSorted = zeros(size(p));

for i = 1:nG
    pSorted(3*(i-1)+(1:3)) = parameters(i, :);
end

pSorted(end-1:end) = p(end-1:end);

% Calcul sur tout l'axe spectral
fitted = carbonateModel(pSorted, x, nG);

components = zeros(numel(x), nG);

for i = 1:nG

    A = parameters(i, 1);
    mu = parameters(i, 2);
    w = parameters(i, 3);

    components(:, i) = A .* exp( ...
        -4*log(2) .* ((x-mu)./w).^2);

end

background = pSorted(end-1) + ...
    pSorted(end) .* (x - mean(xFit));

% Qualité du fit sur la zone sélectionnée
yModel = carbonateModel(pSorted, xFit, nG);

residual = yFit - yModel;

SSE = sum(residual.^2);
SST = sum((yFit - mean(yFit)).^2);

if SST > 0
    R2 = 1 - SSE/SST;
else
    R2 = NaN;
end

RMSE = sqrt(mean(residual.^2));

% Aire totale des composantes
AUC = trapz(x, sum(components, 2));

% Amplitude maximale de la contribution carbonatée
peakAmplitude = max(sum(components, 2));

% FWHM de l'enveloppe totale autour de son maximum global
FWHMtotal = calculateTotalFWHM(x, sum(components, 2));

result = struct();

result.parameters = parameters;
result.fitted = fitted;
result.components = components;
result.background = background;

result.R2 = R2;
result.RMSE = RMSE;
result.AUC = AUC;
result.peakAmplitude = peakAmplitude;
result.FWHM_total = FWHMtotal;

end


%% ------------------------------------------------------------
function y = carbonateModel(p, x, nG)

x = x(:);

y = zeros(size(x));

for i = 1:nG

    idx = 3*(i-1) + (1:3);

    A = p(idx(1));
    mu = p(idx(2));
    w = p(idx(3));

    y = y + A .* exp( ...
        -4*log(2) .* ((x-mu)./w).^2);

end

B0 = p(end-1);
B1 = p(end);

y = y + B0 + B1 .* (x - mean(x));

end


%% ------------------------------------------------------------
function p = boundedFitFminsearch(model, p0, x, y, lb, ub)

% Optimisation sans Optimization Toolbox.
% Une pénalité empêche les paramètres de sortir des bornes.

objective = @(p) boundedObjective(p, model, x, y, lb, ub);

options = optimset( ...
    'Display', 'off', ...
    'MaxIter', 1500, ...
    'MaxFunEvals', 10000, ...
    'TolX', 1e-7, ...
    'TolFun', 1e-8);

p = fminsearch(objective, p0, options);

p = min(max(p, lb), ub);

end


%% ------------------------------------------------------------
function value = boundedObjective(p, model, x, y, lb, ub)

penalty = 0;

below = max(lb-p, 0);
above = max(p-ub, 0);

penalty = 1e6 * sum(below.^2 + above.^2);

% Empêcher les valeurs non physiques
if any(~isfinite(p))
    value = realmax;
    return
end

yModel = model(p, x);

if any(~isfinite(yModel))
    value = realmax;
    return
end

residual = yModel - y;

value = sum(residual.^2) + penalty;

end


%% ------------------------------------------------------------
function width = calculateTotalFWHM(x, y)

% FWHM de l'enveloppe totale autour de son maximum global.
% Pour un profil multimodal, cette définition correspond
% à la largeur du pic contenant le maximum global.

x = x(:);
y = y(:);

if isempty(y) || max(y) <= 0
    width = NaN;
    return
end

% Sur-échantillonnage pour améliorer l'interpolation
xFine = linspace(min(x), max(x), 5000).';
yFine = interp1(x, y, xFine, 'pchip');

[yMax, idxMax] = max(yFine);

halfMax = yMax/2;

idxLeft = find(yFine(1:idxMax) <= halfMax, 1, 'last');

idxRightLocal = find(yFine(idxMax:end) <= halfMax, 1, 'first');

if isempty(idxLeft) || isempty(idxRightLocal)
    width = NaN;
    return
end

idxRight = idxMax + idxRightLocal - 1;

% Interpolation linéaire des deux intersections
xLeft = interp1( ...
    yFine(idxLeft:idxLeft+1), ...
    xFine(idxLeft:idxLeft+1), halfMax);

xRight = interp1( ...
    yFine(idxRight-1:idxRight), ...
    xFine(idxRight-1:idxRight), halfMax);

width = xRight - xLeft;

end


%% ------------------------------------------------------------
function createInteractivePlot(results, referenceImage)

nZ = results.dimensions.Z;
x = results.wavenumber;

fig = figure( ...
    'Name', 'SRS - Analyse spectrale interactive', ...
    'NumberTitle', 'off', ...
    'Color', 'w', ...
    'Position', [100 100 1250 750]);

% Axes
axImage = axes(fig, 'Position', [0.07 0.56 0.30 0.36]);
axRaw = axes(fig, 'Position', [0.47 0.56 0.46 0.36]);
axFit = axes(fig, 'Position', [0.07 0.13 0.56 0.32]);
axInfo = axes(fig, 'Position', [0.70 0.13 0.25 0.32]);

% Image de référence
imagesc(axImage, referenceImage);
axis(axImage, 'image');
colormap(axImage, parula(256));
colorbar(axImage);

hold(axImage, 'on');

rectangle(axImage, ...
    'Position', results.roi_position_background, ...
    'EdgeColor', 'c', ...
    'LineWidth', 1.5);

rectangle(axImage, ...
    'Position', results.roi_position_signal, ...
    'EdgeColor', 'r', ...
    'LineWidth', 1.5);

title(axImage, 'Image de référence et ROI');
xlabel(axImage, 'X (pixels)');
ylabel(axImage, 'Y (pixels)');

% Curseur Z
slider = uicontrol(fig, ...
    'Style', 'slider', ...
    'Units', 'normalized', ...
    'Position', [0.20 0.045 0.60 0.035], ...
    'Min', 1, ...
    'Max', max(1, nZ), ...
    'Value', 1, ...
    'SliderStep', [ ...
        1/max(1,nZ-1), ...
        min(1,5/max(1,nZ-1))]);

if nZ == 1
    set(slider, 'Enable', 'off');
end

txtZ = uicontrol(fig, ...
    'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.82 0.035 0.12 0.05], ...
    'String', sprintf('Z = 1/%d', nZ), ...
    'BackgroundColor', 'w', ...
    'FontSize', 11);

% Actualisation
slider.Callback = @updatePlot;

% Affichage initial
updatePlot();

    function updatePlot(~, ~)

        iz = round(slider.Value);
        slider.Value = iz;

        set(txtZ, 'String', sprintf('Z = %d/%d', iz, nZ));

        %% Spectres signal et background
        cla(axRaw);

        plot(axRaw, x, results.spectrum_signal(:, iz), ...
            'ro-', 'MarkerSize', 4, 'MarkerFaceColor', 'r', ...
            'LineWidth', 1.0);

        hold(axRaw, 'on');

        plot(axRaw, x, results.spectrum_bg(:, iz), ...
            'o-', 'Color', [0.2 0.6 0.7], ...
            'MarkerSize', 4, 'LineWidth', 1.0);

        plot(axRaw, x, results.spectrum_corrected(:, iz), ...
            'ko-', 'MarkerSize', 4, 'MarkerFaceColor', 'k', ...
            'LineWidth', 1.0);

        xlabel(axRaw, 'Raman shift (cm^{-1})');
        ylabel(axRaw, 'Intensity (a.u.)');

        title(axRaw, 'Spectres extraits des ROI');

        legend(axRaw, ...
            'Signal', 'Background', 'Signal corrigé', ...
            'Location', 'best');

        grid(axRaw, 'on');

        %% Spectre corrigé et fit
        cla(axFit);

        y = results.spectrum_corrected(:, iz);

        plot(axFit, x, y, ...
            'ko-', 'MarkerSize', 4, 'MarkerFaceColor', 'k', ...
            'LineWidth', 1.0);

        hold(axFit, 'on');

        if results.fit.success(iz)

            plot(axFit, x, results.fit.fitted(:, iz), ...
                'r-', 'LineWidth', 2);

            if results.fit.success(iz)

                nG = size(results.fit.components, 3);

                for i = 1:nG

                    if isgraphics(axFit)

                        plot(axFit, x, ...
                            results.fit.components(:, iz, i), ...
                            '--', 'LineWidth', 1);

                    end

                end

            end

            legendEntries = [{'Spectre corrigé', 'Fit total'}];

            for i = 1:size(results.fit.components, 3)
                legendEntries{end+1} = ...
                    sprintf('Gaussienne %d', i);
            end

            legend(axFit, legendEntries, ...
                'Location', 'best');

        else

            legend(axFit, 'Spectre corrigé');

        end

        xlabel(axFit, 'Raman shift (cm^{-1})');
        ylabel(axFit, 'Intensity (a.u.)');

        title(axFit, 'Fit multi-gaussien');
        grid(axFit, 'on');

        %% Informations numériques
        cla(axInfo);
        axis(axInfo, 'off');

        if results.fit.success(iz)

            % Conserver systématiquement la forme [nGauss x 3].
            % squeeze peut supprimer une dimension lorsque nGauss = 1.
            nGauss = size(results.fit.parameters, 2);
            p = reshape(results.fit.parameters(iz, :, :), nGauss, 3);

            text(axInfo, 0, 1.0, ...
                sprintf('R^2 = %.4f', results.fit.R2(iz)), ...
                'FontSize', 11);

            text(axInfo, 0, 0.91, ...
                sprintf('RMSE = %.4g', results.fit.RMSE(iz)), ...
                'FontSize', 11);

            text(axInfo, 0, 0.82, ...
                sprintf('AUC = %.4g', results.fit.AUC(iz)), ...
                'FontSize', 11);

            text(axInfo, 0, 0.73, ...
                sprintf('Amplitude max = %.4g', ...
                results.fit.peakAmplitude(iz)), ...
                'FontSize', 11);

            text(axInfo, 0, 0.64, ...
                sprintf('FWHM totale = %.3f cm^{-1}', ...
                results.fit.FWHM_total(iz)), ...
                'FontSize', 11);

            for i = 1:size(p, 1)

                str = sprintf( ...
                    'G%d : A=%.3g | Centre=%.2f | FWHM=%.2f', ...
                    i, p(i,1), p(i,2), p(i,3));

                text(axInfo, 0, 0.48-0.10*(i-1), str, ...
                    'FontSize', 9);

            end

        else

            text(axInfo, 0, 0.8, ...
                'Fit non disponible', ...
                'FontSize', 12, ...
                'Color', 'r');

        end

        drawnow;

    end

end
