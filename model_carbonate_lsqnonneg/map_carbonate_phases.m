function [phase_map, A_maps, ratio_maps] = ...
    map_carbonate_phases( ...
    imgs, ...
    wavenumber, ...
    n_ch, ...
    tau_fwhm, ...
    use_ACC, ...
    use_CCHH, ...
    use_MHC, ...
    use_VAT, ...
    use_ARA, ...
    use_CAL, ...
    threshold_sigma, ...
    min_points_bckg,...
    threshold_ratio, ...
    display_figures,...
    sub_dir_save,...
    R2_min, ...
    residual_sigma_max)

%% ================================================================
% CARTOGRAPHIE DES PHASES CARBONATEES PIXEL PAR PIXEL
%
% Pour chaque pixel :
%
%   1) extraction du spectre
%   2) fit des phases carbonate
%   3) récupération des A_phi
%   4) calcul des fractions A_phi / A_total
%   5) calcul du rapport ACC / Calcite
%   6) classification
%
%
% phase_map :
%
%   0 = background / pixel rejeté
%   1 = ACC
%   2 = CCHH
%   3 = MHC
%   4 = Vaterite
%   5 = Aragonite
%   6 = Calcite
%
%
% A_maps(:,:,k) :
%
%   quantité de matière de la phase k
%
%
% ratio_maps(:,:,k) :
%
%   fraction de la phase k dans le carbonate total :
%
%             A_k
%   f_k = ---------------
%           sum(A_phi)
%
%
% ratio_ACC_CAL_map :
%
%   rapport spécifique ACC / Calcite :
%
%             A_ACC
%   R = ---------------
%             A_CAL
%
%   Ce rapport est utilisé pour la classification ACC / Calcite.
%
%
% threshold_ratio :
%
%   seuil sur A_ACC / A_CAL
%
%   Exemple :
%
%       threshold_ratio = 0.2
%
%   signifie :
%
%       A_ACC / A_CAL >= 0.2  --> ACC détectée
%       A_ACC / A_CAL <  0.2  --> Calcite
%
%% ================================================================


%% ================================================================
% 1. Dimensions de l'image
%% ================================================================

dims = size(imgs);

if ndims(imgs) == 4

    % imgs = X x Y x Nw x Nchannel

    Nx = dims(1);
    Ny = dims(2);
    Nw = dims(3);

elseif ndims(imgs) == 3

    % imgs = X x Y x Nw

    Nx = dims(1);
    Ny = dims(2);
    Nw = dims(3);

else

    error('Dimension de imgs non supportée.');

end


%% ================================================================
% 2. Extraction du canal
%% ================================================================

if ndims(imgs) == 4

    data = squeeze(imgs(:,:,:,n_ch));

else

    data = imgs;

end


%% ================================================================
% 3. Vérification du nombre de nombres d'onde
%% ================================================================

wavenumber = wavenumber(:);

if length(wavenumber) ~= Nw

    error(['Le nombre de nombres d''onde ne correspond pas ' ...
           'au nombre d''images du stack.']);

end


%% ================================================================
% 4. Vérification du seuil
%% ================================================================

if threshold_ratio < 0

    error('threshold_ratio doit être positif.');

end


%% ================================================================
% 5. Initialisation des cartes
%% ================================================================

% ------------------------------------------------
% Carte finale de classification
%
% 0 = rejet / background
% 1 = ACC
% 2 = CCHH
% 3 = MHC
% 4 = Vaterite
% 5 = Aragonite
% 6 = Calcite
% ------------------------------------------------

phase_map = zeros(Nx,Ny);


% ------------------------------------------------
% Quantité de matière de chaque phase
% ------------------------------------------------

A_maps = zeros(Nx,Ny,6);


% ------------------------------------------------
% Fraction de chaque phase
% ------------------------------------------------

ratio_maps = zeros(Nx,Ny,6);


% ------------------------------------------------
% Rapport ACC / Calcite
% ------------------------------------------------

ratio_ACC_CAL_map = NaN(Nx,Ny);


% ------------------------------------------------
% Carte SNR
% ------------------------------------------------

SNR_map = NaN(Nx,Ny);


% ------------------------------------------------
% Carte R²
% ------------------------------------------------

R2_map = NaN(Nx,Ny);

% ------------------------------------------------
% Carte du résidu normalisé par le bruit
% ------------------------------------------------

residual_sigma_map = NaN(Nx,Ny);

%% ================================================================
% 6. Compteurs
%% ================================================================

n_valid    = 0;
n_rejected = 0;
n_ACC      = 0;
n_CAL      = 0;


%% ================================================================
% 7. Boucle sur tous les pixels
%% ================================================================

fprintf('\n');
fprintf('=============================================\n');
fprintf('    LSQNONNEG CARBONATE PHASE MAPPING\n');
fprintf('=============================================\n');

fprintf('Image : %d x %d pixels\n',Nx,Ny);
fprintf('Seuil ACC/Calcite : %.3f\n',threshold_ratio);
fprintf('\n');


for ix = 1:Nx

    % fprintf('Ligne %d / %d\n',ix,Nx);


    for iy = 1:Ny


        %% ========================================================
        % 7.1 Spectre du pixel
        %% ========================================================

        spectrum = squeeze(data(ix,iy,:));


        % Vérification des données

        if any(~isfinite(spectrum))

            phase_map(ix,iy) = 0;

            n_rejected = n_rejected + 1;

            continue

        end


        %% ========================================================
        % 7.2 Fit du spectre
        %% ========================================================

        [A,...
         ~,...
         valid_pixel,...
         ~,...
         ~,...
         R2,...
         ~,...
         SNR,...
         residual_sigma,...
         ~] = fit_carbonate_phases( ...
            wavenumber,...
            spectrum,...
            tau_fwhm,...
            use_ACC,...
            use_CCHH,...
            use_MHC,...
            use_VAT,...
            use_ARA,...
            use_CAL,...
            threshold_sigma,...
            min_points_bckg,...
            false,...
            R2_min,...
            residual_sigma_max);


        %% ========================================================
        % 7.3 Sauvegarde SNR et R²
        %% ========================================================

        SNR_map(ix,iy) = SNR;

        R2_map(ix,iy) = R2;

        residual_sigma_map(ix,iy) = residual_sigma;


        %% ========================================================
        % 7.4 Vérification de la validité du pixel
        %% ========================================================

        if ~valid_pixel

            % Pixel considéré comme background / trop bruité

            phase_map(ix,iy) = 0;

            n_rejected = n_rejected + 1;

            continue

        end


        %% ========================================================
        % 7.5 Vérification des amplitudes
        %% ========================================================

        % On évite les valeurs négatives éventuelles
        % issues du fit numérique.

        A = max(A(:),0);


        % Vérification

        if length(A) < 6

            phase_map(ix,iy) = 0;

            n_rejected = n_rejected + 1;

            continue

        end


        %% ========================================================
        % 7.6 Quantité totale de carbonate
        %% ========================================================

        A_total = sum(A);


        if ~isfinite(A_total) || A_total <= 0

            phase_map(ix,iy) = 0;

            n_rejected = n_rejected + 1;

            continue

        end


        %% ========================================================
        % 7.7 Sauvegarde des quantités de matière
        %% ========================================================

        A_maps(ix,iy,:) = A;


        %% ========================================================
        % 7.8 Fraction de chaque phase
        %% ========================================================

        ratios = A / A_total;


        ratio_maps(ix,iy,:) = ratios;


        %% ========================================================
        % 7.9 Rapport ACC / Calcite
        %% ========================================================

        A_ACC = A(1);

        A_CAL = A(6);


        % --------------------------------------------------------
        % Cas où la Calcite est absente
        % --------------------------------------------------------

        if A_CAL > 0

            ratio_ACC_CAL = A_ACC / A_CAL;

        else

            % Si A_CAL = 0 et A_ACC > 0 :
            %
            %       ACC / Calcite -> infini
            %
            % Si les deux sont nulles :
            %
            %       rapport = 0

            if A_ACC > 0

                ratio_ACC_CAL = Inf;

            else

                ratio_ACC_CAL = 0;

            end

        end


        % Sauvegarde du rapport

        ratio_ACC_CAL_map(ix,iy) = ratio_ACC_CAL;


        %% ========================================================
        % 7.10 Classification ACC / Calcite
        %% ========================================================

        % --------------------------------------------------------
        % Si ACC et Calcite sont les deux phases que l'on cherche
        % à discriminer :
        %
        %       A_ACC / A_CAL >= threshold_ratio
        %
        % --> ACC
        %
        %       A_ACC / A_CAL < threshold_ratio
        %
        % --> Calcite
        % --------------------------------------------------------

        if use_ACC && use_CAL


            if ratio_ACC_CAL >= threshold_ratio

                % ----------------------------------------------
                % ACC suffisamment importante par rapport
                % à la Calcite
                % ----------------------------------------------

                phase_map(ix,iy) = 1;

                n_ACC = n_ACC + 1;


            else

                % ----------------------------------------------
                % Calcite dominante par rapport à l'ACC
                % ----------------------------------------------

                phase_map(ix,iy) = 6;

                n_CAL = n_CAL + 1;

            end


        else

            %% ====================================================
            % 7.11 Cas général :
            %       si ACC ou Calcite n'est pas utilisé
            %
            %       on revient à une classification par phase
            %       dominante.
            %% ====================================================

            [max_ratio,phase_dominante] = max(ratios);


            if max_ratio >= threshold_ratio

                phase_map(ix,iy) = phase_dominante;


            else

                % Mélange trop important / aucune phase dominante

                phase_map(ix,iy) = 0;

            end

        end


        n_valid = n_valid + 1;


    end

end


%% ================================================================
% 8. Statistiques finales
%% ================================================================

fprintf('\n');
fprintf('=============================================\n');
fprintf('             LSQNONNEG RESULTS\n');
fprintf('=============================================\n');

fprintf('Pixels valides   : %d\n',n_valid);
fprintf('Pixels rejetés   : %d\n',n_rejected);

if use_ACC && use_CAL

    fprintf('Pixels ACC       : %d\n',n_ACC);
    fprintf('Pixels Calcite   : %d\n',n_CAL);

    fprintf('Seuil ACC/Calcite = %.3f\n',threshold_ratio);

end


%% ================================================================
% 9. AFFICHAGE SYNTHETIQUE DES RESULTATS
%% ================================================================

if display_figures

    %% ============================================================
    % Calcul des cartes nécessaires
    %% ============================================================

    % ------------------------------------------------------------
    % Fraction ACC
    % ------------------------------------------------------------

    fraction_ACC = ratio_maps(:,:,1);


    % ------------------------------------------------------------
    % Rapport ACC / Calcite
    % ------------------------------------------------------------

    A_ACC_map = A_maps(:,:,1);
    A_CAL_map = A_maps(:,:,6);

    ratio_ACC_CAL_display = NaN(size(A_ACC_map));

    mask_CAL = A_CAL_map > 0;

    ratio_ACC_CAL_display(mask_CAL) = ...
        A_ACC_map(mask_CAL) ./ A_CAL_map(mask_CAL);


    %% ============================================================
    % Figure 2 x 3
    %% ============================================================

    figure( ...
        'Color','white',...
        'Position',[100 100 1300 800]);

    tiledlayout(2,3,...
        'TileSpacing','compact',...
        'Padding','compact');


    %% ============================================================
    % 9.1 Carbonate phase map
    %% ============================================================

    nexttile;

    imagesc(phase_map);

    axis image;
    colorbar;

    clim([0 6]);

    title(sprintf( ...
        'Carbonate phase map | ACC/CAL threshold = %.2f', ...
        threshold_ratio));

    xlabel('Y pixel');
    ylabel('X pixel');

    % Sauvegarde de la phase map     
    
    file_phase_map_2ps = fullfile(sub_dir_save, 'phase_map_2ps.mat');
    
    save(file_phase_map_2ps, ...
         'phase_map', ...
         'Nx', ...
         'Ny');
    
    fprintf('\nPhase map 2 ps sauvegardée dans :\n%s\n', ...
            file_phase_map_2ps);


    %% ============================================================
    % 9.2 Fraction ACC
    %% ============================================================

    nexttile;

    imagesc(fraction_ACC);

    axis image;
    colorbar;

    clim([0 1]);

    title('Fraction ACC');

    xlabel('Y pixel');
    ylabel('X pixel');


    %% ============================================================
    % 9.3 Rapport ACC / Calcite
    %% ============================================================

    nexttile;

    imagesc(ratio_ACC_CAL_display);

    axis image;
    colorbar;

    title(sprintf( ...
        'A_{ACC} / A_{Calcite} | threshold = %.2f', ...
        threshold_ratio));

    xlabel('Y pixel');
    ylabel('X pixel');


    %% ============================================================
    % 9.4 SNR
    %% ============================================================

    nexttile;

    imagesc(SNR_map);

    axis image;
    colorbar;
    clim([0 100]);

    title('SNR');

    xlabel('Y pixel');
    ylabel('X pixel');


    %% ============================================================
    % 9.5 R²
    %% ============================================================

    nexttile;

    imagesc(R2_map);

    axis image;
    
    colorbar;

    clim([0 1]);

    title('R^2')
%     title(sprintf('R^2  R^2_{min} = %.2f',R2_min));

    xlabel('Y pixel');
    ylabel('X pixel');


    %% ============================================================
    % 9.6 Résidu du modèle
    %% ============================================================

    nexttile;

    imagesc(residual_sigma_map);

    axis image;
    colorbar;
    clim([0 5]);

    title('Residual / noise \sigma');

    xlabel('Y pixel');
    ylabel('X pixel');


    %% ============================================================
    % Titre général
    %% ============================================================

    sgtitle('Carbonate phase analysis');

end

end