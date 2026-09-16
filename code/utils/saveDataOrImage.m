function saveDataOrImage(data, sub_dir_save, varargin)
    %
    % SAVEDATAORIMAGE Sauvegarde une structure ou une image dans un sous-dossier.
    %
    %   Inputs:
    %       - data: Structure MATLAB ou matrice (image 2D/3D).
    %       - sub_dir_save: Chemin relatif ou absolu du sous-dossier où sauvegarder.
    %       - varargin: Options supplémentaires :
    %           * 'Name' (char) : Nom du fichier (sans extension).
    %             Par défaut : 'data' pour une structure, 'image' pour une matrice.
    %           * 'Format' (char) : Format de sauvegarde pour les images.
    %             Options : 'png', 'jpg', 'tif', 'mat' (pour les structures).
    %             Par défaut : 'mat' pour les structures, 'png' pour les images.
    %
    %   Exemples:
    %       saveDataOrImage(myStruct, 'results/structures', 'Name', 'my_struct', 'Format', 'mat');
    %       saveDataOrImage(myImage, 'results/images', 'Name', 'my_image', 'Format', 'png');

    % --- Vérifier les arguments ---
    if nargin < 2
        error('Il faut au moins deux arguments : data et sub_dir_save.');
    end

    % --- Définir les valeurs par défaut ---
    fileName = 'data'; % Nom par défaut
    format = 'mat';    % Format par défaut

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

    % --- Créer le sous-dossier s'il n'existe pas ---
    if ~exist(sub_dir_save, 'dir')
        mkdir(sub_dir_save);
        fprintf('Dossier créé : %s\n', sub_dir_save);
    end

    % --- Déterminer le type de données ---
    isStruct = isstruct(data);
    isImage = ~isStruct && (ndims(data) == 2 || ndims(data) == 3);

    % --- Sauvegarder selon le type ---
    if isStruct
        % Sauvegarder une structure en .mat
        if ~strcmp(format, 'mat')
            warning('Format "%s" ignoré pour une structure. Utilisation de .mat.', format);
            format = 'mat';
        end
        fullPath = fullfile(sub_dir_save, [fileName, '.mat']);
        save(fullPath, 'data');
        fprintf('Structure sauvegardée : %s\n', fullPath);

    elseif isImage
        % Sauvegarder une image
        if ~ismember(format, {'png', 'jpg', 'tif', 'mat'})
            warning('Format "%s" non supporté pour une image. Utilisation de .png.', format);
            format = 'png';
        end

        fullPath = fullfile(sub_dir_save, [fileName, '.', format]);

        if strcmp(format, 'mat')
            save(fullPath, 'data');
        else
            % Normaliser l'image pour les formats comme PNG/JPG
            if isfloat(data) && max(data(:)) > 1
                data = mat2gray(data);
            end
            imwrite(data, fullPath);
        end
        fprintf('Image sauvegardée : %s\n', fullPath);

    else
        error('Le type de données n''est ni une structure ni une image (2D/3D).');
    end
end