

function results = analyze_SRS_TIFF_ROI(SRS, cfg)
% ANALYZE_SRS_TIFF_ROI
% Analyse des ROI et fits spectraux à partir de la structure SRS
% renvoyée par load_SRS_TIFF_only.
%
% Entrée :
%   SRS : structure issue de load_SRS_TIFF_only
%         SRS.data       : [Y x X x L x Z x T]
%         SRS.wavenumber : axe Raman [L]
%         SRS.metadata   : métadonnées
%         SRS.scan_type  : type de scan
%         SRS.filename   : nom du fichier (facultatif)
%
%   cfg : structure de configuration facultative
%
% Configuration :
%   cfg.T                   = 1;          % 1, n ou -1 (tous les T)
%   cfg.ROI_signal          = [];         % [x1 x2 y1 y2]
%   cfg.ROI_background      = [];         % [x1 x2 y1 y2]
%   cfg.fitRange            = [1050 1120];
%   cfg.nGauss              = 3;
%   cfg.showIndividualFits  = true;       % conservé pour compatibilité
%   cfg.subtractBackground  = true;       % soustraire ou non le background
%   cfg.fitStep             = 0.1;         % pas de l'axe fin des fits (cm-1)
%
% Sorties :
%   results.spectrum_signal    [L x Z x Tsel]
%   results.spectrum_bg        [L x Z x Tsel]
%   results.spectrum_corrected [L x Z x Tsel]
%
%   results.fit.parameters     [Tsel x Z x nGauss x 3]
%   results.fit.fitted          [Lfine x Z x Tsel]
%   results.fit.components      [Lfine x Z x Tsel x nGauss]
%
%   results.timeIndices         indices T réellement analysés
%
% Convention :
%   data = [Y x X x L x Z x T]
%
% cfg.T = -1 analyse tous les timepoints.

%% ============================================================
% 1. VERIFICATION DES ENTREES
% =============================================================

if nargin < 1 || isempty(SRS) || ~isstruct(SRS)
    error('La fonction attend en entrée la structure SRS.');
end

if nargin < 2 || isempty(cfg)
    cfg = struct();
end

if ~isfield(SRS, 'data') || isempty(SRS.data)
    error('SRS.data est absent ou vide.');
end

if ~isfield(SRS, 'wavenumber') || isempty(SRS.wavenumber)
    error('SRS.wavenumber est absent ou vide.');
end

data = double(SRS.data);

if ndims(data) > 5
    error('SRS.data doit être organisé en [Y X L Z T].');
end

[nY, nX, nL, nZ, nT] = size(data);

wavenumber = double(SRS.wavenumber(:));

if numel(wavenumber) ~= nL
    error(['Le nombre de valeurs de SRS.wavenumber (%d) ne correspond ', ...
        'pas à la dimension spectrale L (%d).'], ...
        numel(wavenumber), nL);
end

%% ============================================================
% 2. CONFIGURATION
% =============================================================

cfg = setDefault(cfg, 'T', 1);
cfg = setDefault(cfg, 'ROI_signal', []);
cfg = setDefault(cfg, 'ROI_background', []);
cfg = setDefault(cfg, 'fitRange', [1050 1120]);
cfg = setDefault(cfg, 'nGauss', 3);
cfg = setDefault(cfg, 'showIndividualFits', true);
cfg = setDefault(cfg, 'subtractBackground', true);
cfg = setDefault(cfg, 'fitStep', 0.1);

if ~islogical(cfg.subtractBackground) || ...
        ~isscalar(cfg.subtractBackground)
    error('cfg.subtractBackground doit être un booléen true ou false.');
end

if ~isnumeric(cfg.fitStep) || ~isscalar(cfg.fitStep) || ...
        ~isfinite(cfg.fitStep) || cfg.fitStep <= 0
    error('cfg.fitStep doit être un nombre strictement positif.');
end

if ~isnumeric(cfg.nGauss) || ~isscalar(cfg.nGauss) || ...
        ~isfinite(cfg.nGauss) || cfg.nGauss < 1 || ...
        cfg.nGauss ~= round(cfg.nGauss)

    error('cfg.nGauss doit être un entier positif.');
end

if numel(cfg.fitRange) ~= 2 || ...
        any(~isfinite(cfg.fitRange)) || ...
        cfg.fitRange(1) >= cfg.fitRange(2)

    error('cfg.fitRange doit être [borne_min borne_max].');
end

% Sélection des timepoints
if ~isnumeric(cfg.T) || ~isscalar(cfg.T) || ...
        ~isfinite(cfg.T) || cfg.T ~= round(cfg.T)

    error('cfg.T doit être un entier ou -1.');
end

if cfg.T == -1

    timeIndices = 1:nT;

elseif cfg.T >= 1 && cfg.T <= nT

    timeIndices = cfg.T;

else

    error('cfg.T doit être compris entre 1 et %d, ou égal à -1.', nT);

end

nTselected = numel(timeIndices);

% Métadonnées facultatives
if isfield(SRS, 'metadata')
    meta = SRS.metadata;
else
    meta = struct();
end

if isfield(SRS, 'scan_type')
    scanType = SRS.scan_type;
else
    scanType = '';
end

if isfield(SRS, 'filename')
    filename = SRS.filename;
else
    filename = '';
end

fprintf('\n========================================\n');
fprintf(' Analyse SRS - ROI et fits spectraux\n');
fprintf('========================================\n');

fprintf('Dimensions : X=%d, Y=%d, L=%d, Z=%d, T=%d\n', ...
    nX, nY, nL, nZ, nT);

fprintf('Timepoints analysés : %s\n', mat2str(timeIndices));
fprintf('Nombre de gaussiennes : %d\n', cfg.nGauss);
if cfg.subtractBackground
    fprintf('Soustraction background : activée\n');
else
    fprintf('Soustraction background : désactivée\n');
end
fprintf('Pas de l''axe fin des fits : %.4g cm-1\n', cfg.fitStep);

%% ============================================================
% 3. IMAGE DE REFERENCE POUR CHAQUE TIMEPOINT
% =============================================================

fprintf('\nCalcul des images de référence...\n');

% Image de référence : moyenne sur L et Z
% referenceImages = [Y x X x Tsel]

referenceImages = nan(nY, nX, nTselected);

for it = 1:nTselected

    iT = timeIndices(it);

    currentData = data(:,:,:,:,iT);

    referenceImages(:,:,it) = ...
        mean(currentData, [3 4], 'omitnan');

end

% Image utilisée pour la sélection des ROI
referenceImage = referenceImages(:,:,1);

%% ============================================================
% 4. SELECTION DES ROI
% =============================================================

% Le ROI background n'est nécessaire que si la soustraction est activée.
% Si subtractBackground=false, ROI_background est totalement ignoré.

needBackground = cfg.subtractBackground;

manualSignal = ~isempty(cfg.ROI_signal);
manualBackground = ~isempty(cfg.ROI_background);
manualROI = manualSignal && (~needBackground || manualBackground);

% Initialisation systématique des variables ROI background
maskBG = false(nY, nX);
posBG = [];
roiBG = [];
nPixBG = 0;

if manualROI

    roiSignal = double(cfg.ROI_signal(:).');

    if numel(roiSignal) ~= 4
        error('cfg.ROI_signal doit être au format [x1 x2 y1 y2].');
    end

    if any(~isfinite(roiSignal)) || ...
            any(roiSignal ~= round(roiSignal)) || ...
            roiSignal(1) < 1 || roiSignal(3) < 1 || ...
            roiSignal(2) > nX || roiSignal(4) > nY || ...
            roiSignal(1) > roiSignal(2) || roiSignal(3) > roiSignal(4)
        error('Coordonnées invalides pour la ROI signal.');
    end

    posSignal = [roiSignal(1), roiSignal(3), ...
        roiSignal(2)-roiSignal(1)+1, ...
        roiSignal(4)-roiSignal(3)+1];

    maskSignal = false(nY, nX);
    maskSignal(roiSignal(3):roiSignal(4), ...
        roiSignal(1):roiSignal(2)) = true;

    if needBackground
        roiBG = double(cfg.ROI_background(:).');

        if numel(roiBG) ~= 4
            error('cfg.ROI_background doit être au format [x1 x2 y1 y2].');
        end

        if any(~isfinite(roiBG)) || ...
                any(roiBG ~= round(roiBG)) || ...
                roiBG(1) < 1 || roiBG(3) < 1 || ...
                roiBG(2) > nX || roiBG(4) > nY || ...
                roiBG(1) > roiBG(2) || roiBG(3) > roiBG(4)
            error('Coordonnées invalides pour la ROI background.');
        end

        posBG = [roiBG(1), roiBG(3), ...
            roiBG(2)-roiBG(1)+1, ...
            roiBG(4)-roiBG(3)+1];

        maskBG(roiBG(3):roiBG(4), ...
            roiBG(1):roiBG(2)) = true;
    end

else

    fprintf('\nSélection des ROI...\n');

    figROI = figure( ...
        'Name', 'Sélection des ROI', ...
        'NumberTitle', 'off', ...
        'Color', 'w');

    axROI = axes(figROI);

    imagesc(axROI, referenceImage);
    axis(axROI, 'image');
    set(axROI, 'YDir', 'normal');
    colormap(axROI, parula(256));
    colorbar(axROI);
    xlabel(axROI, 'X (pixels)');
    ylabel(axROI, 'Y (pixels)');

    if needBackground
        title(axROI, { ...
            'Sélectionner le ROI background', ...
            'Cliquer-glisser puis relâcher pour valider'});

        % getrect évite la dépendance à drawrectangle / Image Processing Toolbox.
        posBG = getrect(axROI);

        if isempty(posBG) || numel(posBG) ~= 4 || ...
                any(~isfinite(posBG)) || posBG(3) <= 0 || posBG(4) <= 0
            error('Sélection du ROI background annulée ou invalide.');
        end

        maskBG = rectangleToMask(posBG, nY, nX);
        if ~any(maskBG(:))
            error('Le ROI background est vide ou hors de l''image.');
        end

        hold(axROI, 'on');
        rectangle(axROI, 'Position', posBG, ...
            'EdgeColor', 'c', 'LineWidth', 1.5);
    else
        title(axROI, { ...
            'Sélectionner le ROI signal', ...
            'Cliquer-glisser puis relâcher pour valider'});
    end

    title(axROI, { ...
        'Sélectionner le ROI signal', ...
        'Cliquer-glisser puis relâcher pour valider'});

    posSignal = getrect(axROI);

    if isempty(posSignal) || numel(posSignal) ~= 4 || ...
            any(~isfinite(posSignal)) || ...
            posSignal(3) <= 0 || posSignal(4) <= 0
        error('Sélection du ROI signal annulée ou invalide.');
    end

    maskSignal = rectangleToMask(posSignal, nY, nX);

    if ~any(maskSignal(:))
        error('Le ROI signal est vide ou hors de l''image.');
    end

    hold(axROI, 'on');
    rectangle(axROI, 'Position', posSignal, ...
        'EdgeColor', 'r', 'LineWidth', 1.5);
end

if needBackground && any(maskBG(:) & maskSignal(:))
    warning('Les deux ROI se chevauchent.');
end

nPixBG = nnz(maskBG);
nPixSignal = nnz(maskSignal);

fprintf('\nROI utilisées :\n');
fprintf('  Signal     : %d pixels\n', nPixSignal);
if needBackground
    fprintf('  Background : %d pixels\n', nPixBG);
else
    fprintf('  Background : non utilisé (soustraction désactivée)\n');
end

%% ============================================================
% 5. EXTRACTION DES SPECTRES POUR CHAQUE Z ET T
% =============================================================

fprintf('\nExtraction des spectres...\n');

% Dimensions : [L x Z x Tsel]
spectrumSignal = nan(nL, nZ, nTselected);

% Le tableau background est conservé pour compatibilité des sorties.
% Il reste à NaN si la soustraction est désactivée.
spectrumBG = nan(nL, nZ, nTselected);

for it = 1:nTselected

    iT = timeIndices(it);

    fprintf('  Extraction T=%d (%d/%d)\n', ...
        iT, it, nTselected);

    for iz = 1:nZ

        for iL = 1:nL

            currentImage = data(:,:,iL,iz,iT);

            valuesSignal = currentImage(maskSignal);
            spectrumSignal(iL,iz,it) = ...
                mean(valuesSignal, 'omitnan');

            if needBackground
                valuesBG = currentImage(maskBG);
                spectrumBG(iL,iz,it) = ...
                    mean(valuesBG, 'omitnan');
            end

        end
    end
end

% Correction éventuelle du background
if needBackground
    spectrumCorrected = spectrumSignal - spectrumBG;
else
    spectrumCorrected = spectrumSignal;
end

%% ============================================================
% 6. FIT MULTI-GAUSSIEN POUR CHAQUE Z ET T
% =============================================================

fprintf('\nAjustement des spectres...\n');

nG = cfg.nGauss;

fit = struct();

% Paramètres : [Tsel x Z x nGauss x 3]
% 3 paramètres par gaussienne : amplitude, centre, FWHM
fit.parameters = nan(nTselected, nZ, nG, 3);

% Axe spectral fin pour l'évaluation et l'affichage des modèles
wavenumberFit = (min(wavenumber):cfg.fitStep:max(wavenumber)).';
if isempty(wavenumberFit)
    wavenumberFit = [min(wavenumber); max(wavenumber)];
elseif wavenumberFit(end) < max(wavenumber)
    wavenumberFit(end+1,1) = max(wavenumber);
end
fit.wavenumber = wavenumberFit;

% Modèles et composantes évalués sur l'axe fin : [Lfine x Z x Tsel]
fit.fitted = nan(numel(wavenumberFit), nZ, nTselected);
fit.components = nan(numel(wavenumberFit), nZ, nTselected, nG);
fit.background = nan(numel(wavenumberFit), nZ, nTselected);

fit.R2 = nan(nZ, nTselected);
fit.RMSE = nan(nZ, nTselected);
fit.AUC = nan(nZ, nTselected);
fit.peakAmplitude = nan(nZ, nTselected);
fit.FWHM_total = nan(nZ, nTselected);
fit.success = false(nZ, nTselected);

for it = 1:nTselected

    iT = timeIndices(it);

    fprintf('\nTimepoint T=%d (%d/%d)\n', iT, it, nTselected);

    for iz = 1:nZ

        y = spectrumCorrected(:,iz,it);

        try

            fitResult = fitCarbonateSpectrum(wavenumber, y, cfg, wavenumberFit);

            fit.parameters(it,iz,:,:) = ...
                reshape(fitResult.parameters, [1 1 nG 3]);

            fit.fitted(:,iz,it) = fitResult.fitted;

            fit.components(:,iz,it,:) = ...
                reshape(fitResult.components, [numel(wavenumberFit) 1 1 nG]);

            fit.background(:,iz,it) = fitResult.background;

            fit.R2(iz,it) = fitResult.R2;
            fit.RMSE(iz,it) = fitResult.RMSE;
            fit.AUC(iz,it) = fitResult.AUC;
            fit.peakAmplitude(iz,it) = fitResult.peakAmplitude;
            fit.FWHM_total(iz,it) = fitResult.FWHM_total;

            fit.success(iz,it) = true;

        catch ME

            warning('Fit échoué pour T=%d, Z=%d : %s', ...
                iT, iz, ME.message);

        end
    end

    fprintf('Fits réussis pour T=%d : %d/%d\n', ...
        iT, nnz(fit.success(:,it)), nZ);

end

fprintf('\nFits terminés : %d/%d réussis.\n', ...
    nnz(fit.success), numel(fit.success));

%% ============================================================
% 7. ANALYSE STATISTIQUE DES FITS
% =============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('             ANALYSE STATISTIQUE DES FITS\n');
fprintf('============================================================\n');

metricNames = {'R2', 'RMSE', 'AUC', ...
    'Peak amplitude', 'FWHM total'};

for it = 1:nTselected

    iT = timeIndices(it);

    validFits = fit.success(:,it);
    nValid = nnz(validFits);

    fprintf('\n============================================================\n');
    fprintf('TIMEPOINT T=%d\n', iT);
    fprintf('Fits réussis : %d / %d (%.1f %%)\n', ...
        nValid, nZ, 100*nValid/max(nZ,1));

    if nValid == 0
        fprintf('Aucun fit valide pour ce timepoint.\n');
        continue
    end

    metricData = { ...
        fit.R2(validFits,it), ...
        fit.RMSE(validFits,it), ...
        fit.AUC(validFits,it), ...
        fit.peakAmplitude(validFits,it), ...
        fit.FWHM_total(validFits,it)};

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

    %% Statistiques des gaussiennes

    fprintf('\n--- STATISTIQUES DES GAUSSIENNES ---\n');

    for iG = 1:nG

        amplitudes = reshape(fit.parameters(it,validFits,iG,1), [], 1);
        centers = reshape(fit.parameters(it,validFits,iG,2), [], 1);
        widths = reshape(fit.parameters(it,validFits,iG,3), [], 1);

        parameterNames = {'Amplitude', 'Centre (cm-1)', 'FWHM (cm-1)'};
        parameterData = {amplitudes, centers, widths};

        fprintf('\nGaussienne %d\n', iG);

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

    %% Résultats individuels selon Z

    fprintf('\n--- RESULTATS INDIVIDUELS SELON Z ---\n');

    fprintf('%5s %10s %12s %12s %12s %12s\n', ...
        'Z', 'Fit', 'R2', 'RMSE', 'AUC', 'FWHM');

    for iz = 1:nZ

        if fit.success(iz,it)

            fprintf('%5d %10s %12.4f %12.4g %12.4g %12.4f\n', ...
                iz, 'OK', ...
                fit.R2(iz,it), ...
                fit.RMSE(iz,it), ...
                fit.AUC(iz,it), ...
                fit.FWHM_total(iz,it));

        else

            fprintf('%5d %10s %12s %12s %12s %12s\n', ...
                iz, 'FAILED', '-', '-', '-', '-');

        end
    end
end

fprintf('\n============================================================\n');
fprintf('                 FIN DE L''ANALYSE\n');
fprintf('============================================================\n');

%% ============================================================
% 8. STRUCTURE DE SORTIE
% =============================================================

results = struct();

results.filename = filename;
results.metadata = meta;
results.scan_type = scanType;

if isfield(SRS, 'pageOrder')
    results.pageOrder = SRS.pageOrder;
elseif isfield(SRS, 'page_order')
    results.pageOrder = SRS.page_order;
else
    results.pageOrder = '';
end

results.dimensions = struct( ...
    'X', nX, ...
    'Y', nY, ...
    'L', nL, ...
    'Z', nZ, ...
    'T', nT);

results.selected_T = cfg.T;
results.timeIndices = timeIndices;

results.wavenumber = wavenumber;          % axe expérimental
results.wavenumber_fit = fit.wavenumber;  % axe fin pour les modèles ajustés
results.subtractBackground = cfg.subtractBackground;
results.fitStep = cfg.fitStep;

% Données complètes de l'acquisition
results.data = data;

% Images de référence : [Y x X x Tsel]
results.referenceImages = referenceImages;

% ROI
results.roi_signal = maskSignal;
results.roi_background = maskBG;

results.roi_position_signal = posSignal;
results.roi_position_background = posBG;

results.nPixels_signal = nPixSignal;
results.nPixels_background = nPixBG;

% Spectres : [L x Z x Tsel]
results.spectrum_signal = spectrumSignal;
results.spectrum_bg = spectrumBG;
results.spectrum_corrected = spectrumCorrected;

% Fits
results.fit = fit;

%% ============================================================
% 9. INTERFACE GRAPHIQUE INTERACTIVE
% =============================================================

createInteractivePlot(results);

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
function result = fitCarbonateSpectrum(x, y, cfg, xFine)

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

if ~isfinite(signalMax) || signalMax <= 0
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

% Le centre du fond linéaire est fixé à mean(xFit), y compris
% lors de l'évaluation ultérieure sur l'axe spectral fin.
backgroundCenter = mean(xFit);
model = @(p, xx) carbonateModel(p, xx, nG, backgroundCenter);

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

        p = boundedFitFminsearch( ...
            model, p0, xFit, yFit, lb, ub);

    end

else

    p = boundedFitFminsearch( ...
        model, p0, xFit, yFit, lb, ub);

end

% Trier les composantes par centre spectral
parameters = reshape(p(1:3*nG), 3, nG).';

[~, order] = sort(parameters(:,2));
parameters = parameters(order,:);

% Reconstruire le vecteur de paramètres trié
pSorted = zeros(size(p));

for i = 1:nG
    pSorted(3*(i-1)+(1:3)) = parameters(i,:);
end

pSorted(end-1:end) = p(end-1:end);

% Evaluation du modèle et des composantes sur l'axe fin.
% L'optimisation, elle, reste réalisée sur les points expérimentaux xFit.
fitted = carbonateModel(pSorted, xFine, nG, backgroundCenter);

components = zeros(numel(xFine), nG);

for i = 1:nG

    A = parameters(i,1);
    mu = parameters(i,2);
    w = parameters(i,3);

    components(:,i) = A .* exp( ...
        -4*log(2) .* ((xFine-mu)./w).^2);

end

background = pSorted(end-1) + ...
    pSorted(end) .* (xFine - backgroundCenter);

% Qualité du fit sur la zone sélectionnée
yModel = carbonateModel(pSorted, xFit, nG, backgroundCenter);

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
AUC = trapz(xFine, sum(components,2));

% Amplitude maximale de la contribution carbonatée
peakAmplitude = max(sum(components,2));

% FWHM de l'enveloppe totale autour de son maximum global
FWHMtotal = calculateTotalFWHM(xFine, sum(components,2));

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
function y = carbonateModel(p, x, nG, backgroundCenter)

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

y = y + B0 + B1 .* (x - backgroundCenter);

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

below = max(lb-p, 0);
above = max(p-ub, 0);

penalty = 1e6 * sum(below.^2 + above.^2);

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
function createInteractivePlot(results)

nZ = results.dimensions.Z;
nT = numel(results.timeIndices);

x = results.wavenumber;             % axe expérimental
xFit = results.fit.wavenumber;       % axe fin des courbes ajustées

fig = figure( ...
    'Name', 'SRS - Analyse spectrale interactive', ...
    'NumberTitle', 'off', ...
    'Color', 'w', ...
    'Position', [100 100 1250 780]);

% Axes
axImage = axes(fig, 'Position', [0.07 0.57 0.30 0.35]);
axRaw = axes(fig, 'Position', [0.47 0.57 0.46 0.35]);
axFit = axes(fig, 'Position', [0.07 0.13 0.56 0.32]);
axInfo = axes(fig, 'Position', [0.70 0.13 0.25 0.32]);

%% Curseur Z

sliderZ = uicontrol(fig, ...
    'Style', 'slider', ...
    'Units', 'normalized', ...
    'Position', [0.20 0.065 0.60 0.025], ...
    'Min', 1, ...
    'Max', max(1,nZ), ...
    'Value', 1, ...
    'SliderStep', [ ...
        1/max(1,nZ-1), ...
        min(1,5/max(1,nZ-1))]);

if nZ == 1
    set(sliderZ, 'Enable', 'off');
end

txtZ = uicontrol(fig, ...
    'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.82 0.057 0.12 0.04], ...
    'String', sprintf('Z = 1/%d', nZ), ...
    'BackgroundColor', 'w', ...
    'FontSize', 11);

%% Curseur T

sliderT = uicontrol(fig, ...
    'Style', 'slider', ...
    'Units', 'normalized', ...
    'Position', [0.20 0.025 0.60 0.025], ...
    'Min', 1, ...
    'Max', max(1,nT), ...
    'Value', 1, ...
    'SliderStep', [ ...
        1/max(1,nT-1), ...
        min(1,5/max(1,nT-1))]);

if nT == 1
    set(sliderT, 'Enable', 'off');
end

txtT = uicontrol(fig, ...
    'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.82 0.017 0.12 0.04], ...
    'String', sprintf('T = %d/%d', ...
        results.timeIndices(1), results.dimensions.T), ...
    'BackgroundColor', 'w', ...
    'FontSize', 11);

% Actualisation
sliderZ.Callback = @updatePlot;
sliderT.Callback = @updatePlot;

% Affichage initial
updatePlot();


    %% ========================================================
    % Fonction interne d'actualisation
    % =========================================================

    function updatePlot(~,~)

        iz = round(sliderZ.Value);
        it = round(sliderT.Value);

        sliderZ.Value = iz;
        sliderT.Value = it;

        actualT = results.timeIndices(it);

        set(txtZ, 'String', sprintf('Z = %d/%d', iz, nZ));
        set(txtT, 'String', sprintf('T = %d/%d', ...
            actualT, results.dimensions.T));

        %% Image de référence

        cla(axImage);

        imagesc(axImage, results.referenceImages(:,:,it));

        axis(axImage, 'image');
        set(axImage, 'YDir', 'normal');

        colormap(axImage, parula(256));
        colorbar(axImage);

        hold(axImage, 'on');

        if results.subtractBackground && ...
                ~isempty(results.roi_position_background)
            rectangle(axImage, ...
                'Position', results.roi_position_background, ...
                'EdgeColor', 'c', ...
                'LineWidth', 1.5);
        end

        rectangle(axImage, ...
            'Position', results.roi_position_signal, ...
            'EdgeColor', 'r', ...
            'LineWidth', 1.5);

        title(axImage, sprintf('Image de référence - T=%d', actualT));
        xlabel(axImage, 'X (pixels)');
        ylabel(axImage, 'Y (pixels)');

        %% Spectres signal et background

        cla(axRaw);

        plot(axRaw, x, results.spectrum_signal(:,iz,it), ...
            'ro-', 'MarkerSize', 4, 'MarkerFaceColor', 'r', ...
            'LineWidth', 1.0);

        hold(axRaw, 'on');

        if results.subtractBackground
            plot(axRaw, x, results.spectrum_bg(:,iz,it), ...
                'o-', 'Color', [0.2 0.6 0.7], ...
                'MarkerSize', 4, 'LineWidth', 1.0);

            plot(axRaw, x, results.spectrum_corrected(:,iz,it), ...
                'ko-', 'MarkerSize', 4, 'MarkerFaceColor', 'k', ...
                'LineWidth', 1.0);

            legend(axRaw, ...
                'Signal', 'Background', 'Signal corrigé', ...
                'Location', 'best');
        else
            plot(axRaw, x, results.spectrum_corrected(:,iz,it), ...
                'ko-', 'MarkerSize', 4, 'MarkerFaceColor', 'k', ...
                'LineWidth', 1.0);

            legend(axRaw, 'Signal (sans soustraction background)', ...
                'Location', 'best');
        end

        xlabel(axRaw, 'Raman shift (cm^{-1})');
        ylabel(axRaw, 'Intensity (a.u.)');

        title(axRaw, sprintf('Spectres extraits des ROI - Z=%d, T=%d', ...
            iz, actualT));

        grid(axRaw, 'on');

        %% Spectre corrigé et fit

        cla(axFit);

        y = results.spectrum_corrected(:,iz,it);

        plot(axFit, x, y, ...
            'ko-', 'MarkerSize', 4, 'MarkerFaceColor', 'k', ...
            'LineWidth', 1.0);

        hold(axFit, 'on');

        if results.fit.success(iz,it)

            plot(axFit, xFit, results.fit.fitted(:,iz,it), ...
                'r-', 'LineWidth', 2);

            nGauss = size(results.fit.components,4);

            for i = 1:nGauss

                plot(axFit, xFit, ...
                    results.fit.components(:,iz,it,i), ...
                    '--', 'LineWidth', 1);

            end

            legendEntries = {'Spectre corrigé', 'Fit total'};

            for i = 1:nGauss
                legendEntries{end+1} = sprintf('Gaussienne %d',i);
            end

            legend(axFit, legendEntries, 'Location', 'best');

        else

            legend(axFit, 'Spectre corrigé');

        end

        xlabel(axFit, 'Raman shift (cm^{-1})');
        ylabel(axFit, 'Intensity (a.u.)');

        title(axFit, sprintf('Fit multi-gaussien - Z=%d, T=%d', ...
            iz, actualT));

        grid(axFit, 'on');

        %% Informations numériques

        cla(axInfo);
        axis(axInfo, 'off');

        if results.fit.success(iz,it)

            nGauss = size(results.fit.parameters,3);

            p = reshape( ...
                results.fit.parameters(it,iz,:,:), nGauss, 3);

            text(axInfo, 0, 1.0, ...
                sprintf('R^2 = %.4f', results.fit.R2(iz,it)), ...
                'FontSize', 11);

            text(axInfo, 0, 0.91, ...
                sprintf('RMSE = %.4g', results.fit.RMSE(iz,it)), ...
                'FontSize', 11);

            text(axInfo, 0, 0.82, ...
                sprintf('AUC = %.4g', results.fit.AUC(iz,it)), ...
                'FontSize', 11);

            text(axInfo, 0, 0.73, ...
                sprintf('Amplitude max = %.4g', ...
                results.fit.peakAmplitude(iz,it)), ...
                'FontSize', 11);

            text(axInfo, 0, 0.64, ...
                sprintf('FWHM totale = %.3f cm^{-1}', ...
                results.fit.FWHM_total(iz,it)), ...
                'FontSize', 11);

            for i = 1:nGauss

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
