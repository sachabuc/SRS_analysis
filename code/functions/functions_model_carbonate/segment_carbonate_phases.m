function [phase_map, composition_map] = segment_carbonate_phases( ...
          I_corr, pixel_fit, phase_model, noise_map, ...
          R2_min, threshold_sigma_noise, min_points_above_noise, ...
          alpha_dominance, dominance_phases, ...
          priority_phases, priority_min_fraction, display_figures)
%SEGMENT_CARBONATE_PHASES Filtre les pixels peu fiables et construit la
%carte de phase dominante + composition, a partir du fit non-lineaire.
%
%   [phase_map, composition_map] = SEGMENT_CARBONATE_PHASES(I_corr, ...
%       pixel_fit, phase_model, noise_map, R2_min, ...
%       threshold_sigma_noise, min_points_above_noise, alpha_dominance, ...
%       dominance_phases, priority_phases, priority_min_fraction, ...
%       display_figures)
%
%   FILTRAGE (deux criteres independants, un pixel doit passer les deux)
%     - R2 >= R2_min                (qualite du fit non-lineaire)
%     - nb de points du spectre au-dessus de threshold_sigma_noise x
%       noise_map(pixel) >= min_points_above_noise (presence d'un vrai
%       signal, independant de la qualite du fit)
%
%   SEGMENTATION (pixels gardes uniquement) -- DEUX ETAPES, DANS L'ORDRE
%
%   1) CRITERE PRIORITAIRE (nouveau) -- pense pour detecter une phase
%      faible (ex : ACC) meme quand une autre phase est plus forte sur
%      le meme pixel (ex : calcite). Pour chaque phase k avec
%      priority_phases(k) = true : si sa fraction de composition
%      depasse priority_min_fraction(k), le pixel lui est attribue
%      DIRECTEMENT, sans meme regarder l'etape 2. Si plusieurs phases
%      prioritaires depassent leur seuil sur le meme pixel, celle avec
%      la plus grande fraction l'emporte.
%
%   2) CRITERE D'ORIGINE (dominance/alpha) -- applique seulement si
%      aucune phase prioritaire n'a declenche l'etape 1. Le gagnant
%      "brut" est la plus grande amplitude parmi TOUTES les phases
%      actives. dominance_phases determine si ce gagnant doit encore
%      PROUVER sa dominance avant d'etre valide :
%        - dominance_phases(gagnant) = true  : le gagnant doit depasser
%          la 2e plus grande amplitude d'un facteur alpha_dominance
%          (A_sorted(1) > alpha_dominance * A_sorted(2)), sinon le pixel
%          est classe AMBIGU
%        - dominance_phases(gagnant) = false : le gagnant est valide des
%          qu'il est le plus grand, sans marge a passer
%
%   ENTREES
%     I_corr                  : cube hyperspectral [n_y x n_x x n_wn]
%     pixel_fit                : structure issue de FIT_PIXEL_PHASES
%     phase_model               : structure issue de MODEL_CARBONATE_PHASES
%     noise_map                 : [n_y x n_x], reference de bruit par
%                                 pixel
%     R2_min                    : R^2 minimal pour garder le pixel
%     threshold_sigma_noise      : facteur x noise_map pour compter un
%                                 point comme "au-dessus du bruit"
%     min_points_above_noise     : nb minimal de points au-dessus du
%                                 bruit pour garder le pixel
%     alpha_dominance             : facteur multiplicatif requis pour que
%                                 la plus grande amplitude l'emporte sur
%                                 la deuxieme, a l'etape 2 (1 <=> argmax
%                                 simple ; > 1 <=> il faut une avance
%                                 plus nette)
%     dominance_phases            : vecteur logique [1 x n_phases] --
%                                 true = cette phase doit passer le test
%                                 alpha_dominance a l'etape 2 pour etre
%                                 validee comme dominante. Par defaut
%                                 ([] ou omis) : toutes les phases
%                                 actives (equivalent a [phase_model.use]).
%     priority_phases              : vecteur logique [1 x n_phases] --
%                                 true = cette phase beneficie du
%                                 court-circuit de l'etape 1. Par defaut
%                                 ([] ou omis) : aucune (false partout,
%                                 comportement identique a avant l'ajout
%                                 de ce critere).
%     priority_min_fraction        : vecteur numerique [1 x n_phases],
%                                 fraction minimale de composition
%                                 (entre 0 et 1) requise a l'etape 1 pour
%                                 la phase k. Ignore si
%                                 priority_phases(k) = false. Par defaut
%                                 ([] ou omis) : 0 partout.
%     display_figures            : booleen
%
%   SORTIES
%     phase_map : structure [n_y x n_x] :
%                   .keep                    : booleen, pixel garde ?
%                   .n_points_above_noise     : diagnostic
%                   .label                    : code entier --
%                       0            = exclu (filtre R2/bruit)
%                       1..n_phases  = index de la phase label
%                       n_phases+1   = garde, mais toutes amplitudes <= 0
%                       n_phases+2   = ambigu (etape 2 seulement)
%     composition_map : [n_y x n_x x n_phases], fraction de chaque phase
%                       active parmi les amplitudes positives (somme = 1
%                       sur TOUTES les phases actives a amplitude > 0,
%                       NaN si exclu)

n_phases = numel(phase_model);

if nargin < 9  || isempty(dominance_phases),      dominance_phases = [phase_model.use];   end
if nargin < 10 || isempty(priority_phases),       priority_phases = false(1, n_phases);   end
if nargin < 11 || isempty(priority_min_fraction), priority_min_fraction = zeros(1, n_phases); end
if nargin < 12 || isempty(display_figures),       display_figures = true;                 end

%% ================================================================
% 0. Mise en forme / verifications

if ndims(I_corr) == 4
    I_corr = squeeze(I_corr);
end

[n_y, n_x, ~] = size(I_corr);
assert(isequal(size(pixel_fit), [n_y n_x]), 'pixel_fit doit avoir la taille [n_y x n_x].');
assert(isequal(size(noise_map), [n_y n_x]), 'noise_map doit avoir la taille [n_y x n_x].');

active_idx = find([phase_model.use]);

assert(numel(dominance_phases) == n_phases, ...
    'dominance_phases doit avoir %d elements (comme phase_model).', n_phases);
assert(all(~dominance_phases(:)' | [phase_model.use]), ...
    'dominance_phases ne peut pas inclure une phase desactivee (phase_model(k).use = false).');
assert(numel(priority_phases) == n_phases, ...
    'priority_phases doit avoir %d elements (comme phase_model).', n_phases);
assert(numel(priority_min_fraction) == n_phases, ...
    'priority_min_fraction doit avoir %d elements (comme phase_model).', n_phases);
assert(all(~priority_phases(:)' | [phase_model.use]), ...
    'priority_phases ne peut pas inclure une phase desactivee (phase_model(k).use = false).');
assert(all(priority_min_fraction >= 0 & priority_min_fraction <= 1), ...
    'priority_min_fraction doit etre compris entre 0 et 1.');

priority_phases = priority_phases(:);
priority_min_fraction = priority_min_fraction(:);

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

        A_active = pixel_fit(iy,ix).A(active_idx);

        if all(A_active <= 0)
            label_map(iy,ix) = label_none;
            composition_map(iy,ix,:) = 0;
            continue
        end

        A_pos = max(A_active, 0);
        frac_full = zeros(n_phases,1);
        frac_full(active_idx) = A_pos / sum(A_pos);
        composition_map(iy,ix,:) = frac_full;

        % --- Etape 1 : critere prioritaire (phase faible favorisee) ---
        priority_eligible = priority_phases & (frac_full >= priority_min_fraction);
        if any(priority_eligible)
            frac_candidates = frac_full;
            frac_candidates(~priority_eligible) = -Inf;
            [~, k_priority] = max(frac_candidates);
            label_map(iy,ix) = k_priority;
            continue
        end

        % --- Etape 2 : critere d'origine (dominance/alpha) ---
        [A_sorted, order] = sort(A_active, 'descend');
        winner = active_idx(order(1));

        needs_test = dominance_phases(winner);
        fails_test = numel(A_sorted) > 1 && ~(A_sorted(1) > alpha_dominance*A_sorted(2));

        if needs_test && fails_test
            label_map(iy,ix) = label_ambiguous;
        else
            label_map(iy,ix) = winner;
        end
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
    title('Segmentation (label)', 'FontSize', 11);
    % 0 = exclu, 1..n_phases = phase, n_phases+1 = aucune amplitude > 0, label_ambiguous = ambigu

    for a = 1:n_active
        k = active_idx(a);
        subplot(n_rows, n_cols, 1+a);
        imagesc(composition_map(:,:,k)); axis image; colorbar;
        clim([0 1]);
        title(sprintf('Fraction : %s', phase_model(k).name), 'FontSize', 11);
    end

end
