

function SRS = load_SRS_TIFF_only(folder, cfg)
% LOAD_SRS_TIFF_ONLY
% Charge une acquisition SRS depuis un dossier contenant un ou plusieurs
% fichiers TIFF.
%
% Organisation de sortie :
%   SRS.data : [Y X L Z T]
%
% Les dimensions X, Y, L et Z sont lues exclusivement dans Labview_data.
% T est déterminé selon l'organisation du timelapse :
%   - XY, XYL, XYZ : N_timepoints_written dans Labview_data.
%   - XYLZ, XYZL   : nombre de fichiers suffixés _tXXXX.
%   - Sans timelapse : T = 1.
%
% Le canal C est une dimension technique du TIFF :
%   - seul C=1 est chargé ;
%   - les images C=2 et suivantes sont ignorées ;
%   - C n'est pas une dimension de SRS.data.
%
% CONFIGURATION :
%   cfg.acquisition     = '';       % Préfixe, ex. 261119_161813_XYL_0000
%   cfg.pageOrder       = 'auto';   % 'auto', 'LZ' ou 'ZL'
%   cfg.channelOrder    = 'auto';   % 'auto', 'interleaved', 'block',
%                                   % 'timepoint-block'
%   cfg.checkZeroImages = false;    % Détection des images C=1 entièrement nulles
%   cfg.wavenumber      = [];       % Axe spectral imposé (optionnel)
%   cfg.wl_ir_nm        = 1031.3;   % Longueur d'onde IR
%
% ORDRE DES CANAUX :
%   interleaved :
%       C1, C2, C1, C2, ...
%   block :
%       toutes les images C1, puis toutes les images C2 dans le fichier
%   timepoint-block :
%       pour chaque T, toutes les images C1 puis toutes les images C2
%
% Avec channelOrder='auto', l'axe C déclaré dans Labview_data.axes
% est utilisé. Si C est présent, l'ordre interleaved est retenu.
% Si SizeC>1 mais que l'ordre ne peut pas être déterminé, une erreur
% est déclenchée plutôt que de risquer de mélanger les images.
%
% ORDRE L/Z :
%   LZ : L varie le plus rapidement, puis Z.
%   ZL : Z varie le plus rapidement, puis L.
%
% Avec pageOrder='auto', la convention utilisée est :
%   XY, XYZ, XYZL : ZL
%   XYL, XYLZ     : LZ
%
% EXEMPLE :
%   cfg.checkZeroImages = true;
%   SRS = load_SRS_TIFF_only('D:\Data\261119', cfg);

    %% 1. Sélection du dossier

    if nargin < 1 || isempty(folder)
        folder = uigetdir(pwd, 'Sélectionner le dossier de l''acquisition SRS');

        if isequal(folder, 0)
            error('Aucun dossier sélectionné.');
        end
    end

    if isstring(folder)
        folder = char(folder);
    end

    if ~isfolder(folder)
        error('Dossier introuvable : %s', folder);
    end

    if nargin < 2 || isempty(cfg)
        cfg = struct();
    end

    %% 2. Configuration

    cfg = setDefault(cfg, 'acquisition', '');
    cfg = setDefault(cfg, 'pageOrder', 'auto');
    cfg = setDefault(cfg, 'channelOrder', 'auto');
    cfg = setDefault(cfg, 'checkZeroImages', false);
    cfg = setDefault(cfg, 'wavenumber', []);
    cfg = setDefault(cfg, 'wl_ir_nm', 1031.3);

    cfg.pageOrder = upper(char(cfg.pageOrder));
    cfg.channelOrder = lower(char(cfg.channelOrder));

    if ~ismember(cfg.pageOrder, {'AUTO','LZ','ZL'})
        error('cfg.pageOrder doit être auto, LZ ou ZL.');
    end

    if ~ismember(cfg.channelOrder, ...
            {'auto','interleaved','block','timepoint-block'})
        error(['cfg.channelOrder doit être auto, interleaved, ', ...
               'block ou timepoint-block.']);
    end

    %% 3. Recherche des fichiers TIFF et identification de l'acquisition

    fprintf('\n========================================\n');
    fprintf('       CHARGEMENT DE L''ACQUISITION SRS\n');
    fprintf('========================================\n');

    fprintf('Dossier : %s\n', folder);

    entries = findAcquisitionFiles(folder);

    if isempty(entries)
        error('Aucun fichier TIFF correspondant au format attendu dans le dossier.');
    end

    % Choix du préfixe de l'acquisition
    if isempty(cfg.acquisition)

        acquisitionBases = unique({entries.base});

        if numel(acquisitionBases) > 1
            fprintf('\nPlusieurs acquisitions ont été trouvées :\n');

            for k = 1:numel(acquisitionBases)
                fprintf('  %s\n', acquisitionBases{k});
            end

            error(['Plusieurs acquisitions sont présentes dans le dossier. ', ...
                   'Renseigner cfg.acquisition avec le préfixe souhaité.']);
        end

        acquisitionBase = acquisitionBases{1};

    else

        acquisitionBase = char(cfg.acquisition);

        % Accepte éventuellement un nom avec extension
        [~, acquisitionBase, ~] = fileparts(acquisitionBase);

        % Supprime un éventuel suffixe temporel
        acquisitionBase = regexprep(acquisitionBase, '_t\d{4}$', '');

        if ~any(strcmp({entries.base}, acquisitionBase))
            error('Acquisition introuvable : %s', acquisitionBase);
        end

    end

    acquisitionEntries = entries(strcmp({entries.base}, acquisitionBase));

    %% 4. Lecture de Labview_data

    % Lecture des métadonnées du premier fichier de l'acquisition.
    % Le choix du fichier définitif dépend du type de timelapse, déterminé
    % à partir de Labview_data.
    firstFilename = fullfile(folder, acquisitionEntries(1).name);

    firstInfo = imfinfo(firstFilename);

    if isempty(firstInfo)
        error('Impossible de lire le TIFF : %s', firstFilename);
    end

    labviewData = extractLabviewData(firstInfo(1));

    %% 5. Lecture du type de scan et du timelapse

    scanType = upper(strtrim(char(getRequiredValue( ...
        labviewData, {'scan_type','ScanType','scanType'}))));

    supportedScanTypes = {'XY','XYL','XYZ','XYLZ','XYZL'};

    if ~ismember(scanType, supportedScanTypes)
        error('scan_type non reconnu : %s', scanType);
    end

    % Détection du timelapse à partir des métadonnées LabVIEW
    timelapse_metadata = getRequiredLogical( ...
        labviewData, ...
        {'timelapse','TimeLapse','time_lapse'});
    
    % Détection du timelapse à partir des noms des fichiers TIFF
    % Exemple : 261118_104731_XYZL_0000_t0000.tiff
    
    hasTimepointFiles = any([acquisitionEntries.hasTimepoint]);
    
    % Le timelapse est actif si l'une des deux conditions est vérifiée
    timelapse = timelapse_metadata || hasTimepointFiles;

    fprintf('\nScan type : %s\n', scanType);
    fprintf('Timelapse : %d\n', timelapse);

    %% 6. Détermination des dimensions expérimentales

    % X et Y sont obligatoires.
    nX = getDimension(labviewData, {'X','SizeX'}, []);
    nY = getDimension(labviewData, {'Y','SizeY'}, []);

    % L et Z peuvent être absents ou égaux à N/A si leur dimension
    % n'existe pas pour le type de scan considéré.
    nL = getDimension(labviewData, {'L','SizeL'}, 1);
    nZ = getDimension(labviewData, {'Z','SizeZ'}, 1);

    % Cohérence entre scan_type et dimensions.
    switch scanType

        case 'XY'
            if nL ~= 1 || nZ ~= 1
                error('Incohérence : scan XY avec L ou Z non singleton.');
            end

        case 'XYL'
            if nL <= 1 || nZ ~= 1
                error('Incohérence des dimensions pour scan XYL.');
            end

        case 'XYZ'
            if nZ <= 1 || nL ~= 1
                error('Incohérence des dimensions pour scan XYZ.');
            end

        case {'XYLZ','XYZL'}
            if nL <= 1 || nZ <= 1
                error('Les scans XYLZ et XYZL nécessitent L>1 et Z>1.');
            end

    end

    %% 7. Détermination de SizeC

    % SizeC n'est pas une dimension expérimentale.
    % Si SizeC n'est pas renseigné, on utilise le nombre d'entrées
    % du champ channels de Labview_data.
    nC = getOptionalPositiveInteger( ...
        labviewData, {'SizeC','C'}, []);

    if isempty(nC)
        nC = getChannelCount(labviewData);
    end

    if isempty(nC)
        nC = 1;
    end

    if nC < 1
        error('Nombre de canaux C invalide.');
    end

    % Détermination de l'ordre des canaux.
    if strcmp(cfg.channelOrder, 'auto')

        axesOrder = getOptionalText(labviewData, {'axes','Axes'});

        if nC == 1
            channelOrder = 'interleaved';

        elseif contains(upper(axesOrder), 'C')
            % Avec un axe C déclaré, on suppose que C varie entre
            % les pages d'une même position dans les autres dimensions.
            channelOrder = 'interleaved';

        else
            error(['SizeC=%d mais l''ordre des canaux ne peut pas être ', ...
                   'déduit de Labview_data.axes. Renseigner ', ...
                   'cfg.channelOrder explicitement.'], nC);
        end

    else
        channelOrder = cfg.channelOrder;
    end

    fprintf('\nDimensions Labview_data :\n');
    fprintf('X=%d, Y=%d, L=%d, Z=%d\n', nX,nY,nL,nZ);
    fprintf('SizeC détecté = %d\n', nC);
    fprintf('Canal conservé = C1 uniquement\n');
    fprintf('Ordre des canaux = %s\n', channelOrder);

    %% 8. Détermination de l'ordre des pages L/Z

    if strcmp(cfg.pageOrder, 'AUTO')

        switch scanType

            case {'XYL','XYLZ'}
                pageOrder = 'LZ';

            case {'XY','XYZ','XYZL'}
                pageOrder = 'ZL';

        end

    else
        pageOrder = cfg.pageOrder;
    end

    fprintf('Ordre des pages L/Z = %s\n', pageOrder);

    %% 9. Détermination de l'organisation temporelle

    % Les trois scans XY, XYL et XYZ stockent T dans un même TIFF.
    % Les scans XYLZ et XYZL stockent un fichier TIFF par timepoint.

    singleFileTimelapse = timelapse && ...
        ismember(scanType, {'XY','XYL','XYZ'});

    multiFileTimelapse = timelapse && ...
        ismember(scanType, {'XYLZ','XYZL'});

    if singleFileTimelapse

        % T est lu dans Labview_data.
        nT = getRequiredNumber(labviewData, ...
            {'N_timepoints_written','N_Timepoints_Written'});

        if nT ~= round(nT) || nT < 1
            error('N_timepoints_written doit être un entier positif.');
        end

        selectedEntries = acquisitionEntries( ...
            isnan([acquisitionEntries.timepoint]));

        if numel(selectedEntries) ~= 1
            error(['Un timelapse %s doit être stocké dans un seul TIFF ', ...
                   'sans suffixe _tXXXX.'], scanType);
        end

        timepointNumbers = 1:nT;

        files = {selectedEntries.name};

        % Tous les T sont dans le même fichier.
        timepointsPerFile = nT;

    elseif multiFileTimelapse

        % T est déterminé par le nombre de fichiers _tXXXX.
        selectedEntries = acquisitionEntries( ...
            ~isnan([acquisitionEntries.timepoint]));

        if isempty(selectedEntries)
            error(['Timelapse %s détecté, mais aucun fichier ', ...
                   'suffixé _tXXXX n''a été trouvé.'], scanType);
        end

        tp = [selectedEntries.timepoint];

        [tp, sortIdx] = sort(tp);
        selectedEntries = selectedEntries(sortIdx);

        % Les timepoints doivent commencer à 0000 et être consécutifs.
        expectedTP = 0:numel(tp)-1;

        if ~isequal(tp, expectedTP)
            error(['Les suffixes temporels doivent être consécutifs ', ...
                   'et commencer à t0000. Timepoints détectés : %s'], ...
                   mat2str(tp));
        end

        nT = numel(selectedEntries);
        timepointNumbers = tp;

        files = {selectedEntries.name};

        % Un seul T par fichier.
        timepointsPerFile = 1;

    else

        % Pas de timelapse : un seul TIFF sans suffixe temporel.
        if timelapse
            error('Organisation temporelle non prise en charge.');
        end

        selectedEntries = acquisitionEntries( ...
            isnan([acquisitionEntries.timepoint]));

        if numel(selectedEntries) ~= 1
            error(['Sans timelapse, un seul TIFF sans suffixe _tXXXX ', ...
                   'est attendu pour cette acquisition.']);
        end

        nT = 1;
        timepointNumbers = 1;
        files = {selectedEntries.name};
        timepointsPerFile = 1;

    end

    nFiles = numel(files);

    fprintf('\nOrganisation temporelle :\n');
    fprintf('Nombre de fichiers utilisés : %d\n', nFiles);
    fprintf('Nombre de timepoints T : %d\n', nT);

    for k = 1:nFiles
        fprintf('  T fichier %d : %s\n', k, files{k});
    end

    %% 10. Vérification de la cohérence des métadonnées entre fichiers

    infos = cell(nFiles,1);
    metadataPerFile = cell(nFiles,1);
    nPagesPerFile = zeros(nFiles,1);

    for f = 1:nFiles

        filename = fullfile(folder, files{f});

        infos{f} = imfinfo(filename);
        nPagesPerFile(f) = numel(infos{f});

        if isempty(infos{f})
            error('TIFF vide : %s', filename);
        end

        metadataPerFile{f} = extractLabviewData(infos{f}(1));

        meta = metadataPerFile{f};

        % Dimensions identiques pour tous les timepoints.
        checkDimension(meta, {'X','SizeX'}, nX, 'X');
        checkDimension(meta, {'Y','SizeY'}, nY, 'Y');
        checkDimension(meta, {'L','SizeL'}, nL, 'L');
        checkDimension(meta, {'Z','SizeZ'}, nZ, 'Z');

        scanTypeFile = upper(strtrim(char(getRequiredValue( ...
            meta, {'scan_type','ScanType','scanType'}))));

        if ~strcmp(scanTypeFile, scanType)
            error('scan_type incohérent dans le fichier %s.', files{f});
        end

        timelapseFile = getRequiredLogical( ...
            meta, {'timelapse','TimeLapse','time_lapse'});
% 
%         if timelapseFile ~= timelapse
%             error('Métadonnée timelapse incohérente dans %s.', files{f});
%         end

    end

    %% 11. Vérification des dimensions spatiales TIFF

    for f = 1:nFiles

        info = infos{f};

        for p = 1:numel(info)

            if info(p).Width ~= nX || info(p).Height ~= nY
                error(['Dimensions incorrectes dans %s, page %d.\n', ...
                       'Attendu : %d x %d ; obtenu : %d x %d'], ...
                    files{f}, p, nX, nY, ...
                    info(p).Height, info(p).Width);
            end

        end

    end

    %% 12. Vérification stricte du nombre de pages

    nLogicalPerT = nL*nZ;

    if singleFileTimelapse
        nExpectedPerFile = nLogicalPerT*nT*nC;
    else
        nExpectedPerFile = nLogicalPerT*nC;
    end

    for f = 1:nFiles

        if nPagesPerFile(f) ~= nExpectedPerFile

            error(['Nombre de pages incorrect dans %s.\n', ...
                   'Pages présentes : %d\n', ...
                   'Pages attendues : %d\n', ...
                   'L=%d, Z=%d, T dans le fichier=%d, C=%d\n\n', ...
                   'Le chargement est interrompu pour éviter ', ...
                   'un décalage des dimensions.'], ...
                files{f}, nPagesPerFile(f), nExpectedPerFile, ...
                nL, nZ, timepointsPerFile, nC);

        end

    end

    %% 13. Chargement de C=1 uniquement

    fprintf('\nChargement des images C=1...\n');

    % Tableau de sortie [Y X L Z T].
    data = nan(nY,nX,nL,nZ,nT,'double');

    selectedPageIndices = cell(nFiles,1);

    zeroImageInfo = struct( ...
        'T',{}, ...
        'file',{}, ...
        'page',{}, ...
        'L',{}, ...
        'Z',{});

    for f = 1:nFiles

        filename = fullfile(folder, files{f});
        selectedPageIndices{f} = zeros(nLogicalPerT*timepointsPerFile,1);

        for localT = 1:timepointsPerFile

            % T global correspondant au fichier et au timepoint local.
            if singleFileTimelapse
                globalT = localT;
            else
                globalT = f;
            end

            for kLogical = 1:nLogicalPerT

                %% Indexation de la page physique C=1

                switch channelOrder

                    case 'interleaved'
                        % C1,C2,C1,C2,...
                        pageIndex = ...
                            ((localT-1)*nLogicalPerT + kLogical-1)*nC + 1;

                    case 'block'
                        % Toutes les images C1, puis toutes les images C2.
                        pageIndex = (localT-1)*nLogicalPerT + kLogical;

                    case 'timepoint-block'
                        % Pour chaque T : bloc C1 puis bloc C2.
                        pageIndex = ...
                            (localT-1)*nLogicalPerT*nC + kLogical;

                    otherwise
                        error('Ordre des canaux non reconnu.');

                end

                selectedIndex = (localT-1)*nLogicalPerT + kLogical;
                selectedPageIndices{f}(selectedIndex) = pageIndex;

                %% Lecture de l'image

                try
                    I = double(imread(filename,pageIndex));
                catch ME
                    error('Erreur lecture %s, page %d : %s', ...
                        files{f}, pageIndex, ME.message);
                end

                if ~ismatrix(I) || ~isequal(size(I),[nY nX])
                    error('La page %d de %s n''est pas une image XY valide.', ...
                        pageIndex, files{f});
                end

                %% Indexation des dimensions L et Z

                if strcmp(pageOrder,'LZ')
                    [iL,iZ] = ind2sub([nL nZ],kLogical);
                else
                    [iZ,iL] = ind2sub([nZ nL],kLogical);
                end

                %% Vérification facultative des images nulles

                if cfg.checkZeroImages && all(I(:)==0)

                    zeroImageInfo(end+1) = struct( ...
                        'T',globalT, ...
                        'file',files{f}, ...
                        'page',pageIndex, ...
                        'L',iL, ...
                        'Z',iZ); %#ok<AGROW>

                end

                %% Stockage

                data(:,:,iL,iZ,globalT) = I;

            end
        end
    end

    fprintf('Chargement C=1 terminé.\n');

    %% 14. Rapport des images nulles

    if cfg.checkZeroImages

        fprintf('\nVérification des images entièrement nulles (C=1) :\n');
        fprintf('Images nulles : %d / %d\n', ...
            numel(zeroImageInfo), nLogicalPerT*nT);

        if ~isempty(zeroImageInfo)

            warning('%d images C=1 sont entièrement nulles.', ...
                numel(zeroImageInfo));

            for k = 1:numel(zeroImageInfo)

                z = zeroImageInfo(k);

                fprintf(['  T=%d, L=%d, Z=%d, page=%d, ', ...
                         'fichier=%s\n'], ...
                    z.T,z.L,z.Z,z.page,z.file);

            end

        else
            fprintf('Aucune image nulle détectée.\n');
        end

    end

    %% 15. Construction de l'axe spectral

    fprintf('\nConstruction de l''axe spectral...\n');

    if ~isempty(cfg.wavenumber)

        wavenumber = cfg.wavenumber(:);

        if numel(wavenumber) ~= nL
            error('cfg.wavenumber doit contenir %d valeurs.',nL);
        end

        if any(~isfinite(wavenumber))
            error('cfg.wavenumber contient des valeurs non finies.');
        end

        wavelength = NaN(nL,1);

    elseif nL > 1

        min_wl = getRequiredScalar(labviewData, ...
            {'min_wl','Lambda_min_nm'});

        max_wl = getRequiredScalar(labviewData, ...
            {'max_wl','Lambda_max_nm'});

        if min_wl <= 0 || max_wl <= 0 || max_wl < min_wl
            error('Longueurs d''onde invalides dans Labview_data.');
        end

        wavelength = linspace(min_wl,max_wl,nL).';

        wavenumber = 1e7./wavelength - ...
                     1e7./cfg.wl_ir_nm;

    else

        wavelength = NaN(nL,1);
        wavenumber = NaN(nL,1);

    end

    %% 16. Tri spectral

    if nL > 1

        [wavenumber,sortIdx] = sort(wavenumber,'ascend');

        data = data(:,:,sortIdx,:,:);

        if all(isfinite(wavelength))
            wavelength = wavelength(sortIdx);
        end

    end

    %% 17. Vérification finale

    if size(data,1) ~= nY || ...
       size(data,2) ~= nX || ...
       size(data,3) ~= nL || ...
       size(data,4) ~= nZ || ...
       size(data,5) ~= nT

        error('Dimensions finales incorrectes.');
    end

    if ~any(isfinite(data(:)))
        error('Aucune donnée valide après chargement.');
    end

    fprintf('\nDimensions finales : [Y=%d X=%d L=%d Z=%d T=%d]\n', ...
        nY,nX,nL,nZ,nT);

    fprintf('Minimum : %.6g\n',min(data(:),[],'omitnan'));
    fprintf('Maximum : %.6g\n',max(data(:),[],'omitnan'));

    %% 18. Structure de sortie

    SRS = struct();

    SRS.folder = folder;
    SRS.acquisition = acquisitionBase;
    SRS.filename = fullfile(folder,files{1});
    SRS.files = cellfun(@(f) fullfile(folder,f), ...
        files, 'UniformOutput', false);

    SRS.metadata = labviewData;

    SRS.scan_type = scanType;
    SRS.timelapse = timelapse;

    SRS.pageOrder = pageOrder;
    SRS.channelOrder = channelOrder;

    SRS.dimensions = struct( ...
        'X',nX, ...
        'Y',nY, ...
        'L',nL, ...
        'Z',nZ, ...
        'T',nT, ...
        'C',1);

    % Informations diagnostiques sur C.
    SRS.detectedSizeC = nC;
    SRS.selectedChannel = 1;
    SRS.discardedChannels = 2:nC;

    SRS.wavenumber = wavenumber;
    SRS.wavelength = wavelength;

    SRS.data = data;

    SRS.nPages = nPagesPerFile;
    SRS.nPagesLoaded = nLogicalPerT*nT;

    SRS.selectedPageIndices = selectedPageIndices;

    SRS.zeroImageInfo = zeroImageInfo;
    SRS.zeroImageCount = numel(zeroImageInfo);

    SRS.loadedTimepoint = 1:nT;
    SRS.timepointNumbers = timepointNumbers;

    fprintf('\n========================================\n');
    fprintf('     CHARGEMENT TERMINÉ AVEC SUCCÈS\n');
    fprintf('========================================\n\n');

end


%% ========================================================================
% FONCTIONS AUXILIAIRES
% ========================================================================

function cfg = setDefault(cfg,field,value)

    if ~isfield(cfg,field) || isempty(cfg.(field))
        cfg.(field) = value;
    end

end


function entries = findAcquisitionFiles(folder)
% FINDACQUISITIONFILES
% Identifie les fichiers d'acquisition SRS dans un dossier.
%
% Formats acceptés :
%   YYMMDD_HHMMSS_SCAN_XXXX.tiff
%   YYMMDD_HHMMSS_SCAN_XXXX_tYYYY.tiff
%
% Exemple :
%   261119_161813_XYL_0000.tiff
%   261118_104731_XYZL_0000_t0000.tiff

    files = [dir(fullfile(folder, '*.tif')); ...
             dir(fullfile(folder, '*.tiff'))];

    entries = struct( ...
        'filename', {}, ...
        'name', {}, ...
        'fullpath', {}, ...
        'acquisition', {}, ...
        'base', {}, ...
        'scanType', {}, ...
        'scanNumber', {}, ...
        'timepoint', {}, ...
        'hasTimepoint', {});

    for k = 1:numel(files)

        [~, stem, ~] = fileparts(files(k).name);

        % Découpage du nom sans extension
        parts = strsplit(stem, '_');

        % Format minimal :
        % date / heure / scan_type / numéro_acquisition
        if numel(parts) < 4
            continue;
        end

        % Vérification du format date et heure
        if isempty(regexp(parts{1}, '^\d{6}$', 'once')) || ...
           isempty(regexp(parts{2}, '^\d{6}$', 'once'))
            continue;
        end

        scanType = upper(parts{3});
        scanNumber = parts{4};

        if isempty(regexp(scanNumber, '^\d{4}$', 'once'))
            continue;
        end

        % Préfixe commun à tous les fichiers d'une acquisition
        acquisition = strjoin(parts(1:4), '_');

        % Détection éventuelle du numéro de timepoint
        hasTimepoint = false;
        timepoint = NaN;

        if numel(parts) >= 5
            tpToken = parts{5};

            if ~isempty(regexp(tpToken, '^t\d{4}$', 'once'))
                hasTimepoint = true;
                timepoint = str2double(tpToken(2:end));
            else
                continue;
            end
        end

        % Enregistrement
        entries(end+1) = struct( ...
            'filename', files(k).name, ...
            'name', files(k).name, ...
            'fullpath', fullfile(folder, files(k).name), ...
            'acquisition', acquisition, ...
            'base', acquisition, ...
            'scanType', scanType, ...
            'scanNumber', scanNumber, ...
            'timepoint', timepoint, ...
            'hasTimepoint', hasTimepoint);
    end

    if isempty(entries)
        error('Aucun fichier TIFF correspondant au format attendu dans : %s', ...
              folder);
    end
end


function labviewData = extractLabviewData(info)

    if ~isfield(info,'ImageDescription')
        error('ImageDescription absente du TIFF.');
    end

    description = char(info.ImageDescription);

    marker = 'Info=LABVIEW_RAMAN|';
    idx = strfind(description,marker);

    if isempty(idx)
        error('Bloc Info=LABVIEW_RAMAN introuvable.');
    end

    startIndex = idx(1)+length(marker);
    jsonText = strtrim(description(startIndex:end));

    endJSON = find(jsonText=='}',1,'last');

    if isempty(endJSON)
        error('Bloc JSON LabVIEW invalide.');
    end

    jsonText = jsonText(1:endJSON);

    try
        decoded = jsondecode(jsonText);
    catch ME
        error('Erreur de décodage du JSON LabVIEW : %s',ME.message);
    end

    fields = fieldnames(decoded);
    idxLV = find(strcmpi(fields,'Labview_data'),1);

    if ~isempty(idxLV)
        labviewData = decoded.(fields{idxLV});
    else
        labviewData = decoded;
    end

    if ~isstruct(labviewData)
        error('Labview_data doit être une structure.');
    end

end


function [value,found] = getFieldCI(meta,names)

    value = [];
    found = false;

    if ~isstruct(meta)
        return;
    end

    fields = fieldnames(meta);

    for k = 1:numel(names)

        idx = find(strcmpi(fields,names{k}),1);

        if ~isempty(idx)
            value = meta.(fields{idx});
            found = true;
            return;
        end

    end

end


function value = getRequiredValue(meta,names)

    [value,found] = getFieldCI(meta,names);

    if ~found
        error('Champ Labview_data manquant : %s',strjoin(names,' / '));
    end

end


function value = getRequiredScalar(meta,names)

    raw = getRequiredValue(meta,names);

    if isnumeric(raw) && isscalar(raw)
        value = double(raw);

    elseif ischar(raw) || (isstring(raw) && isscalar(raw))
        value = str2double(strtrim(char(raw)));

    else
        value = NaN;
    end

    if ~isscalar(value) || ~isfinite(value)
        error('Valeur numérique invalide dans Labview_data : %s', ...
            strjoin(names,' / '));
    end

end


function value = getRequiredNumber(meta,names)

    value = getRequiredScalar(meta,names);

    if value < 1
        error('Valeur numérique invalide : %s doit être >= 1.', ...
            strjoin(names,' / '));
    end

end


function value = getDimension(meta,names,defaultValue)

    [raw,found] = getFieldCI(meta,names);

    if ~found
        if isempty(defaultValue)
            error('Dimension obligatoire absente de Labview_data : %s', ...
                strjoin(names,' / '));
        end

        value = defaultValue;
        return;
    end

    if isnumeric(raw) && isscalar(raw) && isfinite(raw)

        value = double(raw);

    elseif ischar(raw) || (isstring(raw) && isscalar(raw))

        str = strtrim(char(raw));

        if isempty(str) || strcmpi(str,'N/A') || ...
                strcmpi(str,'NA') || strcmpi(str,'NaN')

            if isempty(defaultValue)
                error('Dimension %s non renseignée dans Labview_data.', ...
                    strjoin(names,' / '));
            end

            value = defaultValue;
            return;
        end

        value = str2double(str);

    else
        value = NaN;
    end

    if ~isscalar(value) || ~isfinite(value) || ...
            value < 1 || value ~= round(value)

        error('Dimension invalide dans Labview_data : %s', ...
            strjoin(names,' / '));
    end

end


function value = getOptionalPositiveInteger(meta,names,defaultValue)

    [raw,found] = getFieldCI(meta,names);

    if ~found
        value = defaultValue;
        return;
    end

    if isnumeric(raw) && isscalar(raw) && isfinite(raw)

        value = double(raw);

    elseif ischar(raw) || (isstring(raw) && isscalar(raw))

        str = strtrim(char(raw));

        if isempty(str) || strcmpi(str,'N/A') || strcmpi(str,'NA')
            value = defaultValue;
            return;
        end

        value = str2double(str);

    else
        value = NaN;
    end

    if ~isscalar(value) || ~isfinite(value) || ...
            value < 1 || value ~= round(value)

        error('Valeur invalide pour %s.',strjoin(names,' / '));
    end

end


function value = getChannelCount(meta)

    value = [];

    [channels,found] = getFieldCI(meta,{'channels','Channels'});

    if found

        if iscell(channels) || isstring(channels) || ischar(channels)
            value = numel(channels);

        elseif isstruct(channels)
            value = numel(channels);

        elseif isnumeric(channels)
            value = numel(channels);
        end

    end

end


function value = getOptionalText(meta,names)

    [raw,found] = getFieldCI(meta,names);

    if ~found || isempty(raw)
        value = '';
        return;
    end

    if ischar(raw)
        value = strtrim(raw);

    elseif isstring(raw) && isscalar(raw)
        value = strtrim(char(raw));

    else
        value = '';
    end

end


function value = getRequiredLogical(meta, names)
% GETREQUIREDLOGICAL
% Lit un champ logique dans les métadonnées.
% Si le champ est absent, retourne false.

    value = false;

    for k = 1:numel(names)

        fieldName = names{k};

        if isfield(meta, fieldName)

            raw = meta.(fieldName);

            if isempty(raw)
                value = false;

            elseif islogical(raw) || isnumeric(raw)
                value = logical(raw(1));

            elseif ischar(raw) || isstring(raw)

                str = lower(strtrim(char(raw)));

                if any(strcmp(str, {'true','1','yes','oui'}))
                    value = true;

                elseif any(strcmp(str, {'false','0','no','non',''}))
                    value = false;

                else
                    error('Valeur invalide pour Labview_data.%s : %s', ...
                          fieldName, str);
                end
            else
                error('Type non reconnu pour Labview_data.%s.', ...
                      fieldName);
            end

            return;
        end
    end

    % Champ absent : considéré comme false
end


function checkDimension(meta,names,expected,label)

    actual = getDimension(meta,names,expected);

    if actual ~= expected
        error('Dimension %s incohérente entre les fichiers.',label);
    end

end


