
function [data_corrected, noise_matrix, background_matrix] = ...
    correct_SRS_background(data, ROI, params)
% CORRECT_SRS_BACKGROUND
% Estimation et correction du background d'une acquisition SRS.
%
% INPUTS
%   data  : SRS.data, de dimensions [Y X L Z T].
%           Les dimensions singleton peuvent être absentes.
%
%   ROI   : ROI spatial du background. Trois formats possibles :
%           - Rectangle : [x1 x2 y1 y2]
%           - Polygone  : matrice Nx2 contenant [x y]
%           - Masque    : matrice logique [Y X]
%
%   params.show_nois_figures : true/false (défaut : false)
%
% OUTPUTS
%   data_corrected : données corrigées, dimensions [Y X L Z T].
%                    Pour chaque image XY, soustraction de la
%                    médiane du background correspondant.
%
%   noise_matrix   : bruit robuste pour chaque image, dimensions [L Z T].
%                    Calcul : sigma = 1.4826 * MAD.
%
%   background_matrix : médiane du background pour chaque image [L Z T].
%
% Le bruit est calculé indépendamment pour chaque combinaison L, Z, T.
%
% Exemples :
%   [data_corr, noise, bg] = correct_SRS_background( ...
%       SRS.data, [10 30 10 30], params);
%
%   [data_corr, noise, bg] = correct_SRS_background( ...
%       SRS.data, [10 10; 30 10; 30 30; 10 30], params);

    %% 1. Paramètres

    if nargin < 3 || isempty(params)
        params = struct();
    end

    if ~isfield(params, 'show_nois_figures') || ...
            isempty(params.show_nois_figures)
        params.show_nois_figures = false;
    end

    if ~isnumeric(data) || isempty(data)
        error('data doit être un tableau numérique non vide.');
    end

    %% 2. Normalisation des dimensions en [Y X L Z T]

    originalSize = size(data);

    nY = size(data, 1);
    nX = size(data, 2);
    nL = size(data, 3);
    nZ = size(data, 4);
    nT = size(data, 5);

    % Tableau de travail explicitement en 5 dimensions
    data5D = reshape(data, [nY nX nL nZ nT]);

    %% 3. Construction du masque ROI

    if islogical(ROI)

        if ~isequal(size(ROI), [nY nX])
            error('Le masque ROI doit avoir les dimensions [Y X].');
        end

        roiMask = ROI;

    elseif isnumeric(ROI) && isvector(ROI) && numel(ROI) == 4

        % Rectangle : [x1 x2 y1 y2]
        x1 = round(min(ROI(1:2)));
        x2 = round(max(ROI(1:2)));
        y1 = round(min(ROI(3:4)));
        y2 = round(max(ROI(3:4)));

        if x1 < 1 || x2 > nX || y1 < 1 || y2 > nY
            error('Le rectangle ROI dépasse les dimensions de l''image.');
        end

        roiMask = false(nY, nX);
        roiMask(y1:y2, x1:x2) = true;

    elseif isnumeric(ROI) && size(ROI, 2) == 2 && size(ROI, 1) >= 3

        % Polygone : coordonnées [x y]
        [X, Y] = meshgrid(1:nX, 1:nY);
        roiMask = inpolygon(X, Y, ROI(:,1), ROI(:,2));

    else
        error(['Format ROI non reconnu. Utiliser [x1 x2 y1 y2], ' ...
               'un polygone Nx2 ou un masque logique [Y X].']);
    end

    if ~any(roiMask(:))
        error('Le ROI ne contient aucun pixel.');
    end

    %% 4. Initialisation

    data_corrected = nan(size(data5D));

    % Dimensions logiques [L Z T]
    noise_matrix = reshape(nan(nL, nZ, nT), [nL nZ nT]);
    background_matrix = reshape(nan(nL, nZ, nT), [nL nZ nT]);

    %% 5. Correction du background et estimation du bruit

    for it = 1:nT
        for iz = 1:nZ
            for il = 1:nL

                % Image XY courante
                I = data5D(:,:,il,iz,it);

                % Valeurs dans le ROI
                values = I(roiMask);
                values = values(isfinite(values));

                if isempty(values)
                    warning('ROI vide ou non valide pour L=%d, Z=%d, T=%d.', ...
                        il, iz, it);
                    continue;
                end

                % Niveau de background : médiane
                bg = median(values);

                % Bruit robuste : écart-type estimé à partir du MAD
                sigma = robust_sigma(values);

                % Stockage des résultats
                background_matrix(il,iz,it) = bg;
                noise_matrix(il,iz,it) = sigma;

                % Correction de toute l'image XY
                data_corrected(:,:,il,iz,it) = I - bg;

            end
        end
    end

    %% 6. Figures d'évolution du bruit

    if params.show_nois_figures

        % Masque étendu sur les dimensions L, Z, T
        mask5D = repmat(reshape(roiMask, [nY nX 1 1 1]), ...
                        [1 1 nL nZ nT]);

        % -------------------------------------------------------------
        % Bruit en fonction de X
        % Pour chaque colonne, MAD des pixels du ROI, toutes les
        % dimensions Y, L, Z et T confondues.
        % -------------------------------------------------------------

        noise_X = nan(1,nX);

        for ix = 1:nX
            tmp = data5D(:,ix,:,:,:);
            mask = mask5D(:,ix,:,:,:);

            vals = tmp(mask);
            noise_X(ix) = robust_sigma(vals);
        end

        % -------------------------------------------------------------
        % Bruit en fonction de Y
        % -------------------------------------------------------------

        noise_Y = nan(1,nY);

        for iy = 1:nY
            tmp = data5D(iy,:,:,:,:);
            mask = mask5D(iy,:,:,:,:);

            vals = tmp(mask);
            noise_Y(iy) = robust_sigma(vals);
        end

        % -------------------------------------------------------------
        % Bruit en fonction de L
        % -------------------------------------------------------------

        noise_L = nan(1,nL);

        for il = 1:nL
            tmp = data5D(:,:,il,:,:);
            mask = mask5D(:,:,il,:,:);

            vals = tmp(mask);
            noise_L(il) = robust_sigma(vals);
        end

        % -------------------------------------------------------------
        % Bruit en fonction de Z
        % -------------------------------------------------------------

        noise_Z = nan(1,nZ);

        for iz = 1:nZ
            tmp = data5D(:,:,:,iz,:);
            mask = mask5D(:,:,:,iz,:);

            vals = tmp(mask);
            noise_Z(iz) = robust_sigma(vals);
        end

        % -------------------------------------------------------------
        % Bruit en fonction de T
        % -------------------------------------------------------------

        noise_T = nan(1,nT);

        for it = 1:nT
            tmp = data5D(:,:,:,:,it);
            mask = mask5D(:,:,:,:,it);

            vals = tmp(mask);
            noise_T(it) = robust_sigma(vals);
        end

        %% Figure 1 : évolution du bruit

        figure('Name', 'Evolution du bruit dans le ROI', ...
               'Color', 'w');

        tiledlayout(3,2, 'TileSpacing', 'compact', ...
                          'Padding', 'compact');

        nexttile;
        plot(1:nX, noise_X, '-o', 'LineWidth', 1.5);
        xlabel('X (pixel)');
        ylabel('\sigma_{robuste}');
        title('Bruit en fonction de X');
        grid on;

        nexttile;
        plot(1:nY, noise_Y, '-o', 'LineWidth', 1.5);
        xlabel('Y (pixel)');
        ylabel('\sigma_{robuste}');
        title('Bruit en fonction de Y');
        grid on;

        nexttile;
        plot(1:nL, noise_L, '-o', 'LineWidth', 1.5);
        xlabel('L (indice spectral)');
        ylabel('\sigma_{robuste}');
        title('Bruit en fonction de L');
        grid on;

        nexttile;
        plot(1:nZ, noise_Z, '-o', 'LineWidth', 1.5);
        xlabel('Z (indice)');
        ylabel('\sigma_{robuste}');
        title('Bruit en fonction de Z');
        grid on;

        nexttile;
        plot(1:nT, noise_T, '-o', 'LineWidth', 1.5);
        xlabel('T (indice temporel)');
        ylabel('\sigma_{robuste}');
        title('Bruit en fonction de T');
        grid on;

        %% Figure 2 : évolution du background moyen

        figure('Name', 'Evolution du niveau de background', ...
               'Color', 'w');

        tiledlayout(3,1, 'TileSpacing', 'compact', ...
                          'Padding', 'compact');

        nexttile;
        plot(squeeze(median(background_matrix, [2 3], 'omitnan')), ...
             '-o', 'LineWidth', 1.5);
        xlabel('L (indice spectral)');
        ylabel('Background');
        title('Background en fonction de L');
        grid on;

        nexttile;
        plot(squeeze(median(background_matrix, [1 3], 'omitnan')), ...
             '-o', 'LineWidth', 1.5);
        xlabel('Z (indice)');
        ylabel('Background');
        title('Background en fonction de Z');
        grid on;

        nexttile;
        plot(squeeze(median(background_matrix, [1 2], 'omitnan')), ...
             '-o', 'LineWidth', 1.5);
        xlabel('T (indice temporel)');
        ylabel('Background');
        title('Background en fonction de T');
        grid on;

    end

    %% 7. Retour aux dimensions originales

    data_corrected = reshape(data_corrected, originalSize);

end


%% ========================================================================
% Fonction locale : estimation robuste du bruit
% ========================================================================

function sigma = robust_sigma(values)

    values = values(isfinite(values));

    if isempty(values)
        sigma = NaN;
        return;Je 
    end

    med = median(values);
    madValue = median(abs(values - med));

    sigma = 1.4826 * madValue;

end
