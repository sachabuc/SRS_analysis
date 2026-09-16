function [phase_map_7ps_shifted, ...
          phase_map_7ps_recalculated, ...
          A_maps_shifted, ratio_maps_shifted, ...
          A_maps_recalculated, ratio_maps_recalculated] = ...
    map_carbonate_phases_7ps( ...
    path_phase_map_2ps, ...
    shift_x, ...
    shift_y, ...
    imgs, ...
    wavenumber, ...
    n_ch, ...
    tau_fwhm, ...
    threshold_sigma, ...
    min_points_bckg, ...
    threshold_ratio, ...
    display_figures, ...
    R2_min, ...
    residual_sigma_max)


%% ================================================================
% CARTOGRAPHIE 7 ps À PARTIR DE LA CARTE 2 ps
%
% Deux cartes sont produites :
%
% 1) phase_map_7ps_shifted
%
%    -> mêmes pixels que phase_map_2ps
%    -> simplement déplacés de (shift_x,shift_y)
%    -> aucun nouveau critère de détection
%
% 2) phase_map_7ps_recalculated
%
%    -> classification indépendante des pixels du stack 7 ps
%    -> fit_carbonate_phases est relancé
%    -> les critères SNR / R2 / residual_sigma sont recalculés
%
%
% Convention :
%
% phase_map :
%
%   0 = background / rejeté
%   1 = ACC
%   2 = CCHH
%   3 = MHC
%   4 = Vaterite
%   5 = Aragonite
%   6 = Calcite
%
%
% shift_x = déplacement selon la première dimension (X)
% shift_y = déplacement selon la deuxième dimension (Y)
%
% Exemple :
%
% shift_x = +3
% shift_y = -2
%
% signifie :
%
%   nouveau_X = ancien_X + 3
%   nouveau_Y = ancien_Y - 2
%
%% ================================================================


use_ACC = true;
use_CAL = true;

%% ================================================================
% 1. Vérification de la carte 2 ps
%% ================================================================

% Chargement de la phase map 2 ps

file_phase_map_2ps = fullfile( ...
    path_phase_map_2ps, ...
    'phase_map_2ps.mat');

if ~isfile(file_phase_map_2ps)

    error('Impossible de trouver la phase map 2 ps :\n%s', ...
          file_phase_map_2ps);

end

load(file_phase_map_2ps, ...
     'phase_map', ...
     'Nx', ...
     'Ny');

phase_map_2ps = phase_map;

fprintf('\nPhase map 2 ps chargée depuis :\n%s\n', ...
        file_phase_map_2ps);

[Nx2,Ny2] = size(phase_map_2ps);


if ~isnumeric(phase_map_2ps)

    error('phase_map_2ps doit être numérique.');

end




%% ================================================================
% 2. Extraction du canal 7 ps
%% ================================================================

dims = size(imgs);


if ndims(imgs) == 4

    % imgs = X x Y x Nw x Nchannel

    Nx = dims(1);
    Ny = dims(2);
    Nw = dims(3);

    data = squeeze(imgs(:,:,:,n_ch));

elseif ndims(imgs) == 3

    % imgs = X x Y x Nw

    Nx = dims(1);
    Ny = dims(2);
    Nw = dims(3);

    data = imgs;

else

    error('Dimension de imgs non supportée.');

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
% 4. Vérification de la taille de la carte 2 ps
%% ================================================================

if Nx2 ~= Nx || Ny2 ~= Ny

    warning(['La carte 2 ps et le stack 7 ps ont des dimensions ' ...
             'différentes. La carte shiftée sera limitée à la zone commune.']);

end


%% ================================================================
% 5. Initialisation
%% ================================================================

% ------------------------------------------------
% Carte 7 ps avec les mêmes pixels que 2 ps
% ------------------------------------------------

phase_map_7ps_shifted = zeros(Nx,Ny);


% ------------------------------------------------
% Carte 7 ps recalculée
% ------------------------------------------------

phase_map_7ps_recalculated = zeros(Nx,Ny);


% ------------------------------------------------
% Cartes A
% ------------------------------------------------

A_maps_shifted = zeros(Nx,Ny,6);

A_maps_recalculated = zeros(Nx,Ny,6);


% ------------------------------------------------
% Cartes des fractions
% ------------------------------------------------

ratio_maps_shifted = zeros(Nx,Ny,6);

ratio_maps_recalculated = zeros(Nx,Ny,6);


% ------------------------------------------------
% Cartes ACC / Calcite
% ------------------------------------------------

ratio_ACC_CAL_shifted = NaN(Nx,Ny);

ratio_ACC_CAL_recalculated = NaN(Nx,Ny);


% ------------------------------------------------
% Critères de qualité 7 ps
% ------------------------------------------------

SNR_map_7ps = NaN(Nx,Ny);

R2_map_7ps = NaN(Nx,Ny);

residual_sigma_map_7ps = NaN(Nx,Ny);


%% ================================================================
% 6. TRANSFERT DE LA CARTE 2 ps
%% ================================================================

% On parcourt les pixels de la carte 2 ps.
%
% Le pixel :
%
%       (ix,iy)
%
% devient :
%
%       (ix + shift_x, iy + shift_y)
%
% Aucun fit n'est réalisé ici.


for ix = 1:Nx2

    for iy = 1:Ny2

        new_x = ix + shift_x;
        new_y = iy + shift_y;


        % Vérification que le pixel déplacé reste dans l'image 7 ps

        if new_x < 1 || new_x > Nx || ...
           new_y < 1 || new_y > Ny

            continue

        end


        % Transfert de la classification

        phase_map_7ps_shifted(new_x,new_y) = ...
            phase_map_2ps(ix,iy);

    end

end


%% ================================================================
% 7. BOUCLE SUR LES PIXELS 7 ps
%
% Classification indépendante
%% ================================================================

% fprintf('\n');
% fprintf('=============================================\n');
% fprintf('     CARBONATE PHASE MAPPING - 7 ps\n');
% fprintf('=============================================\n');


% for ix = 1:Nx
% 
%     fprintf('Ligne %d / %d\n',ix,Nx);
% 
% 
%     for iy = 1:Ny
% 
% 
%         %% --------------------------------------------------------
%         % Spectre du pixel
%         %% --------------------------------------------------------
% 
%         spectrum = squeeze(data(ix,iy,:));
% 
% 
%         if any(~isfinite(spectrum))
% 
%             continue
% 
%         end
% 
% 
%         %% --------------------------------------------------------
%         % Fit du spectre
%         %% --------------------------------------------------------
% 
%         [A,...
%          ~,...
%          valid_pixel,...
%          ~,...
%          ~,...
%          R2,...
%          ~,...
%          SNR,...
%          residual_sigma,...
%          ~] = fit_carbonate_phases( ...
%             wavenumber,...
%             spectrum,...
%             tau_fwhm,...
%             true,...       % ACC
%             true,...       % CCHH
%             true,...       % MHC
%             true,...       % Vaterite
%             true,...       % Aragonite
%             true,...       % Calcite
%             threshold_sigma,...
%             min_points_bckg,...
%             false,...
%             R2_min,...
%             residual_sigma_max);
% 
% 
%         %% --------------------------------------------------------
%         % Sauvegarde des critères
%         %% --------------------------------------------------------
% 
%         SNR_map_7ps(ix,iy) = SNR;
% 
%         R2_map_7ps(ix,iy) = R2;
% 
%         residual_sigma_map_7ps(ix,iy) = residual_sigma;
% 
% 
%         %% --------------------------------------------------------
%         % Pixel rejeté
%         %% --------------------------------------------------------
% 
%         if ~valid_pixel
% 
%             phase_map_7ps_recalculated(ix,iy) = 0;
% 
%             continue
% 
%         end
% 
% 
%         %% --------------------------------------------------------
%         % Amplitudes positives
%         %% --------------------------------------------------------
% 
%         A = max(A(:),0);
% 
% 
%         if length(A) < 6
% 
%             continue
% 
%         end
% 
% 
%         %% --------------------------------------------------------
%         % Quantité totale
%         %% --------------------------------------------------------
% 
%         A_total = sum(A);
% 
% 
%         if ~isfinite(A_total) || A_total <= 0
% 
%             continue
% 
%         end
% 
% 
%         %% --------------------------------------------------------
%         % Sauvegarde A
%         %% --------------------------------------------------------
% 
%         A_maps_recalculated(ix,iy,:) = A;
% 
% 
%         %% --------------------------------------------------------
%         % Fractions
%         %% --------------------------------------------------------
% 
%         ratios = A/A_total;
% 
%         ratio_maps_recalculated(ix,iy,:) = ratios;
% 
% 
%         %% --------------------------------------------------------
%         % Rapport ACC / Calcite
%         %% --------------------------------------------------------
% 
%         A_ACC = A(1);
% 
%         A_CAL = A(6);
% 
% 
%         if A_CAL > 0
% 
%             ratio_ACC_CAL_recalculated(ix,iy) = ...
%                 A_ACC/A_CAL;
% 
%         elseif A_ACC > 0
% 
%             ratio_ACC_CAL_recalculated(ix,iy) = Inf;
% 
%         else
% 
%             ratio_ACC_CAL_recalculated(ix,iy) = 0;
% 
%         end
% 
% 
%         %% --------------------------------------------------------
%         % Classification
%         %% --------------------------------------------------------
% 
%         if use_ACC && use_CAL
% 
%             ratio_ACC_CAL = ...
%                 ratio_ACC_CAL_recalculated(ix,iy);
% 
% 
%             if ratio_ACC_CAL >= threshold_ratio
% 
%                 phase_map_7ps_recalculated(ix,iy) = 1;
% 
%             else
% 
%                 phase_map_7ps_recalculated(ix,iy) = 6;
% 
%             end
% 
% 
%         else
% 
%             % Classification par phase dominante
% 
%             [max_ratio,phase_dominante] = max(ratios);
% 
% 
%             if max_ratio >= threshold_ratio
% 
%                 phase_map_7ps_recalculated(ix,iy) = ...
%                     phase_dominante;
% 
%             else
% 
%                 phase_map_7ps_recalculated(ix,iy) = 0;
% 
%             end
% 
%         end
% 
%     end
% 
% end


%% ================================================================
% 8. Calcul des A pour les pixels transférés
%
% IMPORTANT :
%
% Ici, on ne refait PAS de fit.
%
% Les A ne peuvent donc pas être obtenus à partir du stack 7 ps
% sans refaire le fit.
%
% On laisse donc A_maps_shifted à zéro.
%
% La carte shifted sert uniquement à comparer les mêmes pixels.
%% ================================================================


%% ================================================================
% 9. AFFICHAGE
%% ================================================================

if display_figures


    %% ============================================================
    % Carte 2 ps décalée vers le référentiel 7 ps
    %% ============================================================

    figure('Color','white');

    imagesc(phase_map_7ps_shifted);

    axis image;
    colorbar;

    clim([0 6]);

    title('7 ps - mêmes pixels que 2 ps (shiftés)');

    xlabel('Y pixel');
    ylabel('X pixel');


    %% ============================================================
    % Carte 7 ps recalculée
    %% ============================================================

%     figure('Color','white');
% 
%     imagesc(phase_map_7ps_recalculated);
% 
%     axis image;
%     colorbar;
% 
%     clim([0 6]);
% 
%     title('7 ps - classification recalculée');
% 
%     xlabel('Y pixel');
%     ylabel('X pixel');


    %% ============================================================
    % Comparaison côte à côte
    %% ============================================================
% 
%     figure( ...
%         'Color','white',...
%         'Position',[100 100 1200 500]);
% 
% 
%     tiledlayout(1,2,...
%         'TileSpacing','compact',...
%         'Padding','compact');
% 
% 
%     nexttile;
% 
%     imagesc(phase_map_7ps_shifted);
% 
%     axis image;
%     colorbar;
% 
%     clim([0 6]);
% 
%     title('7 ps : mêmes pixels que 2 ps');
% 
% 
%     nexttile;
% 
%     imagesc(phase_map_7ps_recalculated);
% 
%     axis image;
%     colorbar;
% 
%     clim([0 6]);
% 
%     title('7 ps : recalcul indépendant');
% 
% 
%     sgtitle('Comparaison des cartes 7 ps');


    %% ============================================================
    % Rapport ACC / Calcite
    %% ============================================================

%     figure('Color','white');
% 
%     imagesc(ratio_ACC_CAL_recalculated);
% 
%     axis image;
%     colorbar;
% 
%     title(sprintf( ...
%         '7 ps : ACC / Calcite | threshold = %.2f',...
%         threshold_ratio));
% 
%     xlabel('Y pixel');
%     ylabel('X pixel');


    %% ============================================================
    % SNR
    %% ============================================================

%     figure('Color','white');
% 
%     imagesc(SNR_map_7ps);
% 
%     axis image;
%     colorbar;
% 
%     title('7 ps - SNR');
% 
%     xlabel('Y pixel');
%     ylabel('X pixel');


    %% ============================================================
    % R²
    %% ============================================================

%     figure('Color','white');
% 
%     imagesc(R2_map_7ps);
% 
%     axis image;
%     colorbar;
% 
%     clim([0 1]);
% 
%     title('7 ps - R^2');
% 
%     xlabel('Y pixel');
%     ylabel('X pixel');


    %% ============================================================
    % Résidu normalisé
    %% ============================================================

%     figure('Color','white');
% 
%     imagesc(residual_sigma_map_7ps);
% 
%     axis image;
%     colorbar;
% 
%     clim([0 residual_sigma_max]);
% 
%     title(sprintf( ...
%         '7 ps - Residual / noise \\sigma | threshold = %.2f',...
%         residual_sigma_max));
% 
%     xlabel('Y pixel');
%     ylabel('X pixel');

end


%% ================================================================
% 10. Statistiques
%% ================================================================

% fprintf('\n');
% fprintf('=============================================\n');
% fprintf('          COMPARISON 7 ps\n');
% fprintf('=============================================\n');
% 
% fprintf('Pixels non nuls carte 2 ps shiftée : %d\n',...
%     nnz(phase_map_7ps_shifted));
% 
% fprintf('Pixels valides après recalcul 7 ps : %d\n',...
%     nnz(phase_map_7ps_recalculated));
% 
% fprintf('=============================================\n');


end