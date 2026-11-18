

function SRS = load_SRS_TIFF_only(filename, cfg)
% LOAD_SRS_TIFF_ONLY
% Charge un TIFF multipage SRS et retourne les donnees et metadonnees.
%
% Organisation canonique :
%   SRS.data : [Y X L Z T]
%
% Types de scan supportes :
%   XY, XYL, XYZ, XYLZ, XYZL
%
% Organisation des pages :
%   - XYLZ : L varie le plus rapidement, puis Z, puis T.
%   - XYZL : Z varie le plus rapidement, puis L, puis T.
%   - XYL  : L varie, puis T.
%   - XYZ  : Z varie, puis T.
%   - XY   : une image par timepoint.
%
% Utilisation :
%   SRS = load_SRS_TIFF_only;
%   SRS = load_SRS_TIFF_only(filename);
%   SRS = load_SRS_TIFF_only(filename, cfg);
%
% Configuration :
%   cfg.pageOrder  = 'auto';  % 'auto', 'LZ' ou 'ZL'
%   cfg.wavenumber = [];      % Axe Raman directement en cm-1
%   cfg.wl_ir_nm   = 1031.3;  % Longueur d'onde IR/Stokes (nm)
%
% Acces aux donnees :
%   Image XY au temps it :
%       I = SRS.data(:,:,1,1,it);
%
%   Image spectrale au temps it et au Z iz :
%       I = SRS.data(:,:,iL,iz,it);
%
%   Nombre de timepoints :
%       SRS.dimensions.T
%
% Remarque :
%   Les dimensions finales singleton peuvent ne pas apparaitre dans
%   size(SRS.data), comportement normal de MATLAB.

%% 1. Selection du fichier

if nargin < 1 || isempty(filename)

    [file, path] = uigetfile( ...
        {'*.tif;*.tiff', 'TIFF files (*.tif, *.tiff)'}, ...
        'Selectionner une acquisition SRS');

    if isequal(file, 0)
        error('Aucun fichier selectionne.');
    end

    filename = fullfile(path, file);
end

if nargin < 2 || isempty(cfg)
    cfg = struct();
end

%% 2. Configuration

cfg = setDefault(cfg, 'pageOrder', 'auto');
cfg = setDefault(cfg, 'wavenumber', []);
cfg = setDefault(cfg, 'wl_ir_nm', 1031.3);

if ~isfile(filename)
    error('Fichier introuvable : %s', filename);
end

if ~isnumeric(cfg.wl_ir_nm) || ...
        ~isscalar(cfg.wl_ir_nm) || ...
        ~isfinite(cfg.wl_ir_nm) || cfg.wl_ir_nm <= 0
    error('cfg.wl_ir_nm doit etre un scalaire positif.');
end

fprintf('\n========================================\n');
fprintf('       CHARGEMENT DU TIFF SRS\n');
fprintf('========================================\n');

fprintf('Fichier : %s\n', filename);

%% 3. Lecture des informations TIFF

fprintf('\nLecture des informations TIFF...\n');

try
    info = imfinfo(filename);
catch ME
    error('Impossible de lire le fichier TIFF : %s', ME.message);
end

nPages = numel(info);

if nPages < 1
    error('Le fichier TIFF ne contient aucune image.');
end

pageWidth = info(1).Width;
pageHeight = info(1).Height;

if pageWidth < 1 || pageHeight < 1
    error('Dimensions TIFF invalides.');
end

fprintf('Nombre de pages TIFF : %d\n', nPages);
fprintf('Dimensions TIFF : %d x %d\n', pageHeight, pageWidth);

%% 4. Extraction des metadonnees

fprintf('\nExtraction des metadonnees...\n');

meta = extractSRSMetadata(info(1));

nX = getMetaNumber(meta, {'X'}, pageWidth);
nY = getMetaNumber(meta, {'Y'}, pageHeight);

if nX ~= pageWidth || nY ~= pageHeight
    error(['Incoherence entre les metadonnees et le TIFF : ', ...
        'metadata X/Y = %d/%d, TIFF Width/Height = %d/%d.'], ...
        nX, nY, pageWidth, pageHeight);
end

scanType = upper(char(getMetaValue(meta, ...
    {'scan_type'}, 'XYL')));

nL = getMetaNumber(meta, {'L'}, 1);
nZ = getMetaNumber(meta, {'Z'}, 1);

% T peut etre renseigne sous differents noms selon les metadonnees.
nT = getMetaNumber(meta, {'T', 'timepoints', 'frames'}, 1);

%% 5. Verification du type de scan

supportedScanTypes = {'XY', 'XYL', 'XYZ', 'XYLZ', 'XYZL'};

if ~ismember(scanType, supportedScanTypes)
    error('scan_type non reconnu ou non supporte : %s', scanType);
end

fprintf('Type de scan : %s\n', scanType);
fprintf('Dimensions : X=%d, Y=%d, L=%d, Z=%d, T=%d\n', ...
    nX, nY, nL, nZ, nT);

switch scanType

    case 'XY'
        if nL ~= 1 || nZ ~= 1
            error('Incoherence entre scan_type XY et dimensions L/Z.');
        end

    case 'XYL'
        if nZ ~= 1
            error('Incoherence entre scan_type XYL et dimension Z.');
        end

    case 'XYZ'
        if nL ~= 1
            error('Incoherence entre scan_type XYZ et dimension L.');
        end
end

%% 6. Determination de l'ordre des pages

if strcmpi(cfg.pageOrder, 'auto')

    switch scanType

        case {'XYLZ', 'XYL'}
            pageOrder = 'LZ';

        case {'XYZL', 'XYZ', 'XY'}
            pageOrder = 'ZL';

    end

else
    pageOrder = upper(char(cfg.pageOrder));
end

if ~ismember(pageOrder, {'LZ', 'ZL'})
    error('pageOrder doit etre ''auto'', ''LZ'' ou ''ZL''.');
end

fprintf('Ordre des pages : %s\n', pageOrder);

%% 7. Verification du nombre de pages

nPagesPerT = nL * nZ;
nPagesRequired = nPagesPerT * nT;

fprintf('Pages par timepoint : %d\n', nPagesPerT);
fprintf('Pages necessaires : %d\n', nPagesRequired);

if nPages < nPagesRequired
    error(['Nombre de pages insuffisant : %d disponibles, ', ...
        '%d necessaires (L=%d, Z=%d, T=%d).'], ...
        nPages, nPagesRequired, nL, nZ, nT);
end

if nPages > nPagesRequired
    warning(['Le TIFF contient %d pages supplementaires. ', ...
        'Elles ne seront pas chargees.'], ...
        nPages - nPagesRequired);
end

%% 8. Verification des dimensions des pages

fprintf('\nVerification des pages TIFF...\n');

for k = 1:nPagesRequired

    if info(k).Width ~= nX || info(k).Height ~= nY
        error(['La page TIFF %d possede des dimensions ', ...
            'incorrectes (%d x %d au lieu de %d x %d).'], ...
            k, info(k).Height, info(k).Width, nY, nX);
    end

end

%% 9. Chargement et reorganisation des donnees

fprintf('\nChargement des images...\n');

% Organisation canonique : [Y X L Z T]
data = zeros(nY, nX, nL, nZ, nT, 'double');

for k = 1:nPagesRequired

    try
        I = double(imread(filename, k));
    catch ME
        error('Erreur de lecture de la page TIFF %d : %s', ...
            k, ME.message);
    end

    if ~ismatrix(I) || ~isequal(size(I), [nY nX])
        error('La page TIFF %d ne contient pas une image XY valide.', k);
    end

    if any(~isfinite(I(:)))
        warning('La page TIFF %d contient des valeurs non finies.', k);
    end

    % Numero du timepoint
    iT = floor((k-1) / nPagesPerT) + 1;

    % Numero de la page a l'interieur du timepoint
    kWithinT = mod(k-1, nPagesPerT) + 1;

    % Determination des indices L et Z
    if strcmp(pageOrder, 'LZ')

        [iL, iZ] = ind2sub([nL nZ], kWithinT);

    else

        [iZ, iL] = ind2sub([nZ nL], kWithinT);

    end

    data(:, :, iL, iZ, iT) = I;

end

fprintf('Chargement termine.\n');

%% 10. Construction de l'axe spectral

fprintf('\nConstruction de l''axe spectral...\n');

if ~isempty(cfg.wavenumber)

    wavenumber = cfg.wavenumber(:);

    if numel(wavenumber) ~= nL
        error(['cfg.wavenumber contient %d valeurs, ', ...
            'alors que L=%d.'], numel(wavenumber), nL);
    end

    if any(~isfinite(wavenumber))
        error('cfg.wavenumber contient des valeurs non finies.');
    end

    wavelength = NaN(nL, 1);

elseif nL > 1

    min_wl = getMetaScalar(meta, ...
        {'min_wl', 'Lambda_min_nm'}, NaN);

    max_wl = getMetaScalar(meta, ...
        {'max_wl', 'Lambda_max_nm'}, NaN);

    if ~isfinite(min_wl) || ~isfinite(max_wl)
        error(['Impossible de construire l''axe spectral. ', ...
            'Les metadonnees doivent contenir min_wl et max_wl. ', ...
            'Il est egalement possible de fournir cfg.wavenumber.']);
    end

    if min_wl <= 0 || max_wl <= 0
        error('Les longueurs d''onde doivent etre positives.');
    end

    wavelength = linspace(min_wl, max_wl, nL).';

    wavenumber = 1e7 ./ wavelength - ...
                 1e7 ./ cfg.wl_ir_nm;

else

    wavelength = NaN(nL, 1);
    wavenumber = NaN(nL, 1);

end

%% 11. Tri spectral croissant

if nL > 1

    [wavenumber, sortIdx] = sort(wavenumber, 'ascend');

    % Le tri est effectue independamment pour tous les Z et T.
    data = data(:, :, sortIdx, :, :);

    if all(isfinite(wavelength))
        wavelength = wavelength(sortIdx);
    end

end

if nL > 1
    fprintf('Axe spectral : %.2f a %.2f cm-1\n', ...
        min(wavenumber), max(wavenumber));
end

%% 12. Verification finale des donnees

fprintf('\nVerification finale des donnees...\n');

% Ne pas utiliser isequal(size(data), expectedSize) :
% MATLAB supprime les dimensions finales singleton dans size().
if size(data,1) ~= nY || ...
   size(data,2) ~= nX || ...
   size(data,3) ~= nL || ...
   size(data,4) ~= nZ || ...
   size(data,5) ~= nT

    error(['Dimensions finales incorrectes apres reorganisation.\n', ...
        'Attendu : [%d %d %d %d %d]\n', ...
        'Obtenu  : [%d %d %d %d %d]'], ...
        nY, nX, nL, nZ, nT, ...
        size(data,1), size(data,2), ...
        size(data,3), size(data,4), size(data,5));
end

if ~any(isfinite(data(:)))
    error('Les donnees chargees ne contiennent aucune valeur valide.');
end

fprintf('Dimensions finales : [Y=%d X=%d L=%d Z=%d T=%d]\n', ...
    nY, nX, nL, nZ, nT);

fprintf('Valeurs minimales : %.6g\n', min(data(:), [], 'omitnan'));
fprintf('Valeurs maximales : %.6g\n', max(data(:), [], 'omitnan'));

%% 13. Structure de sortie

SRS = struct();

SRS.filename = filename;
SRS.metadata = meta;

SRS.scan_type = scanType;
SRS.pageOrder = pageOrder;

SRS.dimensions = struct( ...
    'X', nX, ...
    'Y', nY, ...
    'L', nL, ...
    'Z', nZ, ...
    'T', nT);

SRS.wavenumber = wavenumber;
SRS.wavelength = wavelength;

SRS.data = data;

SRS.nPages = nPages;
SRS.nPagesLoaded = nPagesRequired;

% Tous les timepoints sont charges.
SRS.loadedTimepoint = 1:nT;

fprintf('\n========================================\n');
fprintf('     CHARGEMENT TERMINE AVEC SUCCES\n');
fprintf('========================================\n\n');

end


%% ============================================================
% FONCTIONS AUXILIAIRES
% =============================================================

function cfg = setDefault(cfg, field, value)

    if ~isfield(cfg, field) || isempty(cfg.(field))
        cfg.(field) = value;
    end

end


function meta = extractSRSMetadata(info)

    meta = struct();

    if ~isfield(info, 'ImageDescription')
        warning('Aucune ImageDescription dans le TIFF.');
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
        warning('Metadonnees LabVIEW non trouvees dans le TIFF.');
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

        error('Impossible de decoder les metadonnees LabVIEW : %s', ...
            ME.message);

    end

end


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


function value = getMetaNumber(meta, names, defaultValue)

    rawValue = getMetaValue(meta, names, defaultValue);

    if isnumeric(rawValue) && isscalar(rawValue)

        value = double(rawValue);

    elseif ischar(rawValue) || ...
            (isstring(rawValue) && isscalar(rawValue))

        value = str2double(rawValue);

    else

        value = defaultValue;

    end

    if ~isfinite(value) || value < 1
        value = defaultValue;
    end

    value = round(value);

end


function value = getMetaScalar(meta, names, defaultValue)

    value = defaultValue;

    for k = 1:numel(names)

        if isfield(meta, names{k})

            candidate = meta.(names{k});

            if isnumeric(candidate) && isscalar(candidate)

                candidate = double(candidate);

            elseif ischar(candidate) || ...
                    (isstring(candidate) && isscalar(candidate))

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
