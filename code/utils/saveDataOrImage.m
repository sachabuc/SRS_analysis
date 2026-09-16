function saveDataOrImage(data, sub_dir_save, varargin)
    %
    % SAVEDATAORIMAGE Sauvegarde une structure ou une image.
    %
    %   Inputs:
    %       - data: Structure MATLAB ou matrice (image 2D/3D).
    %       - sub_dir_save: Chemin du dossier de sauvegarde.
    %       - varargin:
    %           * 'Name'   : Nom du fichier sans extension.
    %           * 'Format' : 'png', 'jpg', 'tif', 'mat'.
    %

    % --- Vérifier les arguments ---
    if nargin < 2
        error('Il faut au moins deux arguments : data et sub_dir_save.');
    end

    % --- Valeurs par défaut ---
    fileName = 'data';
    format = 'mat';

    % --- Parser les options ---
    for i = 1:2:length(varargin)
        switch lower(varargin{i})
            case 'name'
                fileName = varargin{i+1};

            case 'format'
                format = lower(varargin{i+1});

            otherwise
                warning('Option inconnue : %s', varargin{i});
        end
    end

    % --- Créer le dossier s'il n'existe pas ---
    if ~exist(sub_dir_save, 'dir')
        mkdir(sub_dir_save);
        fprintf('Dossier créé : %s\n', sub_dir_save);
    end

    % --- Déterminer le type de données ---
    isStruct = isstruct(data);
    isImage = ~isStruct && (ndims(data) == 2 || ndims(data) == 3);

    % --- Sauvegarder une structure ---
    if isStruct
    
        if ~strcmp(format, 'mat')
            format = 'mat';
        end
    
        fullPath = fullfile(sub_dir_save, [fileName, '.mat']);
    
        % Créer une structure temporaire avec le nom souhaité
        S = struct();
        S.(fileName) = data;
    
        save(fullPath, '-struct', 'S', '-v7.3');
    
        fprintf('Structure sauvegardée : %s\n', fullPath);
    
    
    % --- Sauvegarder une image ---

    elseif isImage

        if ~ismember(format, {'png', 'jpg', 'tif', 'mat'})
            warning(['Format "%s" non supporté pour une image. ', ...
                     'Utilisation de .png.'], format);
            format = 'png';
        end

        fullPath = fullfile(sub_dir_save, [fileName, '.', format]);

        if strcmp(format, 'mat')

            % Pour une matrice, le nom de variable reste "data"
            save(fullPath, 'data');

        else

            % Normaliser l'image pour les formats PNG/JPG
            if isfloat(data) && max(data(:)) > 1
                data = mat2gray(data);
            end

            imwrite(data, fullPath);
        end

        fprintf('Image sauvegardée : %s\n', fullPath);

    else
        error(['Le type de données n''est ni une structure ', ...
               'ni une image (2D/3D).']);
    end
end