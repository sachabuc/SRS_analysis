function ref_spectra = plot_phase_reference_spectra( ...
          I_corr, wavenumber, pixel_fit, phase_map, phase_model, ...
          phase_idx, n_top, fwhm_instr, show_theoretical, save_path, ...
          methode, priority_phases, background_image, n_theoretical_points)
%PLOT_PHASE_REFERENCE_SPECTRA Spectre moyen (top-N par R^2 ou par
%amplitude) pour chaque phase demandee, avec superposition optionnelle
%du modele theorique, et enregistrement des parametres de fit pour
%reutilisation (ex : comparer les memes pixels sur une acquisition a
%fwhm_instr different).
%
%   ref_spectra = PLOT_PHASE_REFERENCE_SPECTRA(I_corr, wavenumber, ...
%       pixel_fit, phase_map, phase_model, phase_idx, n_top, fwhm_instr, ...
%       show_theoretical, save_path, methode, priority_phases, ...
%       background_image, n_theoretical_points)
%
%   Pour chaque phase k = phase_idx(i) : on prend le pool des pixels ou
%   cette phase est le label (phase_map.label == k, donc deja filtres
%   R2/bruit par SEGMENT_CARBONATE_PHASES), on trie ce pool, et on garde
%   les n_top(i) meilleurs -- moins si le pool est plus petit. CRITERE DE
%   TRI (nouveau) :
%     - methode = 'R2' (defaut) : tri par R^2 decroissant, comme avant,
%       pour TOUTES les phases (priority_phases est ignore).
%     - methode = 'amplitude' : les phases k ou priority_phases(k) = true
%       sont triees par leur FRACTION DE COMPOSITION decroissante
%       (A(k) / somme des amplitudes positives actives sur ce pixel --
%       la meme quantite que priority_min_fraction dans
%       SEGMENT_CARBONATE_PHASES) plutot que par R^2 -- utile pour une
%       phase faible (ex : ACC) ou l'on veut les pixels ou elle est
%       proportionnellement la plus presente, meme si le R^2 global du
%       pixel n'est pas le meilleur du lot. Les phases avec
%       priority_phases(k) = false continuent d'etre triees par R^2 meme
%       si methode = 'amplitude'.
%   Dans tous les cas, .R2_worst_used est calcule sur les pixels
%   REELLEMENT retenus (donc reste interpretable meme en tri par
%   amplitude).
%   Le spectre moyen (+/- 1 ecart-type) de ces pixels est calcule sur
%   I_corr, et si show_theoretical, compare au modele theorique de la
%   phase (PHASEMODELSPECTRUM), mis a l'echelle par l'amplitude moyenne
%   ajustee sur ces memes pixels.
%
%   ENTREES
%     I_corr            : cube hyperspectral [n_y x n_x x n_wn]
%     wavenumber          : nombres d'onde (cm^-1), pas necessairement
%                         tries (retries ici, I_corr reordonne pareil)
%     pixel_fit           : structure issue de FIT_PIXEL_PHASES
%     phase_map            : structure issue de SEGMENT_CARBONATE_PHASES
%                         (utilise .label)
%     phase_model          : structure issue de MODEL_CARBONATE_PHASES
%     phase_idx            : vecteur d'indices de phases a afficher
%                         (ex : [1 4] pour CAL et ACC)
%     n_top                : vecteur, meme longueur que phase_idx, nombre
%                         de pixels a garder par phase (ex : [100 300])
%     fwhm_instr             : FWHM (ps) de la reponse instrumentale de
%                         cette acquisition -- stocke tel quel dans
%                         ref_spectra, pour tracer les resultats de
%                         plusieurs acquisitions les unes contre les
%                         autres ensuite
%     show_theoretical      : booleen, superpose le modele theorique
%                         (defaut true)
%     save_path             : chemin .mat pour sauvegarder ref_spectra
%                         (ex : 'ref_spectra_tau2ps.mat'), ou '' pour ne
%                         pas sauvegarder (defaut '')
%     methode                : 'R2' (defaut) ou 'amplitude', cf. ci-dessus
%     priority_phases          : vecteur logique [1 x n_phases], meme
%                         convention que dans SEGMENT_CARBONATE_PHASES --
%                         quelles phases beneficient du tri par amplitude
%                         quand methode = 'amplitude'. Ignore si
%                         methode = 'R2'. Par defaut ([] ou omis) :
%                         aucune (false partout).
%     background_image        : image [n_y x n_x] en niveaux de gris de
%                         l'echantillon (ex : sum(I_corr,3)), utilisee
%                         comme fond pour la carte des pixels
%                         selectionnes (combined_pixel_image). Si [] ou
%                         omis, cette figure est simplement ignoree.
%     n_theoretical_points      : nombre de points de la grille fine
%                         utilisee pour tracer le modele theorique
%                         (independante de la grille de mesure, qui reste
%                         a n_wn points) -- defaut 500.
%
%   SORTIE
%     ref_spectra : structure, une entree par phase demandee :
%                     .phase_idx, .name, .fwhm_instr
%                     .selection_method        ('R2' ou 'amplitude',
%                                              methode reellement
%                                              appliquee a cette phase)
%                     .n_requested, .n_used   (n_used < n_requested si
%                                              le pool etait plus petit)
%                     .R2_worst_used           (R^2 le plus bas PARMI les
%                                              pixels retenus, quel que
%                                              soit le critere de tri)
%                     .mean_spectrum, .std_spectrum  (sur wavenumber, la
%                                              grille de mesure)
%                     .wavenumber_theoretical, .theoretical_spectrum
%                                              (grille FINE independante,
%                                              n_theoretical_points points ;
%                                              theoretical_spectrum = NaN
%                                              si show_theoretical=false)
%                     .pixel_linear_idx, .row, .col  (identite des pixels
%                                              gardes, pour les retrouver
%                                              sur une autre acquisition)
%                     .A_values   [n_used x n_phases] -- amplitude de
%                                 CHAQUE phase, a CHAQUE pixel garde
%                     .A_mean, .A_std          [1 x n_phases]
%                     .nu_target_values, .FWHM_target_values
%                                 [n_used x n_raies] -- position/largeur
%                                 ajustees (ou fixees) de la phase k
%                                 uniquement, a chaque pixel garde
%                     .nu_target_mean/.std, .FWHM_target_mean/.std
%                     .background_values, .background_mean/.std
 
if nargin < 9  || isempty(show_theoretical),     show_theoretical = true; end
if nargin < 10 || isempty(save_path),            save_path = '';          end
if nargin < 11 || isempty(methode),              methode = 'R2';          end
if nargin < 12 || isempty(priority_phases),      priority_phases = false(1, numel(phase_model)); end
if nargin < 13,                                  background_image = [];   end
if nargin < 14 || isempty(n_theoretical_points), n_theoretical_points = 500; end
 
assert(numel(phase_idx) == numel(n_top), 'phase_idx et n_top doivent avoir la meme longueur.');
assert(any(strcmpi(methode, {'R2','amplitude'})), ...
    'methode doit valoir ''R2'' ou ''amplitude'' (recu : %s).', methode);
assert(numel(priority_phases) == numel(phase_model), ...
    'priority_phases doit avoir %d elements (comme phase_model).', numel(phase_model));
 
%% ================================================================
% 1. Mise en forme
 
if ndims(I_corr) == 4
    I_corr = squeeze(I_corr);
end
 
[wavenumber, sort_idx] = sort(wavenumber(:).');
I_corr = I_corr(:,:,sort_idx);
 
[n_y, n_x, n_wn] = size(I_corr);
assert(isequal(size(phase_map.label), [n_y n_x]), ...
    'phase_map.label doit avoir la taille [n_y x n_x] de I_corr.');
 
I_flat = reshape(permute(I_corr, [3 1 2]), n_wn, n_y*n_x).';   % [n_pixels x n_wn]
 
wavenumber_theo = linspace(min(wavenumber), max(wavenumber), n_theoretical_points);
 
%% ================================================================
% 2. Selection top-N par R^2, pour chaque phase demandee
 
n_req = numel(phase_idx);
n_phases = numel(phase_model);
ref_spectra(n_req).phase_idx = [];   % preallocation implicite
 
for i = 1:n_req
    k = phase_idx(i);
 
    pool = find(phase_map.label == k);

    
    ref_spectra(i).phase_idx   = k;
    ref_spectra(i).name        = phase_model(k).name;
    ref_spectra(i).n_requested = n_top(i);
    ref_spectra(i).fwhm_instr    = fwhm_instr;
    ref_spectra(i).wavenumber  = wavenumber;
 
    if isempty(pool)
        warning('plot_phase_reference_spectra:emptyPool', ...
            'Aucun pixel avec la phase %s comme dominante -- ignoree.', phase_model(k).name);
                      
        ref_spectra(i).n_used               = 0;
        ref_spectra(i).R2_worst_used         = NaN;
        ref_spectra(i).mean_spectrum         = nan(1, n_wn);
        ref_spectra(i).std_spectrum          = nan(1, n_wn);
        ref_spectra(i).wavenumber_theoretical = wavenumber_theo;
        ref_spectra(i).theoretical_spectrum  = nan(1, n_theoretical_points);
        ref_spectra(i).pixel_linear_idx       = [];
        ref_spectra(i).row                    = [];
        ref_spectra(i).col                    = [];
        ref_spectra(i).A_values               = [];
        ref_spectra(i).A_mean                 = nan(1, n_phases);
        ref_spectra(i).A_std                  = nan(1, n_phases);
        ref_spectra(i).nu_target_values        = [];
        ref_spectra(i).nu_target_mean          = [];
        ref_spectra(i).nu_target_std           = [];
        ref_spectra(i).FWHM_target_values      = [];
        ref_spectra(i).FWHM_target_mean        = [];
        ref_spectra(i).FWHM_target_std         = [];
        ref_spectra(i).background_values       = [];
        ref_spectra(i).background_mean         = NaN;
        ref_spectra(i).background_std          = NaN;
        ref_spectra(i).n_pool                  = 0;
        ref_spectra(i).selection_method         = '';
        continue
    end
 
    R2_pool = arrayfun(@(s) s.R2, pixel_fit(pool));
 
    use_amplitude_ranking = strcmpi(methode, 'amplitude') && priority_phases(k);
 
    if use_amplitude_ranking
        active_idx_local = find([phase_model.use]);
        frac_pool = arrayfun(@(s) fractionForPhase(s, active_idx_local, k), pixel_fit(pool));
        [~, order] = sort(frac_pool, 'descend');
        selection_method_used = 'amplitude';
    else
        [~, order] = sort(R2_pool, 'descend');
        selection_method_used = 'R2';
    end
 
    n_use = min(n_top(i), numel(pool));
    sel   = pool(order(1:n_use));
    R2_sel = R2_pool(order(1:n_use));
 
    spectra_sel = I_flat(sel, :);
    mean_spec   = mean(spectra_sel, 1);
    std_spec    = std(spectra_sel, 1);
 
    % --- Parametres de fit pour les pixels selectionnes -----------------
    A_matrix = reshape([pixel_fit(sel).A], n_phases, n_use).';   % [n_use x n_phases]
 
    nu_cells   = arrayfun(@(s) s.nu{k},   pixel_fit(sel), 'UniformOutput', false);
    FWHM_cells = arrayfun(@(s) s.FWHM{k}, pixel_fit(sel), 'UniformOutput', false);
    nu_target   = cell2mat(nu_cells(:));     % [n_use x n_raies de la phase k]
    FWHM_target = cell2mat(FWHM_cells(:));   % [n_use x n_raies de la phase k]
 
    background_values = arrayfun(@(s) s.background, pixel_fit(sel)).';   % [n_use x 1]
 
    [row_sel, col_sel] = ind2sub([n_y n_x], sel);
 
    if show_theoretical
        theo_spec = mean(A_matrix(:,k)) * phaseModelSpectrum(phase_model(k), wavenumber_theo) ...
                    + mean(background_values);
    else
        theo_spec = nan(1, n_theoretical_points);
    end
 
    ref_spectra(i).n_used                   = n_use;
    ref_spectra(i).R2_worst_used            = min(R2_sel);
    ref_spectra(i).selection_method         = selection_method_used;
    ref_spectra(i).mean_spectrum            = mean_spec;
    ref_spectra(i).std_spectrum             = std_spec;
    ref_spectra(i).wavenumber_theoretical   = wavenumber_theo;
    ref_spectra(i).theoretical_spectrum     = theo_spec;
    ref_spectra(i).pixel_linear_idx         = sel;
    ref_spectra(i).row                      = row_sel(:);
    ref_spectra(i).col                      = col_sel(:);
    ref_spectra(i).A_values                 = A_matrix;
    ref_spectra(i).A_mean                   = mean(A_matrix, 1);
    ref_spectra(i).A_std                    = std(A_matrix, 0, 1);
    ref_spectra(i).nu_target_values         = nu_target;
    ref_spectra(i).nu_target_mean           = mean(nu_target, 1);
    ref_spectra(i).nu_target_std            = std(nu_target, 0, 1);
    ref_spectra(i).FWHM_target_values       = FWHM_target;
    ref_spectra(i).FWHM_target_mean         = mean(FWHM_target, 1);
    ref_spectra(i).FWHM_target_std          = std(FWHM_target, 0, 1);
    ref_spectra(i).background_values        = background_values;
    ref_spectra(i).background_mean          = mean(background_values);
    ref_spectra(i).background_std           = std(background_values);
    ref_spectra(i).n_pool                   = numel(pool);
 
    if n_use < n_top(i)
        warning('plot_phase_reference_spectra:poolTooSmall', ...
            'Phase %s : seulement %d pixels disponibles (demande : %d).', ...
            phase_model(k).name, n_use, n_top(i));
    end
end
 
%% ================================================================
% 3. Affichage
 
plotReferenceSpectra(ref_spectra, wavenumber, show_theoretical);
 
if ~isempty(background_image)
    plotCombinedPixelImage(ref_spectra, background_image);
else
    warning('plot_phase_reference_spectra:noBackgroundImage', ...
        'background_image non fourni -- carte des pixels selectionnes (combined_pixel_image) non affichee.');
end
 
%% ================================================================
% 4. Sauvegarde (optionnelle)
 
if ~isempty(save_path)
    save(save_path, 'ref_spectra');
    fprintf('ref_spectra sauvegarde dans %s\n', save_path);
end
 
end
 
 
%% ====================================================================
%  FONCTION LOCALE
%% ====================================================================
 
function frac = fractionForPhase(pf, active_idx, k)
% Fraction de composition de la phase k sur ce pixel -- meme quantite
% que priority_min_fraction dans SEGMENT_CARBONATE_PHASES (amplitudes
% positives des phases actives, normalisees par leur somme).
    A_active = pf.A(active_idx);
    A_pos = max(A_active, 0);
    total = sum(A_pos);
    if total <= 0
        frac = 0;
    else
        frac = max(pf.A(k), 0) / total;
    end
end
 
 
function plotCombinedPixelImage(ref_spectra, background_image)
% Image en niveaux de gris de l'echantillon (background_image), avec les
% pixels selectionnes par phase superposes en couleur -- une couleur par
% phase, meme ordre/palette que PLOTREFERENCESPECTRA pour rester
% coherent visuellement entre les deux figures.
 
    figure('Color', 'white', 'Position', [100 100 900 800]);
 
    imagesc(background_image); axis image; colormap(gca, gray);
    hold on;
 
    colors = lines(numel(ref_spectra));
 
    for i = 1:numel(ref_spectra)
        rs = ref_spectra(i);
        if rs.n_used == 0
            continue
        end
        plot(rs.col, rs.row, 'o', 'Color', colors(i,:), ...
             'MarkerFaceColor', colors(i,:), 'MarkerSize', 5, ...
             'DisplayName', sprintf('%s (n=%d)', rs.name, rs.n_used));
    end
 
    xlabel('Colonne', 'FontSize', 12);
    ylabel('Ligne', 'FontSize', 12);
    title('Pixels de reference selectionnes, sur image de l''echantillon', 'FontSize', 13);
    legend('Location', 'best');
    hold off;
 
end

function plotReferenceSpectra(ref_spectra, wavenumber, show_theoretical)
% Spectre moyen +/- 1 ecart-type par phase demandee, superpose au modele
% theorique si disponible.
 
    figure('Color','white','Position',[100 100 1000 700]);
    hold on;
 
    colors = lines(numel(ref_spectra));
 
    for i = 1:numel(ref_spectra)
        rs = ref_spectra(i);
        if rs.n_used == 0
            continue
        end
 
        upper = rs.mean_spectrum + rs.std_spectrum;
        lower = rs.mean_spectrum - rs.std_spectrum;
        fill([wavenumber, fliplr(wavenumber)], [upper, fliplr(lower)], ...
             colors(i,:), 'FaceAlpha', 0.15, 'EdgeColor', 'none', ...
             'HandleVisibility', 'off');
 
        plot(wavenumber, rs.mean_spectrum, '-o', 'Color', colors(i,:), ...
             'MarkerFaceColor', colors(i,:), 'MarkerSize', 4, ...
             'LineWidth', 2, 'DisplayName', ...
             sprintf('%s (n=%d, tri=%s, R^2 >= %.3f)', rs.name, rs.n_used, rs.selection_method, rs.R2_worst_used));
 
        if show_theoretical
            plot(rs.wavenumber_theoretical, rs.theoretical_spectrum, '--', 'Color', colors(i,:), ...
                 'LineWidth', 1.5, 'DisplayName', sprintf('%s (theorique)', rs.name));
        end
    end
 
    xlabel('Wavenumber (cm^{-1})', 'FontSize', 12);
    ylabel('Intensity (a.u.)', 'FontSize', 12);
    title('Spectres de reference par phase (top-N par R^2)', 'FontSize', 13);
    legend('Location', 'best');
    grid on; box on; set(gca, 'FontSize', 11);
 
end







