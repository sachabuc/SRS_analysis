function ref_roi = compare_spectrums_double( ...
          I_corr, wavenumber, phase_model, phase_map, ...
          roi1, roi1_phase_idx, roi2, roi2_phase_idx, ...
          fwhm_instr,active_idx, phase_colors, colors_roi,...
          sub_dir_save,exportgraphics_segm_roi,ref_roi_compare, compare_plots,...
          noise_global,n_theoretical_points, save_path, delta_nu, fwhm_bounds)
%COMPARE_ROI_TO_THEORETICAL_MODEL Ajuste (lsqcurvefit) le spectre moyen
%de deux regions d'interet (ROI) sur un modele a une seule raie, avec
%AMPLITUDE, POSITION (nu) ET LARGEUR (FWHM) LIBRES en plus du fond
%(4 parametres). Affiche les deux ROI sur UN SEUL graphe (avec bande
%+/- 1 ecart-type), normalise par rapport a la courbe theorique ajustee
%la plus haute des deux -- avec nu/FWHM ajustes indiques dans la
%legende. Affiche aussi les deux ROI positionnees sur la carte de
%segmentation (phase_map.label), avec un colormap neutre (gris) pour
%que les ROI -- tracees dans des couleurs vives et contrastantes --
%restent bien visibles quel que soit le label dessous.
%
%   ref_roi = COMPARE_ROI_TO_THEORETICAL_MODEL(I_corr, wavenumber, ...
%       phase_model, phase_map, roi1, roi1_phase_idx, roi2, ...
%       roi2_phase_idx, fwhm_instr, n_theoretical_points, save_path, ...
%       delta_nu, fwhm_bounds)
%
%   Pour chaque ROI, le spectre moyen est ajuste par :
%       I(wavenumber) = A * G(wavenumber; nu, sigma_eff) + fond
%       sigma_eff = sqrt(fwhm2sigma(FWHM)^2 + fwhm2sigma(fwhm_instr)^2)
%   via lsqcurvefit, avec A (>=0), nu, FWHM (>=0) et le fond LIBRES.
%   Contrairement a la version precedente, la phase n'a plus besoin
%   d'avoir ete active dans MODEL_CARBONATE_PHASES (phase_model(k).nu et
%   .FWHM(1) servent uniquement de point de depart) -- suppose une phase
%   a UNE SEULE raie (erreur explicite sinon ; VAT, par exemple, n'est
%   pas geree ici).
%
%   ENTREES
%     I_corr            : cube hyperspectral [n_y x n_x x n_wn]
%     wavenumber          : nombres d'onde (cm^-1), pas necessairement
%                         tries (retries ici, I_corr reordonne pareil)
%     phase_model          : structure issue de MODEL_CARBONATE_PHASES
%                         (utilise .nu(1), .FWHM(1) comme point de depart)
%     phase_map            : structure issue de SEGMENT_CARBONATE_PHASES
%                         (utilise .label, uniquement pour l'affichage)
%     roi1                 : [row_start row_end col_start col_end] --
%                         region majoritairement cristalline
%     roi1_phase_idx         : index de la phase cristalline presente
%                         dans roi1 (CAL ou ARA selon votre echantillon)
%     roi2                 : [row_start row_end col_start col_end] --
%                         region majoritairement ACC
%     roi2_phase_idx         : index de la phase presente dans roi2
%     fwhm_instr             : FWHM de la reponse instrumentale de cette
%                         acquisition -- stocke tel quel pour tracabilite
%                         ET utilise pour reconstruire sigma_eff a chaque
%                         evaluation du fit (le FWHM ajuste etant
%                         intrinseque, pas convolue)
%     n_theoretical_points     : nombre de points de la grille fine pour
%                         le modele theorique (defaut 500)
%     save_path             : chemin .mat pour sauvegarder ref_roi (ex :
%                         'ref_roi_tau2ps.mat'), ou '' pour ne pas
%                         sauvegarder (defaut '')
%     delta_nu              : demi-largeur (cm^-1) de l'intervalle
%                         [nu0-delta_nu, nu0+delta_nu] autorise pour nu
%                         (defaut 3)
%     fwhm_bounds            : [facteur_min facteur_max] appliques a
%                         FWHM0 pour les bornes de FWHM, ex [0.5 2]
%                         (defaut [0.5 2])
%
%   SORTIE
%     ref_roi : structure [1x2], une entree par ROI :
%                 .name, .phase_idx, .roi, .fwhm_instr
%                 .mean_spectrum, .std_spectrum             (sur wavenumber)
%                 .A_fit, .nu_fit, .FWHM_fit, .background_fit, .R2, .resnorm
%                 .wavenumber_theoretical, .theoretical_spectrum_fit
%                                                          (grille fine)
%                 .peak_height_fit                          (max de la
%                                                          courbe ajustee,
%                                                          sert de base a
%                                                          la normalisation
%                                                          commune)
if nargin < 15 || isempty(compare_plots), compare_plots = false; end
if nargin < 16 || isempty(ref_roi_compare), ref_roi_compare = ''; end  
if nargin < 18 || isempty(n_theoretical_points), n_theoretical_points = 500; end
if nargin < 19, save_path = ''; end
if nargin < 20 || isempty(delta_nu),     delta_nu = 5;        end
if nargin < 21 || isempty(fwhm_bounds),  fwhm_bounds = [0.5 2]; end


%% ================================================================
% 1. Mise en forme

phase_name_1 = phase_model(roi1_phase_idx).name;
phase_name_2 = phase_model(roi2_phase_idx).name;

if ndims(I_corr) == 4
    I_corr = squeeze(I_corr);
end

[wavenumber, sort_idx] = sort(wavenumber(:).');
I_corr = I_corr(:,:,sort_idx);

[n_y, n_x, ~] = size(I_corr);

assert(numel(roi1) == 4 && numel(roi2) == 4, ...
    'roi1 et roi2 doivent etre [row_start row_end col_start col_end].');

checkROI(roi1, n_y, n_x, 'roi1');
checkROI(roi2, n_y, n_x, 'roi2');

wavenumber_theo = linspace(min(wavenumber), max(wavenumber), n_theoretical_points);

% Couleurs des ROI : rouge et cyan, deux teintes saturees et eloignees
% l'une de l'autre, choisies pour rester visibles sur un fond en niveaux
% de gris ET sur les courbes de spectres.


%% ================================================================
% 2. Extraction + fit lsqcurvefit (A, nu, FWHM, fond), pour chaque ROI

ref_roi(1) = buildRoiEntry(I_corr, wavenumber, wavenumber_theo, phase_model, ...
    roi1, roi1_phase_idx, 1, fwhm_instr, delta_nu, fwhm_bounds,  ... 
    colors_roi(1,:),false, false);
ref_roi(2) = buildRoiEntry(I_corr, wavenumber, wavenumber_theo, phase_model, ...
    roi2, roi2_phase_idx, 2, fwhm_instr, delta_nu, fwhm_bounds, ... 
    colors_roi(2,:),false, false);

%buildRoiEntry( ...
%     I_corr, wavenumber, wavenumber_theo, phase_model, ...
%     roi, k, roi_idx, fwhm_instr, delta_nu, fwhm_bounds, ...
%     nu_is_variable, FWHM_is_variable)

%% ================================================================
% COMPARISON ACC / CAL : 2 ps vs 7 ps
%
% Convention :
%   - ACC       = bleu
%   - Calcite   = orange
%   - 2 ps      = ligne pleine
%   - 7 ps      = ligne tiretée
%
% Panneaux :
%   (a) Spectres normalisés par la calcite
%   (b) Rapport ACC / Calcite
%   (c) SNR ACC et Calcite
%
% Hypothèses :
%   ref_roi(1)           = ACC, 2 ps
%   ref_roi(2)           = Calcite, 2 ps
%   ref_roi_compare(1)   = ACC, 7 ps
%   ref_roi_compare(2)   = Calcite, 7 ps
%
% Les structures doivent contenir :
%   .mean_spectrum
%   .wavenumber
%
% Pour le SNR, si .SNR existe, il est utilisé directement.
% Sinon, le SNR est calculé à partir de .mean_spectrum et
% .std_spectrum.
%% ================================================================

% clearvars -except ref_roi ref_roi_compare wavenumber compare_plots ...
%     noise_global phase_name_1 phase_name_2 phase_map phase_model active_idx

%% -------------------- PARAMETRES -------------------------------

% Indices des phases
idx_CAL = 1;
idx_ACC = 2;

% Couleurs
color_CAL = [0.0000 0.4470 0.7410];
color_ACC = [0.8500 0.3250 0.0980];

% Style des acquisitions
lineStyle_ref     = '--';    % 7 ps
lineStyle_compare = '-';   % 2 ps

% Largeur des courbes
lineWidth = 2.0;

% Taille des marqueurs
markerSize_ACC = 6;
markerSize_CAL = 6;
% Affichage des marqueurs
show_markers = true;

% Si true, affiche les valeurs ACC/Cal directement sur le panneau b
show_ratio_values = true;

% Si true, affiche les valeurs SNR sur le panneau c
show_SNR_values = true;

% Limites spectrales optionnelles
% Exemple : xlim([1060 1110])
use_xlim = false;
xlim_values = [1060 1110];

%% ---------------- VERIFICATION DES DONNEES ---------------------

assert(numel(ref_roi) >= 2, ...
    'ref_roi doit contenir au moins ACC et Calcite.');

assert(numel(ref_roi_compare) >= 2, ...
    'ref_roi_compare doit contenir au moins ACC et Calcite.');

%% ================================================================
% 1. EXTRACTION DES SPECTRES
% ================================================================

acc_ref = ref_roi(idx_ACC).mean_spectrum(:);
cal_ref = ref_roi(idx_CAL).mean_spectrum(:);

acc_comp = ref_roi_compare(idx_ACC).mean_spectrum(:);
cal_comp = ref_roi_compare(idx_CAL).mean_spectrum(:);

% Wavenumbers
wn_ref = ref_roi(idx_ACC).wavenumber(:);
wn_comp = ref_roi_compare(idx_ACC).wavenumber(:);

% Vérification
assert(numel(wn_ref) == numel(acc_ref), ...
    'Le wavenumber et le spectre ACC 7 ps n''ont pas la même taille.');

assert(numel(wn_ref) == numel(cal_ref), ...
    'Le wavenumber et le spectre Calcite 7 ps n''ont pas la même taille.');

assert(numel(wn_comp) == numel(acc_comp), ...
    'Le wavenumber et le spectre ACC 2 ps n''ont pas la même taille.');

assert(numel(wn_comp) == numel(cal_comp), ...
    'Le wavenumber et le spectre Calcite 2 ps n''ont pas la même taille.');

%% ================================================================
% 2. SOUSTRACTION DU MINIMUM
%
% Chaque spectre commence à 0.
%% ================================================================

acc_ref_0 = acc_ref - min(acc_ref);
cal_ref_0 = cal_ref - min(cal_ref);

acc_comp_0 = acc_comp - min(acc_comp);
cal_comp_0 = cal_comp - min(cal_comp);

%% ================================================================
% 3. NORMALISATION PAR LA CALCITE DE CHAQUE ACQUISITION
%
% IMPORTANT :
%
% ACC 2 ps / max(Calcite 2 ps)
% Calcite 2 ps / max(Calcite 2 ps)
%
% ACC 7 ps / max(Calcite 7 ps)
% Calcite 7 ps / max(Calcite 7 ps)

cal_max_ref = max(cal_ref_0);
cal_max_comp = max(cal_comp_0);

if cal_max_ref <= 0
    error('Maximum de la calcite 7 ps <= 0.');
end

if cal_max_comp <= 0
    error('Maximum de la calcite 2 ps <= 0.');
end

acc_ref_norm = acc_ref_0 / cal_max_ref;
cal_ref_norm = cal_ref_0 / cal_max_ref;

acc_comp_norm = acc_comp_0 / cal_max_comp;
cal_comp_norm = cal_comp_0 / cal_max_comp;

%% ================================================================
% 4. RAPPORT ACC / CALCITE
%
% On utilise les amplitudes après soustraction du minimum.
%
% R = max(ACC) / max(Calcite)
%
% C'est exactement le rapport des hauteurs relatives conservé
% par la normalisation précédente.
%% ================================================================

A_ACC_ref = max(acc_ref_0);
A_CAL_ref = max(cal_ref_0);

A_ACC_comp = max(acc_comp_0);
A_CAL_comp = max(cal_comp_0);

ratio_ref = A_ACC_ref / A_CAL_ref;
ratio_comp = A_ACC_comp / A_CAL_comp;

ratio_values = [ratio_ref ratio_comp];

%% ================================================================
% 5. CALCUL / EXTRACTION DU SNR
% ================================================================

SNR_ACC_ref = getSNR(ref_roi(idx_ACC));
SNR_CAL_ref = getSNR(ref_roi(idx_CAL));

SNR_ACC_comp = getSNR(ref_roi_compare(idx_ACC));
SNR_CAL_comp = getSNR(ref_roi_compare(idx_CAL));

SNR_values = [
    SNR_ACC_ref   SNR_ACC_comp;
    SNR_CAL_ref   SNR_CAL_comp
];

%% ================================================================
% 6. FIGURE
% ================================================================


%% ================================================================
% PANEL A — SPECTRES
% ================================================================

figure( ...
    'Color', 'white', ...
    'Position', [100 100 1100 850]);

hold on;

% ---------- 7 ps ----------
if show_markers
    plot(wn_ref, acc_ref_norm, ...
        'Color', color_ACC, ...
        'LineStyle', lineStyle_ref, ...
        'LineWidth', lineWidth, ...
        'Marker', '*', ...
        'MarkerSize', markerSize_ACC, ...
        'DisplayName', sprintf('%s — 7 ps',phase_name_2));
else
    plot(wn_ref, acc_ref_norm, ...
        'Color', color_ACC, ...
        'LineStyle', lineStyle_ref, ...
        'LineWidth', lineWidth, ...
        'DisplayName', sprintf('%s — 7 ps',phase_name_2));
end

plot(wn_ref, cal_ref_norm, ...
    'Color', color_CAL, ...
    'LineStyle', lineStyle_ref, ...
    'LineWidth', lineWidth, ...
    'Marker', 'x', ...
    'MarkerSize', markerSize_CAL, ...
    'DisplayName', sprintf('%s — 7 ps',phase_name_1));

% ---------- 2 ps ----------
if show_markers
    plot(wn_comp, acc_comp_norm, ...
        'Color', color_ACC, ...
        'LineStyle', lineStyle_compare, ...
        'LineWidth', lineWidth, ...
        'Marker', '*', ...
        'MarkerSize', markerSize_ACC, ...
        'DisplayName', sprintf('%s — 2 ps',phase_name_2));
else
    plot(wn_comp, acc_comp_norm, ...
        'Color', color_ACC, ...
        'LineStyle', lineStyle_compare, ...
        'LineWidth', lineWidth, ...
        'DisplayName', sprintf('%s — 2 ps',phase_name_2));
end

plot(wn_comp, cal_comp_norm, ...
    'Color', color_CAL, ...
    'LineStyle', lineStyle_compare, ...
    'LineWidth', lineWidth, ...
    'Marker', 'x', ...
    'MarkerSize', markerSize_CAL, ...
    'DisplayName', sprintf('%s — 2 ps',phase_name_1));

% Calcite = 1
yline(1, ':', ...
    'Color', [0.4 0.4 0.4], ...
    'LineWidth', 1.2, ...
    'HandleVisibility', 'off');

grid on;
xlabel('Raman shift (cm^{-1})');
ylabel('Normalized intensity');

title(sprintf('(a) %s and %s spectra',phase_name_2,phase_name_1));

legend( ...
    'Location', 'northeast', ...
    'Box', 'off');

set(gca, ...
    'FontSize', 12, ...
    'LineWidth', 1, ...
    'TickDir', 'out');

if use_xlim
    xlim(xlim_values);
end

%% ================================================================
% PANEL B — ACC / CALCITE
% ================================================================

figure( ...
    'Color', 'white', ...
    'Position', [100 100 1100 850]);

tiledlayout(2,1, ...
    'TileSpacing', 'compact', ...
    'Padding', 'compact');

nexttile;
hold on;
box on;

x_ratio = [1 2];

b = bar(x_ratio, ratio_values, ...
    0.55, ...
    'FaceColor', 'flat');

% Même couleur pour les deux acquisitions
b.CData(1,:) = color_ACC;
b.CData(2,:) = color_ACC;

% Ligne horizontale éventuellement utile
yline(1, ':', ...
    'Color', [0.4 0.4 0.4], ...
    'LineWidth', 1.2, ...
    'HandleVisibility', 'off');

set(gca, ...
    'XTick', x_ratio, ...
    'XTickLabel', {'7 ps', '2 ps'}, ...
    'FontSize', 12, ...
    'LineWidth', 1, ...
    'TickDir', 'out');

ylabel(sprintf('%s / %s',phase_name_2,phase_name_1));

title(sprintf('(b) Relative %s-to-%s signal',phase_name_2,phase_name_1));

if show_ratio_values
    for i = 1:2
        text( ...
            x_ratio(i), ...
            ratio_values(i), ...
            sprintf(' %.2f', ratio_values(i)), ...
            'VerticalAlignment', 'bottom', ...
            'HorizontalAlignment', 'center', ...
            'FontSize', 11);
    end
end

%% ================================================================
% PANEL C — SNR
% ================================================================

nexttile;
hold on;
box on;

% Organisation :
%
%       7 ps     2 ps
% ACC
% Cal

x = [1 2];

bar_width = 0.32;

% ACC
bar( ...
    x - bar_width/2, ...
    SNR_values(1,:), ...
    bar_width, ...
    'FaceColor', color_ACC, ...
    'EdgeColor', 'none', ...
    'DisplayName', sprintf('%s',phase_name_2));

% Calcite
bar( ...
    x + bar_width/2, ...
    SNR_values(2,:), ...
    bar_width, ...
    'FaceColor', color_CAL, ...
    'EdgeColor', 'none', ...
    'DisplayName', sprintf('%s',phase_name_1));

% Ligne SNR = noise_global
yline(noise_global, '--', ...
    'Color', [0.4 0.4 0.4], ...
    'LineWidth', 1.2, ...
    'DisplayName', sprintf('SNR = %.2f', noise_global));

set(gca, ...
    'XTick', x, ...
    'XTickLabel', {'7 ps', '2 ps'}, ...
    'FontSize', 12, ...
    'LineWidth', 1, ...
    'TickDir', 'out');

xlabel('Acquisition');
ylabel('SNR');

title('(c) Signal-to-noise ratio');

legend( ...
    'Location', 'northwest', ...
    'Box', 'off');

if show_SNR_values

    % ACC
    for i = 1:2
        text( ...
            x(i) - bar_width/2, ...
            SNR_values(1,i), ...
            sprintf(' %.1f', SNR_values(1,i)), ...
            'VerticalAlignment', 'bottom', ...
            'HorizontalAlignment', 'center', ...
            'FontSize', 10);
    end

    % Calcite
    for i = 1:2
        text( ...
            x(i) + bar_width/2, ...
            SNR_values(2,i), ...
            sprintf(' %.1f', SNR_values(2,i)), ...
            'VerticalAlignment', 'bottom', ...
            'HorizontalAlignment', 'center', ...
            'FontSize', 10);
    end

end

%% ================================================================
% 7. AFFICHAGE DES RESULTATS DANS LA CONSOLE
% ================================================================

fprintf('\n');
fprintf('====================================================\n');
fprintf('       COMPARISON %s / %s — 7 ps vs 2 ps\n',phase_name_2,phase_name_1);
fprintf('====================================================\n');

fprintf('\n %s / %s:\n',phase_name_2,phase_name_1);
fprintf('  7 ps : %.4f\n', ratio_ref);
fprintf('  2 ps : %.4f\n', ratio_comp);

fprintf('\nEvolution du rapport : %.2f %%\n', ...
    100 * (ratio_comp/ratio_ref - 1));

fprintf('\nSNR %s:\n',phase_name_2);
fprintf('  7 ps : %.2f\n', SNR_ACC_ref);
fprintf('  2 ps : %.2f\n', SNR_ACC_comp);

fprintf('\nSNR %s:\n',phase_name_1);
fprintf('  7 ps : %.2f\n', SNR_CAL_ref);
fprintf('  2 ps : %.2f\n', SNR_CAL_comp);

fprintf('\n====================================================\n');


%% ================================================================
% FONCTION LOCALE — EXTRACTION / CALCUL DU SNR
% ================================================================

function SNR = getSNR(entry)

    % --------------------------------------------------------------
    % CAS 1 : le SNR est déjà présent dans la structure
    % --------------------------------------------------------------

    if isfield(entry, 'SNR') && ~isempty(entry.SNR)

        SNR = entry.SNR;

        return;

    end

    % --------------------------------------------------------------
    % CAS 2 : SNR calculé à partir de mean_spectrum/std_spectrum
    %
    % SNR = amplitude du signal / bruit
    %
    % Ici :
    %   signal = max(mean spectrum - minimum)
    %   noise  = moyenne du std_spectrum
    %
    % Cette définition peut être remplacée par ton estimation
    % de bruit spécifique si tu en as déjà une.
    % --------------------------------------------------------------

    if isfield(entry, 'mean_spectrum') && ...
            isfield(entry, 'std_spectrum')

        spectrum = entry.mean_spectrum(:);
        noise = entry.std_spectrum(:);

        signal = max(spectrum - min(spectrum));

        noise_value = mean(noise, 'omitnan');

        if noise_value > 0
            SNR = signal / noise_value;
        else
            SNR = NaN;
        end

        return;

    end

    % --------------------------------------------------------------
    % Si aucune information disponible
    % --------------------------------------------------------------

    warning( ...
        'Impossible de calculer le SNR pour %s.', ...
        getEntryName(entry));

    SNR = NaN;

end




%% ================================================================
% 4. Affichage : ROI sur la carte de segmentation (colormap neutre)

% figure('Color', 'white','Position', [100 100 700 650]);
% imagesc(phase_map.label); axis image; colorbar;
% % colormap(gca, gray);
% clim([0, numel(phase_model)+2]);
% hold on;

plotSegmentation_ROI(phase_map, phase_model, active_idx, ...
    phase_colors,colors_roi,ref_roi,sub_dir_save,exportgraphics_segm_roi);


%% ================================================================
% 5. Sauvegarde (optionnelle)

if ~isempty(save_path)
    save(save_path, 'ref_roi');
    fprintf('ref_roi sauvegarde dans %s\n', save_path);
end

end

%% ================================================================
% PETITE FONCTION UTILITAIRE POUR LE NOM
%% ================================================================

function name = getEntryName(entry)

    if isfield(entry, 'name')
        name = char(entry.name);
    else
        name = 'ROI inconnue';
    end

end


% %% ================================================================
% % 3. Affichage : les deux ROI sur UN SEUL graphe, normalisation commune
% 
% 
% figure('Color', 'white', 'Position', [100 100 1050 700]);
% hold on;
% 
% %% =========================
% % Couleurs
% % ==========================
% 
% % Spectres de référence : ACC / Calcite
% colors_ref = [
%     0.0000 0.4470 0.7410;   % bleu
%     0.8500 0.3250 0.0980   % orange
% ];
% 
% % Spectres de comparaison
% colors_compare = [
%     0.4940 0.1840 0.5560;   % violet
%     0.4660 0.6740 0.1880    % vert
% ];
% 
% 
% %% =========================
% % Normalisation commune ACC + Calcite
% % ==========================
% 
% % Récupération des deux spectres
% spec1 = ref_roi(1).mean_spectrum(:);
% spec2 = ref_roi(2).mean_spectrum(:);
% 
% % Minimum commun
% min_common = min([spec1; spec2]);
% 
% % Maximum commun
% max_common = max([spec1; spec2]);
% 
% % Normalisation avec les mêmes valeurs pour les deux
% spec1_norm = (spec1 - min_common) / max_common;
% spec2_norm = (spec2 - min_common) / max_common;
% 
% 
% %% =========================
% % Tracé ACC + Calcite
% % ==========================
% 
% plot(wavenumber(:), spec1_norm, ...
%     '-o', ...
%     'Color', colors_ref(1,:), ...
%     'MarkerFaceColor', colors_ref(1,:), ...
%     'MarkerSize', 4, ...
%     'LineWidth', 2, ...
%     'DisplayName', ref_roi(1).name);
% 
% plot(wavenumber(:), spec2_norm, ...
%     '-o', ...
%     'Color', colors_ref(2,:), ...
%     'MarkerFaceColor', colors_ref(2,:), ...
%     'MarkerSize', 4, ...
%     'LineWidth', 2, ...
%     'DisplayName', ref_roi(2).name);
% 
% 
% %% =========================
% % Spectres de comparaison
% % ==========================
% 
% if compare_plots
% 
%     for p = 1:numel(ref_roi_compare)
% 
%         % Spectre
%         spectrum = ref_roi_compare(p).mean_spectrum(:);
% 
%         % Normalisation avec le même max/min que ACC + Calcite
%         spectrum_norm = (spectrum - min_common) / max_common;
% 
%         % Tracé
%         plot(ref_roi_compare(p).wavenumber(:), ...
%             spectrum_norm, ...
%             '-o', ...
%             'Color', colors_compare(p,:), ...
%             'MarkerFaceColor', colors_compare(p,:), ...
%             'MarkerSize', 4, ...
%             'LineWidth', 2, ...
%             'DisplayName', ref_roi_compare(p).name);
%     end
% end
% 
% 
% %% =========================
% % Mise en forme
% % ==========================
% 
% xlabel('Wavenumber (cm^{-1})', 'FontSize', 12);
% ylabel('Normalized intensity', 'FontSize', 12);
% 
% title('Comparison of ACC and calcite spectra', ...
%       'FontSize', 13);
% 
% legend('Location', 'best', 'Box', 'off');
% 
% grid on;
% box on;
% 
% set(gca, ...
%     'FontSize', 11, ...
%     'LineWidth', 1);






