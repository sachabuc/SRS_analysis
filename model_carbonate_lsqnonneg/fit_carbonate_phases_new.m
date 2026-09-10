function [offset_fit, valid_pixel, fit_spectrum, ...
          residual, R2, SNR] = ...
          fit_carbonate_phases_new( ...
          model_phases,...
          wavenumber_not_sorted, ...
          sp_pix, ...
          tau_fwhm, ...
          threshold_sigma, ...
          min_points_bckg, ... 
          display_figures, ...
          R2_min)

%% ================================================================
%  FIT DES PHASES CARBONATEES PAR MOINDRES CARRES NON NEGATIFS
%
% Le spectre est modélisé par :
%
%   S(nu) = somme_phi A_phi * G_phi(nu) + Background
%
% Chaque G_phi est une gaussienne normalisée en aire.
%
% La réponse instrumentale est également supposée gaussienne.
% La convolution est donc faite analytiquement :
%
%   sigma_eff^2 = sigma_phase^2 + sigma_instrument^2
%
% Les A_phi sont obtenus par :
%
%   min || M*A - S ||^2
%
% avec A >= 0
%
% grâce à LSQNONNEG.
%
%
% PHASES :
%
%   1 = ACC
%   2 = CCHH
%   3 = MHC
%   4 = Vaterite
%   5 = Aragonite
%   6 = Calcite
%
% use_xxx = true  -> phase utilisée
% use_xxx = false -> phase ignorée
%
% VALIDITE PIXELS :
%
% 1) SNR >= threshold_sigma
%
% 2) R2 >= R2_min
%
%
%
%
% SORTIES :
%
%   A            : [ACC CCHH MHC VAT ARA CAL]
%   offset_fit   : background ajusté
%   valid_pixel  : pixel suffisamment signalé
%   fit_spectrum : modèle total
%   residual     : expérimental - modèle
%   R2           : coefficient de détermination
%   RMS          : erreur quadratique moyenne
%   SNR          : rapport signal/bruit
%   phase_names  : noms des phases


%% ================================================================
% 3. Mise en forme du spectre expérimental
%% ================================================================

wavenumber_not_sorted = wavenumber_not_sorted(:);
sp_pix = sp_pix(:);


% Suppression des NaN / Inf
valid = isfinite(wavenumber_not_sorted) & isfinite(sp_pix);

wavenumber_not_sorted = wavenumber_not_sorted(valid);
sp_pix = sp_pix(valid);


% Tri par nombre d'onde
[wavenumber_sorted, idx] = sort(wavenumber_not_sorted);

sp_sorted = sp_pix(idx);


N = length(sp_sorted);


if N < 3

    error('Le spectre contient trop peu de points.');

end


%% ================================================================
% 4. Estimation robuste du background et du bruit
%% ================================================================

% On prend les 20 % des intensités les plus faibles.
%
% L'idée est que ces points contiennent principalement :
%   - le background
%   - le bruit
%
% plutôt que les pics Raman/SRS.

n_low = max(3,round(0.20*N));

sp_sorted_ordered = sort(sp_sorted);

background_points = ...
    sp_sorted_ordered(1:n_low);


% Estimation du background
background_est = median(background_points);


% ------------------------------------------------
% Estimation robuste du bruit
% ------------------------------------------------

% Median Absolute Deviation calculé manuellement :
%
% MAD = median(|x - median(x)|)
%
% Pour un bruit gaussien :
%
% sigma ≈ 1.4826 * MAD

med_bg = median(background_points);

MAD = median(abs(background_points-med_bg));

noise_std = 1.4826*MAD;


% Sécurité si MAD = 0
if noise_std <= 0

    noise_std = std(background_points);

end

if noise_std <= 0

    noise_std = eps;

end


%% ================================================================
% 5. Détection du pixel
%% ================================================================

%% Signal corrigé du background

sp_corr = sp_sorted - background_est;
% sp_sorted= sp_sorted - background_est; pour soustraire le bruit pixel par
% pixel

threshold = threshold_sigma * noise_std;


%% Points significativement au-dessus du bruit

above_noise = sp_corr > threshold;


%% Nombre de points consécutifs au-dessus du bruit

signal_max = max(sp_sorted)-background_est;

d = diff([false; above_noise; false]);

start_idx = find(d == 1);
end_idx   = find(d == -1) - 1;

run_length = end_idx - start_idx + 1;


valid_pixel = any(run_length >= min_points_bckg);

%% ================================================================
% 6. Si le pixel est trop bruité
%% ================================================================

if ~valid_pixel

    A = zeros(6,1);

    offset_fit = background_est;

    fit_spectrum = ...
        background_est*ones(size(sp_sorted));

    residual = ...
        sp_sorted-fit_spectrum;

    SS_res = sum(residual.^2);

    SS_tot = ...
        sum((sp_sorted-mean(sp_sorted)).^2);

    R2 = 1-SS_res/SS_tot;

    SNR = signal_max/noise_std;


    if display_figures

        figure('Color','white');

        plot(wavenumber_sorted,...
             sp_sorted,...
             'ko-',...
             'MarkerFaceColor','r',...
             'LineWidth',1.2);

        hold on;

        yline(background_est,...
              'k--',...
              'LineWidth',1.5,...
              'DisplayName','Background');

        yline(background_est+threshold,...
              'b--',...
              'LineWidth',1.5,...
              'DisplayName','Detection threshold');

        xlabel('Wavenumber (cm^{-1})');
        ylabel('Intensity (a.u.)');

        title('Pixel rejected : background / noise');

        legend('Location','best');

        grid on;
        box on;


        fprintf('\n');
        fprintf('============================================\n');
        fprintf(' PIXEL REJECTED\n');
        fprintf('============================================\n');
        fprintf('Background       : %.5g\n',background_est);
        fprintf('Noise sigma      : %.5g\n',noise_std);
        fprintf('Signal max       : %.5g\n',signal_max);
        fprintf('Threshold        : %.5g\n',threshold);
        fprintf('SNR              : %.3f\n',SNR);
        fprintf('============================================\n');

    end

    return

end


%% ================================================================
% 7. Grille théorique
%% ================================================================

% On ajoute une marge autour de la zone expérimentale.
%
% Cela évite les problèmes de bord lors de la modélisation.

margin = 10;

wn_min = min(wavenumber_sorted)-margin;
wn_max = max(wavenumber_sorted)+margin;

dw = 0.05;

wavenumber = wn_min:dw:wn_max;


%% ================================================================
% 8. Réponse instrumentale
%% ================================================================

if tau_fwhm > 0

    sigma_inst = tau_fwhm/2.355;

else

    sigma_inst = 0;

end


%% ================================================================
% 9. Construction de la matrice du modèle
%% ================================================================

%
% Chaque colonne de M correspond à une phase.
%
% M(:,1) = ACC
% M(:,2) = CCHH
% ...
%
% dernière colonne = background
%
% Le modèle devient :
%
%     sp = M*x
%
% avec :
%
%     x = [A_ACC A_CCHH ... A_CAL Background]'
%

M = [];

phase_column = zeros(6,1);


%% ================================================================
% 10. Construction des fonctions spectrales
%% ================================================================

% On conserve également chaque fonction de base
% pour pouvoir afficher les contributions.

basis_exp = cell(6,1);


for k = 1:length(model_phases)


    % -------------------------------------------------------------
    % Phase désactivée
    % -------------------------------------------------------------

    if ~model_phases(k).use

        continue

    end


        % ---------------------------------------------------------
        % Gaussienne normalisée en aire
        % ---------------------------------------------------------

        phase_model(k).G_analytical
        Gp = ratios(p) ./ (sqrt(2*pi)*sigma_eff) .* ...
             exp(-(wavenumber-model_phases(k).nu(p)).^2 / (2*sigma_eff^2));


        G = G+Gp;





    % -------------------------------------------------------------
    % Interpolation sur les points expérimentaux
    % -------------------------------------------------------------

    G_exp = interp1( ...
        wavenumber,...
        G,...
        wavenumber_sorted,...
        'linear',...
        0);


    % -------------------------------------------------------------
    % Ajout de la colonne à la matrice
    % -------------------------------------------------------------

    M = [M G_exp(:)];


    basis_exp{k} = G_exp(:);


end


%% ================================================================
% 11. Ajout du background
%% ================================================================

% Background constant :
%
% B(nu) = B
%
% dernière colonne de M = 1

M = [M ones(N,1)];


%% ================================================================
% 12. Ajustement par moindres carrés non négatifs
%% ================================================================

%
% On cherche :
%
%       min ||M*x - sp||²
%
% sous la contrainte :
%
%       x >= 0
%
% Cela évite d'obtenir des quantités de matière négatives.
%

x = lsqnonneg(M,sp_sorted);

% dw_display = 0.01;
% 
% wavenumber_display = ...
%     min(wavenumber_sorted):dw_display:max(wavenumber_sorted);


%% ================================================================
% 13. Extraction des A_phi
%% ================================================================

A = zeros(6,1);

column = 0;


for k = 1:length(model_phases)


    if ~model_phases(k).use

        continue

    end


    column = column+1;

    A(k) = x(column);


end


% Dernier coefficient = background
offset_fit = x(end);


%% ================================================================
% 14. Spectre reconstruit
%% ================================================================

fit_spectrum = M*x;


%% ================================================================
% 15. Résidu
%% ================================================================

residual = sp_sorted-fit_spectrum;

%% ================================================================
% 16. SNR
%% ================================================================

% SNR global basé sur le signal maximum
% au-dessus du background.

SNR = ...
    (max(sp_sorted)-offset_fit)/noise_std;


%% ================================================================
% 17. Qualité du fit
%% ================================================================

SS_res = sum(residual.^2);

SS_tot = ...
    sum((sp_sorted-mean(sp_sorted)).^2);


R2 = 1-SS_res/SS_tot;


RMS = sqrt(mean(residual.^2));

% Critère de qualité globale du fit
criterion_R2 = R2 >= R2_min;


% Résidu exprimé en unités de bruit
residual_sigma = RMS / noise_std;


% Critère de compatibilité avec le bruit
criterion_model = ...
    residual_sigma <= residual_sigma_max;


valid_pixel = ...
    criterion_R2 && ...
    criterion_model;





%% ================================================================
% 18. Affichage des résultats numériques
%% ================================================================

if display_figures

    fprintf('\n');
    fprintf('====================================================\n');
    fprintf('             CARBONATE FIT\n');
    fprintf('====================================================\n');
    
    for k = 1:length(model_phases)
    
        if model_phases(k).use
    
            fprintf('%-12s : A = %.6g\n',...
                model_phases(k).name,...
                A(k));
    
        end
    
    end
    
    fprintf('----------------------------------------------------\n');
    
    fprintf('Background       = %.6g\n',offset_fit);
    
    fprintf('Noise sigma      = %.6g\n',noise_std);
    
    fprintf('Detection SNR    = %.4f\n',SNR);
    
    fprintf('R²               = %.6f\n',R2);
    
    fprintf('RMS residual     = %.6g\n',RMS);
    
    fprintf('====================================================\n');

end

%% ================================================================
% 19. AFFICHAGE
%% ================================================================

if display_figures

    %% ------------------------------------------------------------
    % Grille dense pour affichage
    %% ------------------------------------------------------------

    dw_display = 0.01;

    wavenumber_display = ...
        min(wavenumber_sorted):dw_display:max(wavenumber_sorted);


    %% ------------------------------------------------------------
    % Calcul des contributions sur grille dense
    %% ------------------------------------------------------------

    phase_display = cell(6,1);

    for k = 1:length(model_phases)

        if ~model_phases(k).use
            continue
        end

        G_display = zeros(size(wavenumber_display));

        ratios = model_phases(k).ratio;
        ratios = ratios/sum(ratios);

        for p = 1:length(model_phases(k).nu)

            sigma_phase = ...
                model_phases(k).FWHM(p)/2.355;

            if tau_fwhm > 0
                sigma_inst = tau_fwhm/2.355;
            else
                sigma_inst = 0;
            end

            % Convolution analytique
            sigma_eff = sqrt( ...
                sigma_phase^2 + sigma_inst^2);

            % Gaussienne normalisée en aire
            Gp = ratios(p) ./ ...
                 (sqrt(2*pi)*sigma_eff) .* ...
                 exp(-(wavenumber_display-model_phases(k).nu(p)).^2 ...
                 /(2*sigma_eff^2));

            G_display = G_display + Gp;

        end

        % Quantité de matière
        phase_display{k} = ...
            A(k)*G_display;

    end


    %% ------------------------------------------------------------
    % Modèle total
    %% ------------------------------------------------------------

    total_display = ...
        offset_fit*ones(size(wavenumber_display));

    for k = 1:length(model_phases)

        if model_phases(k).use

            total_display = ...
                total_display + phase_display{k};

        end

    end


    %% ------------------------------------------------------------
    % Figure
    %% ------------------------------------------------------------

    figure( ...
        'Color','white',...
        'Position',[100 100 1100 700]);

    hold on;


    %% ------------------------------------------------------------
    % Spectre expérimental
    %% ------------------------------------------------------------

    plot(wavenumber_sorted,...
         sp_sorted,...
         'ko',...
         'MarkerFaceColor','r',...
         'MarkerSize',6,...
         'LineWidth',1.2,...
         'DisplayName','Experimental');


    %% ------------------------------------------------------------
    % Contributions individuelles
    %% ------------------------------------------------------------

    colors = lines(6);

    for k = 1:length(model_phases)

        if ~model_phases(k).use
            continue
        end

        plot(wavenumber_display,...
             phase_display{k},...
             '--',...
             'Color',colors(k,:),...
             'LineWidth',2,...
             'DisplayName',model_phases(k).name);

    end


    %% ------------------------------------------------------------
    % Background
    %% ------------------------------------------------------------

    plot(wavenumber_display,...
         offset_fit*ones(size(wavenumber_display)),...
         ':',...
         'Color',[0.2 0.2 0.2],...
         'LineWidth',2,...
         'DisplayName','Background');


    %% ------------------------------------------------------------
    % Modèle total
    %% ------------------------------------------------------------

    plot(wavenumber_display,...
         total_display,...
         'k-',...
         'LineWidth',3,...
         'DisplayName','Total fit');


    %% ------------------------------------------------------------
    % Mise en forme
    %% ------------------------------------------------------------

    xlabel('Wavenumber (cm^{-1})',...
           'FontSize',13);

    ylabel('Intensity (a.u.)',...
           'FontSize',13);

    title(sprintf( ...
        'Carbonate fit : R^2 = %.4f | SNR = %.2f',...
        R2,SNR),...
        'FontSize',14);

    legend('Location','best');

    grid on;
    box on;

    set(gca,'FontSize',12);

end

end