function [phase_map, composition_map] = segment_carbonate_phases( ...
          I_corr, pixel_fit, phase_model, noise_map, ...
          R2_min, threshold_sigma_noise, min_points_above_noise, ...
          alpha_dominance, dominance_phases, display_figures)
%SEGMENT_CARBONATE_PHASES Filtre les pixels peu fiables et construit la
%carte de phase dominante + composition, a partir du fit non-lineaire.
%
%   [phase_map, composition_map] = SEGMENT_CARBONATE_PHASES(I_corr, ...
%       pixel_fit, phase_model, noise_map, R2_min, ...
%       threshold_sigma_noise, min_points_above_noise, alpha_dominance, ...
%       dominance_phases, display_figures)
%
%   FILTRAGE (deux criteres independants, un pixel doit passer les deux)
%     - R2 >= R2_min                (qualite du fit non-lineaire)
%     - nb de points du spectre au-dessus de threshold_sigma_noise x
%       noise_map(pixel) >= min_points_above_noise (presence d'un vrai
%       signal, independant de la qualite du fit)
%
%   SEGMENTATION (pixels gardes uniquement)
%     Comparaison des DEUX plus grandes amplitudes BRUTES, mais
%     UNIQUEMENT parmi les phases marquees dans dominance_phases
%     (A_sorted(1) >= A_sorted(2) apres tri sur ce sous-ensemble) :
%       - si A_sorted(1) > alpha_dominance * A_sorted(2) : dominante =
%         la plus grande (les phases plus petites que la 2e n'ont pas
%         besoin d'etre testees, elles ne peuvent pas dominer non plus,
%         le tableau etant trie)
%       - sinon : AMBIGU -- les deux plus grandes sont trop proches pour
%         trancher, quel que soit le nombre de phases actives
%     Une phase active mais absente de dominance_phases continue d'etre
%     ajustee et apparait dans composition_map (calcule sur TOUTES les
%     phases actives, pas seulement dominance_phases), mais ne peut
%     jamais devenir la phase dominante -- utile pour ecarter une phase
%     peu fiable (ex : CAL/ARA quasi-degenerees) de la competition sans
%     la retirer du modele.
%
%   ENTREES
%     I_corr                  : cube hyperspectral [n_y x n_x x n_wn]
%     pixel_fit                : structure issue de FIT_PIXEL_PHASES
%     phase_model               : structure issue de MODEL_CARBONATE_PHASES
%     noise_map                 : [n_y x n_x], reference de bruit par
%                                 pixel (ex : reshape([pixel_data.noise],
%                                 n_y, n_x) -- a remplacer plus tard par
%                                 une estimation substrat si disponible)
%     R2_min                    : R^2 minimal pour garder le pixel
%     threshold_sigma_noise      : facteur x noise_map pour compter un
%                                 point comme "au-dessus du bruit"
%     min_points_above_noise     : nb minimal de points au-dessus du
%                                 bruit pour garder le pixel
%     alpha_dominance             : facteur multiplicatif requis pour que
%                                 la plus grande amplitude l'emporte sur
%                                 la deuxieme (alpha_dominance = 1 <=>
%                                 argmax simple ; > 1 <=> il faut une
%                                 avance plus nette)
%     dominance_phases            : vecteur logique [1 x n_phases],  true =
%                                 cette phase participe a la comparaison
%                                 de dominance. Par defaut ([] ou omis) :
%                                 toutes les phases actives (equivalent a
%                                 [phase_model.use]). Doit etre un
%                                 sous-ensemble des phases actives.
%     display_figures            : booleen
%
%   SORTIES
%     phase_map : structure [n_y x n_x] :
%                   .keep                    : booleen, pixel garde ?
%                   .n_points_above_noise     : diagnostic
%                   .label                    : code entier --
%                       0            = exclu (filtre R2/bruit)
%                       1..n_phases  = index de la phase dominante
%                       n_phases+1   = garde, mais toutes amplitudes <= 0
%                                     (parmi dominance_phases)
%                       n_phases+2   = ambigu (2 plus grandes amplitudes
%                                     trop proches, cf. alpha_dominance)
%     composition_map : [n_y x n_x x n_phases], fraction de chaque phase
%                       active parmi les amplitudes positives (somme = 1
%                       sur TOUTES les phases actives a amplitude > 0,
%                       NaN si exclu -- independant de dominance_phases)

if nargin < 9  || isempty(dominance_phases), dominance_phases = [phase_model.use]; end
if nargin < 10 || isempty(display_figures),  display_figures = true;              end

%% ================================================================
% 0. Mise en forme / verifications

if ndims(I_corr) == 4
    I_corr = squeeze(I_corr);
end

[n_y, n_x, ~] = size(I_corr);
assert(isequal(size(pixel_fit), [n_y n_x]), 'pixel_fit doit avoir la taille [n_y x n_x].');
assert(isequal(size(noise_map), [n_y n_x]), 'noise_map doit avoir la taille [n_y x n_x].');

n_phases   = numel(phase_model);
active_idx = find([phase_model.use]);

assert(numel(dominance_phases) == n_phases, ...
    'dominance_phases doit avoir %d elements (comme phase_model).', n_phases);
assert(all(~dominance_phases(:)' | [phase_model.use]), ...
    'dominance_phases ne peut pas inclure une phase desactivee (phase_model(k).use = false).');

dominance_idx = find(dominance_phases);

label_none      = n_phases + 1;
label_ambiguous = n_phases + 2;

%% ================================================================
% 1. Boucle pixels : filtrage + segmentation

keep_map      = false(n_y, n_x);
n_above_map   = zeros(n_y, n_x);
label_map     = zeros(n_y, n_x);
composition_map = nan(n_y, n_x, n_phases);

for iy = 1:n_y
    for ix = 1:n_x

        I_pixel = squeeze(I_corr(iy,ix,:));
        n_above = sum(I_pixel > threshold_sigma_noise*noise_map(iy,ix));
        n_above_map(iy,ix) = n_above;

        keep = (pixel_fit(iy,ix).R2 >= R2_min) && (n_above >= min_points_above_noise);
        keep_map(iy,ix) = keep;

        if ~keep
            label_map(iy,ix) = 0;
            continue
        end

        A_dom = pixel_fit(iy,ix).A(dominance_idx);

        if all(A_dom <= 0)
            label_map(iy,ix) = label_none;
            composition_map(iy,ix,:) = 0;
            continue
        end

        [A_sorted, order] = sort(A_dom, 'descend');
        if numel(A_sorted) > 1 && ~(A_sorted(1) > alpha_dominance*A_sorted(2))
            label_map(iy,ix) = label_ambiguous;
        else
            label_map(iy,ix) = dominance_idx(order(1));
        end

        A_active = pixel_fit(iy,ix).A(active_idx);
        A_pos = max(A_active, 0);
        frac_full = zeros(n_phases,1);
        frac_full(active_idx) = A_pos / sum(A_pos);
        composition_map(iy,ix,:) = frac_full;
    end
end

phase_map.keep                = keep_map;
phase_map.n_points_above_noise = n_above_map;
phase_map.label                = label_map;

%% ================================================================
% 2. Affichage
%% ================================================================

if display_figures
    plotSegmentation(phase_map, composition_map, phase_model, active_idx, label_ambiguous);
end

end


%% ====================================================================
%  FONCTION LOCALE
%% ====================================================================

function plotSegmentation(phase_map, composition_map, phase_model, active_idx, label_ambiguous)
% Carte de segmentation (categorielle) + une carte de fraction par phase
% active.

    n_active = numel(active_idx);
    n_maps   = 1 + n_active;
    n_cols   = ceil(sqrt(n_maps));
    n_rows   = ceil(n_maps/n_cols);

    figure('Color','white','Position',[100 100 1300 850]);

    subplot(n_rows, n_cols, 1);
    imagesc(phase_map.label); axis image; colorbar;
    clim([0, label_ambiguous]);
    title('Segmentation (phase dominante)', 'FontSize', 11);
    % 0 = exclu, 1..n_phases = phase, n_phases+1 = aucune amplitude > 0, label_ambiguous = ambigu

    for a = 1:n_active
        k = active_idx(a);
        subplot(n_rows, n_cols, 1+a);
        imagesc(composition_map(:,:,k)); axis image; colorbar;
        clim([0 1]);
        title(sprintf('Fraction : %s', phase_model(k).name), 'FontSize', 11);
    end

end
