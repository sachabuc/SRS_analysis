function ref_roi = compare_roi_to_theoretical_model( ...
          I_corr, wavenumber, pixel_fit,phase_idx, phase_model, phase_map, ...
          roi1, roi2, n_theoretical_points)
%COMPARE_ROI_TO_THEORETICAL_MODEL Compare le spectre moyen de deux
%regions d'interet (ROI) a leur modele theorique respectif, tous deux
%normalises (pic = 1) pour une comparaison de FORME plutot que
%d'amplitude absolue. Affiche aussi les deux ROI positionnees sur la
%carte de segmentation (phase_map.label).
%
%   ref_roi = COMPARE_ROI_TO_THEORETICAL_MODEL(I_corr, wavenumber, ...
%       phase_model, phase_map, roi1, roi1_phase_idx, roi2, ...
%       roi2_phase_idx, n_theoretical_points)
%
%   Pense pour une verification qualitative rapide : "le spectre moyen
%   d'une zone connue pour etre majoritairement une phase cristalline
%   (ROI 1, calcite OU aragonite) ressemble-t-il a la forme theorique de
%   cette phase ? Et une zone majoritairement ACC (ROI 2) ?" -- sans
%   passer par le fit complet ni par la selection top-N de
%   PLOT_PHASE_REFERENCE_SPECTRA.
%
%   ENTREES
%     I_corr            : cube hyperspectral [n_y x n_x x n_wn]
%     wavenumber          : nombres d'onde (cm^-1), pas necessairement
%                         tries (retries ici, I_corr reordonne pareil)
%     phase_model          : structure issue de MODEL_CARBONATE_PHASES
%                         (utilise .sigma_eff, donc la phase visee doit
%                         avoir ete active -- use_xxx=true -- lors de cet
%                         appel)
%     phase_map            : structure issue de SEGMENT_CARBONATE_PHASES
%                         (utilise .label, uniquement pour l'affichage)
%     roi1                 : [row_start row_end col_start col_end] --
%                         region majoritairement cristalline
%     roi1_phase_idx         : index de la phase cristalline presente
%                         dans roi1 (CAL ou ARA selon votre echantillon)
%     roi2                 : [row_start row_end col_start col_end] --
%                         region majoritairement ACC
%     roi2_phase_idx         : index de la phase presente dans roi2
%     n_theoretical_points     : nombre de points de la grille fine pour
%                         le modele theorique (defaut 500)
%
%   SORTIE
%     ref_roi : structure [1x2], une entree par ROI :
%                 .name, .phase_idx, .roi
%                 .mean_spectrum, .mean_spectrum_norm     (sur wavenumber)
%                 .wavenumber_theoretical, .theoretical_spectrum, ...
%                 .theoretical_spectrum_norm               (grille fine)

% if phase_model(1).use 
%     roi1_phase_idx = 1;
% elseif phase_model(2).use
%     roi1_phase_idx = 2; 
% end

% if phase_model(4).use 
%     roi2_phase_idx = 4;
% elseif phase_model(5).use
%     roi2_phase_idx = 5; 
% end
 
if nargin < 9 || isempty(n_theoretical_points)
    n_theoretical_points = 500;
end
 
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
 
%% ================================================================
% 2. Extraction + normalisation, pour chaque ROI
roi1_phase_idx = phase_idx(1);
roi2_phase_idx = phase_idx(2);

ref_roi(1) = buildRoiEntry(I_corr, wavenumber_theo, phase_model, roi1, roi1_phase_idx);
ref_roi(2) = buildRoiEntry(I_corr, wavenumber_theo, phase_model, roi2, roi2_phase_idx);
 
%% ================================================================
% 3. Affichage : spectres normalises
 
figure('Color', 'white', 'Position', [100 100 1200 500]);
colors = lines(2);
 
for j = 1:2
    plot(wavenumber, ref_roi(j).mean_spectrum_norm, '-o', 'Color', colors(j,:), ...
         'MarkerFaceColor', colors(j,:), 'MarkerSize', 4, 'LineWidth', 2, ...
         'DisplayName', sprintf('Spectre moyen %s',ref_roi(j).name));
    hold on;
    plot(ref_roi(j).wavenumber_theoretical, ref_roi(j).theoretical_spectrum_norm, '--', ...
         'Color', colors(j,:), 'LineWidth', 1.5, 'DisplayName', sprintf('Modele theorique %s',ref_roi(j).name));
    xlabel('Wavenumber (cm^{-1})', 'FontSize', 12);
    ylabel('Intensite normalisee', 'FontSize', 12);
    % title(sprintf('ROI %d : %s', j, ref_roi(j).name), 'FontSize', 13);
    legend('Location', 'best');
    grid on; box on; set(gca, 'FontSize', 11);
end
 
%% ================================================================
% 4. Affichage : ROI sur la carte de segmentation
 
figure('Color', 'white', 'Position', [100 100 700 650]);
imagesc(phase_map.label); axis image; colorbar;
clim([0, numel(phase_model)+2]);
hold on;
 
drawROI(roi1, colors(1,:), ref_roi(1).name);
drawROI(roi2, colors(2,:), ref_roi(2).name);
 
xlabel('Colonne', 'FontSize', 12);
ylabel('Ligne', 'FontSize', 12);
title('ROI positionnees sur la segmentation (label)', 'FontSize', 13);
legend('Location', 'best');
hold off;
 
end
 
 
%% ====================================================================
%  FONCTIONS LOCALES
%% ====================================================================
 
function checkROI(roi, n_y, n_x, roi_name)
    assert(roi(1) >= 1 && roi(2) <= n_y && roi(1) <= roi(2), ...
        '%s : lignes hors bornes ou mal ordonnees (1..%d).', roi_name, n_y);
    assert(roi(3) >= 1 && roi(4) <= n_x && roi(3) <= roi(4), ...
        '%s : colonnes hors bornes ou mal ordonnees (1..%d).', roi_name, n_x);
end
 
function entry = buildRoiEntry(I_corr, wavenumber_theo, phase_model, roi, k)
    sub_cube = I_corr(roi(1):roi(2), roi(3):roi(4), :);
    [ry, rx, rw] = size(sub_cube);
    flat = reshape(permute(sub_cube, [3 1 2]), rw, ry*rx).';
    mean_spec = mean(flat, 1);
 
    assert(~isempty(phase_model(k).sigma_eff), ...
        ['phase_model(%d).sigma_eff est vide : la phase doit etre active ' ...
         '(use_xxx=true) au moment de MODEL_CARBONATE_PHASES pour etre utilisee ici.'], k);

    theo_spec = phaseModelSpectrum(phase_model(k), wavenumber_theo);
    
    entry.name                     = phase_model(k).name;
    entry.use                      = phase_model(k).use;
    entry.phase_idx                = k;
    entry.roi                      = roi;
    entry.mean_spectrum            = mean_spec;
    entry.mean_spectrum_norm       = mean_spec / (max(mean_spec));
    entry.wavenumber_theoretical    = wavenumber_theo;
    entry.theoretical_spectrum     = theo_spec;
    entry.theoretical_spectrum_norm = theo_spec / max(theo_spec);
end
 
function drawROI(roi, color, label_text)
    row_start = roi(1); row_end = roi(2);
    col_start = roi(3); col_end = roi(4);
    rectangle('Position', [col_start, row_start, col_end-col_start, row_end-row_start], ...
              'EdgeColor', color, 'LineWidth', 2, 'LineStyle', '-');
    plot(NaN, NaN, '-', 'Color', color, 'LineWidth', 2, 'DisplayName', label_text);
end