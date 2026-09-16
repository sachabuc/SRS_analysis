function presence_map = plot_phase_presence_map( ...
          pixel_fit, phase_map, phase_model, phase_idx, ...
          detection_method, threshold_A, display_figures)
%PLOT_PHASE_PRESENCE_MAP Carte de presence d'UNE phase d'interet, meme
%quand elle n'est pas dominante -- utile pour une phase attendue en
%faible quantite (ex : ACC), invisible dans SEGMENT_CARBONATE_PHASES qui
%ne montre que la phase dominante par pixel.
%
%   presence_map = PLOT_PHASE_PRESENCE_MAP(pixel_fit, phase_map, ...
%       phase_model, phase_idx, detection_method, threshold_A, ...
%       display_figures)
%
%   Categories (un code entier par pixel) :
%     0 = exclu (phase_map.keep = false, meme filtre R2/bruit que la
%         segmentation standard -- on ne pretend pas detecter une phase
%         sur un pixel deja juge peu fiable)
%     1 = phase absente (non detectee, cf. detection_method)
%     2 = phase PRESENTE mais PAS dominante -- exactement les pixels que
%         SEGMENT_CARBONATE_PHASES cache derriere une autre phase
%     3 = phase dominante (deja visible dans phase_map.label)
%
%   ENTREES
%     pixel_fit         : structure issue de FIT_PIXEL_PHASES
%     phase_map          : structure issue de SEGMENT_CARBONATE_PHASES
%                         (utilise .keep .label)
%     phase_model         : structure issue de MODEL_CARBONATE_PHASES
%     phase_idx           : index de LA phase d'interet (scalaire, ex :
%                         l'index d'ACC dans phase_model)
%     detection_method      : 'significance' (defaut) utilise
%                         pixel_fit.A_significant(phase_idx) -- legitime
%                         ici car on teste juste "A different de 0", pas
%                         une comparaison entre phases (contrairement a
%                         SEGMENT_CARBONATE_PHASES, ou ce test s'etait
%                         avere trop restrictif pour trancher une
%                         dominance) -- ou 'threshold', qui compare
%                         directement A(phase_idx) a threshold_A
%     threshold_A          : seuil absolu si detection_method='threshold'
%                         (ignore sinon)
%     display_figures       : booleen (defaut true)
%
%   SORTIE
%     presence_map : structure :
%                      .category  [n_y x n_x], code 0-3 ci-dessus
%                      .A         [n_y x n_x], amplitude brute de la
%                                 phase (NaN si exclu)
 
if nargin < 5 || isempty(detection_method), detection_method = 'significance'; end
if nargin < 7 || isempty(display_figures),   display_figures = true;           end
 
[n_y, n_x] = size(phase_map.label);
 
%% ================================================================
% 1. Amplitude et detection, vectorise (pas de boucle pixel)
 
A_map = reshape(arrayfun(@(s) s.A(phase_idx), pixel_fit), n_y, n_x);
 
switch detection_method
    case 'significance'
        detected_map = reshape(arrayfun(@(s) s.A_significant(phase_idx), pixel_fit), n_y, n_x);
    case 'threshold'
        detected_map = A_map > threshold_A;
    otherwise
        error('plot_phase_presence_map:unknownMethod', ...
            'detection_method inconnu : %s (attendu ''significance'' ou ''threshold'')', detection_method);
end
 
%% ================================================================
% 2. Categorisation
 
category = zeros(n_y, n_x);
category(phase_map.keep & ~detected_map)                            = 1;
category(phase_map.keep &  detected_map & phase_map.label ~= phase_idx) = 2;
category(phase_map.keep &  detected_map & phase_map.label == phase_idx) = 3;
 
A_map(~phase_map.keep) = NaN;
 
presence_map.category = category;
presence_map.A        = A_map;
 
%% ================================================================
% 3. Affichage
 
if display_figures
    plotPresenceMap(category, A_map, phase_model(phase_idx).name);
end
 
end
 
 
%% ====================================================================
%  FONCTION LOCALE
%% ====================================================================
 
function plotPresenceMap(category, A_map, phase_name)
 
    figure('Color', 'white', 'Position', [100 100 1100 500]);
 
    subplot(1,2,1);
    imagesc(category); axis image; colorbar;
    clim([0 3]);
    title(sprintf('Presence de %s\n(0=exclu, 1=absent, 2=present non-dominant, 3=dominant)', ...
          phase_name), 'FontSize', 10);
 
    subplot(1,2,2);
    imagesc(A_map); axis image; colorbar;
    title(sprintf('Amplitude brute : %s', phase_name), 'FontSize', 11);
 
end