function [wavenumber, intensite] = lire_spectre_raman(filepath, filename)
% LIRE_SPECTRE_RAMAN Lit un fichier spectre Raman (.l6s ou similaire)
%
% Entrées :
%   filepath : chemin du dossier
%   filename : nom du fichier (ex: 'vat_alons_bis_x100.l6s')
%
% Sorties :
%   wavenumber : vecteur des nombres d'onde (cm^-1)
%   intensite  : vecteur des intensités

    % Construction du chemin complet
    fullpath = fullfile(filepath, filename);

    % Vérification existence
    if ~isfile(fullpath)
        error('Fichier introuvable : %s', fullpath);
    end

    % Initialisation
    wavenumber = [];
    intensite = [];

    % --- Tentative lecture texte ---
    try
        data = readmatrix(fullpath);

        if size(data,2) >= 2
            wavenumber = data(:,1);
            intensite  = data(:,2);
        else
            error('Format inattendu (moins de 2 colonnes)');
        end

    catch
        warning('Lecture texte échouée, tentative lecture binaire...');

        % --- Lecture binaire brute ---
        fid = fopen(fullpath, 'r');
        raw = fread(fid, 'float32'); % type à ajuster si besoin
        fclose(fid);

        % Hypothèse : données intercalées [x1 y1 x2 y2 ...]
        if mod(length(raw),2) ~= 0
            error('Nombre de points impair : format inconnu');
        end

        raw = reshape(raw, 2, [])';
        wavenumber = raw(:,1);
        intensite  = raw(:,2);
    end

    % --- Nettoyage éventuel ---
    % Supprime les NaN ou lignes invalides
    valid = ~(isnan(wavenumber) | isnan(intensite));
    wavenumber = wavenumber(valid);
    intensite  = intensite(valid);

end