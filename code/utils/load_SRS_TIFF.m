
function data = load_SRS_TIFF(filename, cfg)
% LOAD_SRS_TIFF
% Import d'un TIFF multipage issu du systeme SRS.
%
% Modes supportes :
%   XY, XYL, XYZ, XYLZ, XYZL
%
% Format de sortie :
%   data.images : [Y, X, L, Z, T]
%
% Les metadonnees LabVIEW sont lues dans ImageDescription :
%   Info=LABVIEW_RAMAN|{...}
%
% Les parametres de cfg sont prioritaires sur les metadonnees.
%
% Exemple :
%   cfg = struct();
%   data = load_SRS_TIFF("acquisition.tiff", cfg);
%
% Correction spatiale :
%   cfg.spatialScaleCorrection = 36;

if nargin < 2 || isempty(cfg)
    cfg = struct();
end

%% 1. Verification du fichier

filename = char(filename);

% Sélection du fichier si le chemin fourni est invalide
if ~isfile(filename)

    warning('Fichier introuvable : %s', filename);

    [file, path] = uigetfile( ...
        {'*.tif;*.tiff', 'TIFF files (*.tif, *.tiff)'}, ...
        'Sélectionner le fichier TIFF');

    if isequal(file, 0)
        error('Aucun fichier sélectionné.');
    end

    filename = string(fullfile(path, file));
end

info = imfinfo(filename);
nPages = numel(info);

if nPages == 0
    error('Le TIFF ne contient aucune page.');
end

nY = info(1).Height;
nX = info(1).Width;

for k = 2:nPages
    if info(k).Height ~= nY || info(k).Width ~= nX
        error('Dimensions incompatibles entre les pages TIFF.');
    end
end

%% 2. Lecture des metadonnees LabVIEW

meta = extractLabviewMetadata(info(1));

%% 3. Identification du mode d'acquisition

if isfield(cfg,'mode') && ~isempty(cfg.mode)
    mode = upper(char(cfg.mode));
elseif isfield(meta,'scan_type')
    mode = upper(char(meta.scan_type));
else
    error('Mode absent : renseigner cfg.mode ou scan_type dans les metadonnees.');
end

validModes = {'XY','XYL','XYZ','XYLZ','XYZL'};

if ~ismember(mode,validModes)
    error('Mode non reconnu : %s',mode);
end

usesL = ismember(mode,{'XYL','XYLZ','XYZL'});
usesZ = ismember(mode,{'XYZ','XYLZ','XYZL'});

%% 4. Nombre de points sur chaque axe

nL = 1;
nZ = 1;
nT = 1;

if usesL
    nL = getCount(cfg,meta,'nL','L');
end

if usesZ
    nZ = getCount(cfg,meta,'nZ','Z');
end

    % Nombre de points temporels T

if isfield(cfg,'nT') && ~isempty(cfg.nT)

    % Priorite a la configuration manuelle
    nT = checkCount(cfg.nT,'nT');

elseif isfield(meta,'timepoints') && ...
        isnumeric(meta.timepoints)

    % Nombre de timepoints depuis les metadonnees LabVIEW
    nT = checkCount(meta.timepoints,'timepoints');

elseif isfield(meta,'timelapse') && logicalValue(meta.timelapse)

    error(['Timelapse detecte, mais le nombre de timepoints ', ...
           'est absent des metadonnees.']);

end

expectedPages = nL*nZ*nT;

if nPages ~= expectedPages
    error(['Nombre de pages incorrect : %d pages trouvees, ', ...
           '%d attendues (L=%d, Z=%d, T=%d).'], ...
           nPages,expectedPages,nL,nZ,nT);
end

%% 5. Construction des axes

% Axe spectral L (nm)
L = getAxis(cfg,'L',nL);

if isempty(L) && usesL
    L = makeLinearAxis(meta,'Lambda_min_nm', ...
                           'Lambda_max_nm',nL);
end

if isempty(L)
    L = 1:nL;
end

% Axe Z (um)
Z = getAxis(cfg,'Z',nZ);

if isempty(Z) && usesZ
    Z = makeLinearAxis(meta,'Zmin_um','Zmax_um',nZ);
end

if isempty(Z)
    Z = 1:nZ;
end

% Axe temporel
T = getAxis(cfg,'T',nT);

if isempty(T)
    T = 1:nT;
end

%% 6. Ordre des pages dans le TIFF

% LZ : L varie le plus rapidement.
% ZL : Z varie le plus rapidement.

if isfield(cfg,'pageOrder') && ~isempty(cfg.pageOrder)
    pageOrder = upper(char(cfg.pageOrder));
elseif strcmp(mode,'XYZL')
    pageOrder = 'ZL';
else
    pageOrder = 'LZ';
end

if ~ismember(pageOrder,{'LZ','ZL'})
    error('cfg.pageOrder doit etre LZ ou ZL.');
end

%% 7. Allocation du tableau images

firstFrame = imread(filename,1,'Info',info);
inputClass = class(firstFrame);

if isfield(cfg,'outputClass') && ~isempty(cfg.outputClass)
    outputClass = char(cfg.outputClass);
else
    outputClass = inputClass;
end

images = zeros(nY,nX,nL,nZ,nT,outputClass);

%% 8. Import des pages TIFF

for t = 1:nT

    for z = 1:nZ

        for l = 1:nL

            if strcmp(pageOrder,'LZ')
                pageInTime = l + (z-1)*nL;
            else
                pageInTime = z + (l-1)*nZ;
            end

            page = pageInTime + (t-1)*nL*nZ;

            frame = imread(filename,page,'Info',info);

            images(:,:,l,z,t) = cast(frame,outputClass);

        end
    end
end

%% 9. Correction de la calibration spatiale

% Facteur de correction par defaut : x36.
scaleCorrection = 36;

if isfield(cfg,'spatialScaleCorrection') && ...
        ~isempty(cfg.spatialScaleCorrection)

    scaleCorrection = cfg.spatialScaleCorrection;

end

if ~isscalar(scaleCorrection) || ...
        ~isfinite(scaleCorrection) || scaleCorrection <= 0

    error('Le facteur spatial doit etre un scalaire positif.');

end

% Valeurs originales issues des metadonnees.
FOV_X_raw = getNumericMetadata(meta,'FOV_X_um');
FOV_Y_raw = getNumericMetadata(meta,'FOV_Y_um');

pixel_X_raw = getNumericMetadata(meta,'pixel_size_X_um');
pixel_Y_raw = getNumericMetadata(meta,'pixel_size_Y_um');

% Correction des dimensions spatiales.
FOV_X = FOV_X_raw * scaleCorrection;
FOV_Y = FOV_Y_raw * scaleCorrection;

pixel_X = pixel_X_raw * scaleCorrection;
pixel_Y = pixel_Y_raw * scaleCorrection;

% Coordonnees spatiales centrees sur l'image.
if isfinite(pixel_X)
    X_um = ((0:nX-1)-(nX-1)/2)*pixel_X;
elseif isfinite(FOV_X)
    X_um = linspace(-FOV_X/2,FOV_X/2,nX);
else
    X_um = 1:nX;
end

if isfinite(pixel_Y)
    Y_um = ((0:nY-1)-(nY-1)/2)*pixel_Y;
elseif isfinite(FOV_Y)
    Y_um = linspace(-FOV_Y/2,FOV_Y/2,nY);
else
    Y_um = 1:nY;
end

%% 10. Structure de sortie

data.images = images;

data.axes.X = 1:nX;
data.axes.Y = 1:nY;

data.axes.X_um = X_um;
data.axes.Y_um = Y_um;

data.axes.L = L;
data.axes.Z = Z;
data.axes.T = T;

data.mode = mode;
data.pageOrder = pageOrder;

data.hasTime = nT > 1;

data.dimensions.nX = nX;
data.dimensions.nY = nY;
data.dimensions.nL = nL;
data.dimensions.nZ = nZ;
data.dimensions.nT = nT;

% Metadonnees
data.metadata.filename = filename;
data.metadata.numberOfPages = nPages;
data.metadata.imageSizeYX = [nY,nX];

data.metadata.originalClass = inputClass;
data.metadata.outputClass = outputClass;

data.metadata.labview = meta;
data.metadata.tiffInfo = info;

data.metadata.spatialScaleCorrection = scaleCorrection;

data.metadata.FOV_X_um_raw = FOV_X_raw;
data.metadata.FOV_Y_um_raw = FOV_Y_raw;

data.metadata.pixel_size_X_um_raw = pixel_X_raw;
data.metadata.pixel_size_Y_um_raw = pixel_Y_raw;

data.metadata.FOV_X_um = FOV_X;
data.metadata.FOV_Y_um = FOV_Y;

data.metadata.pixel_size_X_um = pixel_X;
data.metadata.pixel_size_Y_um = pixel_Y;

data.metadata.axisLName = 'Lambda';
data.metadata.axisLUnit = 'nm';

%% 11. Affichage du resume

fprintf('\n========== TIFF SRS ==========\n');
fprintf('Fichier : %s\n',filename);
fprintf('Mode : %s\n',mode);
fprintf('Pages : %d\n',nPages);

fprintf('Dimensions [Y X L Z T] : [%d %d %d %d %d]\n', ...
    nY,nX,nL,nZ,nT);

fprintf('Classe des donnees : %s\n',outputClass);

if isfinite(FOV_X) && isfinite(FOV_Y)

    fprintf('FOV corrige : %.3f x %.3f um\n',FOV_X,FOV_Y);

    fprintf('Taille pixel corrigee : %.4f x %.4f um\n', ...
        pixel_X,pixel_Y);

    fprintf('Facteur spatial : x%.2f\n',scaleCorrection);

end

if usesL
    fprintf('Lambda : %.4f - %.4f nm (%d points)\n', ...
        L(1),L(end),nL);
end

if usesZ
    fprintf('Z : %.4f - %.4f um (%d points)\n', ...
        Z(1),Z(end),nZ);
end

fprintf('==============================\n\n');

end


%% ============================================================
%  FONCTIONS LOCALES
%  ============================================================

function meta = extractLabviewMetadata(info)

meta = struct();

if ~isfield(info,'ImageDescription') || ...
        isempty(info.ImageDescription)
    return
end

description = char(info.ImageDescription);

marker = 'Info=LABVIEW_RAMAN|';

idx = strfind(description,marker);

if isempty(idx)
    return
end

startIndex = idx(1) + length(marker);
jsonText = strtrim(description(startIndex:end));

% Suppression d'un eventuel retour a la ligne apres le JSON.
jsonText = regexprep(jsonText,'[\r\n].*$','');

try
    meta = jsondecode(jsonText);
catch ME
    warning('Impossible de decoder les metadonnees LabVIEW : %s',ME.message);
end

end


function n = getCount(cfg,meta,cfgName,metaName)

n = [];

if isfield(cfg,cfgName) && ~isempty(cfg.(cfgName))

    n = checkCount(cfg.(cfgName),cfgName);

elseif isfield(meta,metaName)

    value = meta.(metaName);

    if isnumeric(value) && isscalar(value) && ...
            isfinite(value) && value >= 1

        n = checkCount(value,metaName);

    end
end

if isempty(n)
    error('Nombre de points absent : renseigner cfg.%s.',cfgName);
end

end


function n = checkCount(value,name)

if ~isnumeric(value) || ~isscalar(value) || ...
        ~isfinite(value) || value < 1 || ...
        value ~= floor(value)

    error('%s doit etre un entier positif.',name);

end

n = double(value);

end


function axisValues = getAxis(cfg,name,n)

axisValues = [];

if isfield(cfg,name) && ~isempty(cfg.(name))

    axisValues = cfg.(name);

    if ~isnumeric(axisValues) || numel(axisValues) ~= n
        error('cfg.%s doit contenir %d valeurs.',name,n);
    end

    axisValues = double(axisValues(:).');

end

end


function axisValues = makeLinearAxis(meta,minName,maxName,n)

axisValues = [];

vMin = getNumericMetadata(meta,minName);
vMax = getNumericMetadata(meta,maxName);

if isfinite(vMin) && isfinite(vMax)

    if n == 1
        axisValues = vMin;
    else
        axisValues = linspace(vMin,vMax,n);
    end

end

end


function value = getNumericMetadata(meta,name)

value = NaN;

if isfield(meta,name)

    v = meta.(name);

    if isnumeric(v) && isscalar(v) && isfinite(v)
        value = double(v);
    end

end

end


function tf = logicalValue(value)

if islogical(value)
    tf = value;

elseif isnumeric(value)
    tf = value ~= 0;

elseif ischar(value) || isstring(value)
    tf = any(strcmpi(string(value),["true","1","yes"]));

else
    tf = false;
end

end
