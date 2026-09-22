function ref_roi = compare_spectrums_double( ...
          I_corr, wavenumber, phase_model, phase_map, ...
          roi1, roi1_phase_idx, roi2, roi2_phase_idx, ...
          fwhm_instr,active_idx, phase_colors, colors_roi,...
          sub_dir_save,exportgraphics_segm_roi,ref_roi_compare, compare_plots,...
          n_theoretical_points, save_path, delta_nu, fwhm_bounds)
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
if nargin < 17 || isempty(n_theoretical_points), n_theoretical_points = 500; end
if nargin < 18, save_path = ''; end
if nargin < 19 || isempty(delta_nu),     delta_nu = 5;        end
if nargin < 20 || isempty(fwhm_bounds),  fwhm_bounds = [0.5 2]; end


%% ================================================================
% 1. Mise en forme

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
    roi1, 1, roi1_phase_idx, fwhm_instr, delta_nu, fwhm_bounds,  ... 
    colors_roi(1,:),false, false);
ref_roi(2) = buildRoiEntry(I_corr, wavenumber, wavenumber_theo, phase_model, ...
    roi2, 4, roi2_phase_idx, fwhm_instr, delta_nu, fwhm_bounds, ... 
    colors_roi(2,:),false, false);

%buildRoiEntry( ...
%     I_corr, wavenumber, wavenumber_theo, phase_model, ...
%     roi, k, roi_idx, fwhm_instr, delta_nu, fwhm_bounds, ...
%     nu_is_variable, FWHM_is_variable)

%% ================================================================
% 3. Affichage : les deux ROI sur UN SEUL graphe, normalisation commune


figure('Color', 'white', 'Position', [100 100 1050 700]);
hold on;

%% =========================
% Couleurs
% ==========================

% Spectres de référence : ACC / Calcite
colors_ref = [
    0.0000 0.4470 0.7410;   % bleu
    0.8500 0.3250 0.0980   % orange
];

% Spectres de comparaison
colors_compare = [
    0.4940 0.1840 0.5560;   % violet
    0.4660 0.6740 0.1880    % vert
];


%% =========================
% Normalisation commune ACC + Calcite
% ==========================

% Récupération des deux spectres
spec1 = ref_roi(1).mean_spectrum(:);
spec2 = ref_roi(2).mean_spectrum(:);

% Minimum commun
min_common = min([spec1; spec2]);

% Maximum commun
max_common = max([spec1; spec2]);

% Normalisation avec les mêmes valeurs pour les deux
spec1_norm = (spec1 - min_common) / max_common;
spec2_norm = (spec2 - min_common) / max_common;


%% =========================
% Tracé ACC + Calcite
% ==========================

plot(wavenumber(:), spec1_norm, ...
    '-o', ...
    'Color', colors_ref(1,:), ...
    'MarkerFaceColor', colors_ref(1,:), ...
    'MarkerSize', 4, ...
    'LineWidth', 2, ...
    'DisplayName', ref_roi(1).name);

plot(wavenumber(:), spec2_norm, ...
    '-o', ...
    'Color', colors_ref(2,:), ...
    'MarkerFaceColor', colors_ref(2,:), ...
    'MarkerSize', 4, ...
    'LineWidth', 2, ...
    'DisplayName', ref_roi(2).name);


%% =========================
% Spectres de comparaison
% ==========================

if compare_plots

    for p = 1:numel(ref_roi_compare)

        % Spectre
        spectrum = ref_roi_compare(p).mean_spectrum(:);

        % Normalisation avec le même max/min que ACC + Calcite
        spectrum_norm = (spectrum - min_common) / max_common;

        % Tracé
        plot(ref_roi_compare(p).wavenumber(:), ...
            spectrum_norm, ...
            '-o', ...
            'Color', colors_compare(p,:), ...
            'MarkerFaceColor', colors_compare(p,:), ...
            'MarkerSize', 4, ...
            'LineWidth', 2, ...
            'DisplayName', ref_roi_compare(p).name);
    end
end


%% =========================
% Mise en forme
% ==========================

xlabel('Wavenumber (cm^{-1})', 'FontSize', 12);
ylabel('Normalized intensity', 'FontSize', 12);

title('Comparison of ACC and calcite spectra', ...
      'FontSize', 13);

legend('Location', 'best', 'Box', 'off');

grid on;
box on;

set(gca, ...
    'FontSize', 11, ...
    'LineWidth', 1);


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








