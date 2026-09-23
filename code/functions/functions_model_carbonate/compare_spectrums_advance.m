function ref_roi = compare_spectrums_advance( ...
          I_corr, wavenumber, phase_model, phase_map, ...
          roi1, roi1_phase_idx, roi2, roi2_phase_idx, ...
          fwhm_instr,active_idx, phase_colors, colors_roi,...
          sub_dir_save,exportgraphics_segm_roi,...
          n_theoretical_points, results_dir, delta_nu, fwhm_bounds)
%COMPARE_ROI_TO_THEORETICAL_MODEL Ajuste (lsqcurvefit) le spectre moyen
%de deux regions d'interet (ROI) sur leur modele theorique respectif
%(amplitude + fond libres, position/largeur fixees par phase_model), et
%affiche les deux ROI sur UN SEUL graphe (avec bande +/- 1 ecart-type),
%normalise par rapport a la courbe theorique ajustee la plus haute des
%deux. Affiche aussi les deux ROI positionnees sur la carte de
%segmentation (phase_map.label), avec un colormap volontairement neutre
%(gris) pour que les ROI -- tracees dans des couleurs vives et
%contrastantes -- restent bien visibles quel que soit le label
%dessous.
%
%   ref_roi = COMPARE_ROI_TO_THEORETICAL_MODEL(I_corr, wavenumber, ...
%       phase_model, phase_map, roi1, roi1_phase_idx, roi2, ...
%       roi2_phase_idx, fwhm_instr, n_theoretical_points, results_dir)
%
%   Pour chaque ROI, le spectre moyen est ajuste par :
%       I(wavenumber) = A * G_k(wavenumber) + fond
%   via lsqcurvefit, avec G_k = PHASEMODELSPECTRUM(phase_model(k), ...)
%   -- position/largeur fixees (celles de phase_model, deja convoluees
%   par la reponse instrumentale via sigma_eff), seules A (>=0) et le
%   fond sont libres. C'est un fit a 2 parametres, pas le fit complet
%   multi-phases de FIT_PIXEL_PHASES.
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
%     fwhm_instr             : FWHM de la reponse instrumentale de cette
%                         acquisition -- stocke tel quel pour tracabilite
%                         (doit correspondre a celui utilise pour
%                         construire phase_model ; n'intervient pas
%                         directement dans le calcul, deja incorpore
%                         dans phase_model(k).sigma_eff)
%     n_theoretical_points     : nombre de points de la grille fine pour
%                         le modele theorique (defaut 500)
%     results_dir             : chemin .mat pour sauvegarder ref_roi (ex :
%                         'ref_roi_tau2ps.mat'), ou '' pour ne pas
%                         sauvegarder (defaut '') -- pour reutilisation
%                         lors d'une comparaison avec une autre
%                         acquisition (ex : 7ps)
%
%   SORTIE
%     ref_roi : structure [1x2], une entree par ROI :
%                 .name, .phase_idx, .roi, .fwhm_instr
%                 .mean_spectrum, .std_spectrum             (sur wavenumber)
%                 .A_fit, .background_fit, .R2, .resnorm    (fit lsqcurvefit)
%                 .wavenumber_theoretical, .theoretical_spectrum_fit
%                                                          (grille fine)
%                 .peak_height_fit                          (max de la
%                                                          courbe ajustee,
%                                                          sert de base a
%                                                          la normalisation
%                                                          commune)
 

if nargin < 15 || isempty(n_theoretical_points), n_theoretical_points = 500; end
if nargin < 16, save_path = ''; end
if nargin < 17 || isempty(delta_nu),     delta_nu = 3;        end
if nargin < 18 || isempty(fwhm_bounds),  fwhm_bounds = [0.75 1.5]; end

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
% colors_roi = [1 0 0; 0 0.8 0.8];
 
%% ================================================================
% 2. Extraction + fit lsqcurvefit, pour chaque ROI
 
ref_roi(1) = buildRoiEntry(I_corr, wavenumber, wavenumber_theo, phase_model, ...
    roi1, 1, roi1_phase_idx, fwhm_instr, delta_nu, fwhm_bounds,  ... 
    colors_roi(1,:),true, true);
ref_roi(2) = buildRoiEntry(I_corr, wavenumber, wavenumber_theo, phase_model, ...
    roi2, 4, roi2_phase_idx, fwhm_instr, delta_nu, fwhm_bounds, ... 
    colors_roi(2,:),true, true);
 
%% ================================================================
% 3. Affichage : les deux ROI sur UN SEUL graphe, normalisation commune
 
norm_factor = max([ref_roi.peak_height_fit]);
 
figure('Color', 'white', 'Position', [100 100 1000 700]);
hold on;
 
for j = 1:2
    upper = (ref_roi(j).mean_spectrum + ref_roi(j).std_spectrum) / norm_factor;
    lower = (ref_roi(j).mean_spectrum - ref_roi(j).std_spectrum) / norm_factor;
    upper      = upper(:).';
    lower      = lower(:).';

    fill([wavenumber, fliplr(wavenumber)], [upper, fliplr(lower)], colors_roi(j,:), ...
         'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');

        % Spectre expérimental
    plot(wavenumber, ...
         ref_roi(j).mean_spectrum / ref_roi(1).norm_factor, ...
         '-o', 'Color', colors_roi(j,:), ...
         'MarkerFaceColor', colors_roi(j,:),...
         'MarkerSize', 4, ...
         'LineWidth', 2, ...
         'DisplayName', sprintf('%s : moyenne ROI', ...
                                ref_roi(j).name));

    % Fit théorique
    plot(ref_roi(j).wavenumber_theoretical, ...
         ref_roi(j).theoretical_spectrum_fit / ref_roi(1).norm_factor, ...
         '--', 'Color', colors_roi(j,:), ...
         'MarkerFaceColor', colors_roi(j,:),...
         'LineWidth', 1.5, ...
         'DisplayName', sprintf( ...
             '%s : fit (A=%.3g, \\nu=%.2f, FWHM=%.2f, R^2=%.3f)', ...
             ref_roi(j).name, ...
             ref_roi(j).A_fit, ...
             ref_roi(j).nu_fit, ...
             ref_roi(j).FWHM_fit, ...
             ref_roi(j).R2));
 

end
 
xlabel('Wavenumber (cm^{-1})', 'FontSize', 12);
ylabel('Intensite normalisee (/ pic theorique ajuste le plus eleve)', 'FontSize', 12);
title('Comparaison ROI cristalline vs ACC, meme echelle', 'FontSize', 13);
legend('Location', 'best');
grid on; box on; set(gca, 'FontSize', 11);
 
%% ================================================================
% 4. Affichage : ROI sur la carte de segmentation (colormap neutre)
 
plotSegmentation_ROI(phase_map, phase_model, active_idx, ...
    phase_colors,colors_roi,ref_roi,sub_dir_save,exportgraphics_segm_roi);
 
%% ================================================================
% 5. Sauvegarde (optionnelle)

if ~isempty(results_dir)
    save(results_dir, 'ref_roi');
    fprintf('ref_roi sauvegarde dans %s\n', results_dir);
end
 
end

