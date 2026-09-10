function ref_spectra = plot_phase_reference_spectra( ...
          I_corr, wavenumber, pixel_fit, phase_map, phase_model, ...
          phase_idx, n_top, fwhm_instr, show_theoretical)
%PLOT_PHASE_REFERENCE_SPECTRA Spectre moyen (top-N par R^2) pour chaque
%phase demandee, avec superposition optionnelle du modele theorique, et
%enregistrement des parametres de fit pour reutilisation (ex : comparer
%les memes pixels sur une acquisition a tau_instrumental different).
%
%   ref_spectra = PLOT_PHASE_REFERENCE_SPECTRA(I_corr, wavenumber, ...
%       pixel_fit, phase_map, phase_model, phase_idx, n_top, fwhm_instr, ...
%       show_theoretical, save_path)
%
%   Pour chaque phase k = phase_idx(i) : on prend le pool des pixels ou
%   cette phase est dominante (phase_map.label == k, donc deja filtres
%   R2/bruit par SEGMENT_CARBONATE_PHASES), on trie ce pool par R^2
%   decroissant (pixel_fit.R2, celui du fit non-lineaire complet), et on
%   garde les n_top(i) meilleurs -- moins si le pool est plus petit. Le
%   spectre moyen (+/- 1 ecart-type) de ces pixels est calcule sur
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
%
%   SORTIE
%     ref_spectra : structure, une entree par phase demandee :
%                     .phase_idx, .name, .fwhm_instr
%                     .n_requested, .n_used   (n_used < n_requested si
%                                              le pool etait plus petit)
%                     .R2_worst_used           (seuil R^2 effectif)
%                     .mean_spectrum, .std_spectrum
%                     .theoretical_spectrum    (NaN si show_theoretical=false)
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

if nargin < 9  || isempty(show_theoretical), show_theoretical = true; end
if nargin < 10 || isempty(save_path),        save_path = '';          end

assert(numel(phase_idx) == numel(n_top), 'phase_idx et n_top doivent avoir la meme longueur.');

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

%% ================================================================
% 2. Selection top-N par R^2, pour chaque phase demandee

n_req = numel(phase_idx);
n_phases = numel(phase_model);
ref_spectra(n_req).phase_idx = [];   % preallocation implicite

% Initialiser une image vide pour stocker les pixels sélectionnés
combined_pixel_image = zeros(size(phase_map.label));

for i = 1:n_req
    k = phase_idx(i);

    pool = find(phase_map.label == k);

    ref_spectra(i).phase_idx   = k;
    ref_spectra(i).name        = phase_model(k).name;
    ref_spectra(i).n_requested = n_top(i);
    ref_spectra(i).fwhm_instr    = fwhm_instr;

    if isempty(pool)
        warning('plot_phase_reference_spectra:emptyPool', ...
            'Aucun pixel avec la phase %s comme dominante -- ignoree.', phase_model(k).name);
        ref_spectra(i).n_used               = 0;
        ref_spectra(i).R2_worst_used         = NaN;
        ref_spectra(i).sum_spectrum         = nan(1, n_wn);
        ref_spectra(i).mean_spectrum         = nan(1, n_wn);
        ref_spectra(i).std_spectrum          = nan(1, n_wn);
        ref_spectra(i).theoretical_spectrum  = nan(1, n_wn);
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
        continue
    end

    R2_pool = arrayfun(@(s) s.R2, pixel_fit(pool));
    [R2_sorted, order] = sort(R2_pool, 'descend');

    n_use = min(n_top(i), numel(pool));
    sel   = pool(order(1:n_use));

    % Marquer les pixels sélectionnés pour cette phase avec l'indice i
    combined_pixel_image(sel) = i;

    spectra_sel = I_flat(sel, :);
    sum_spec    = sum(spectra_sel, 1);
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
    
        A_sel   = arrayfun(@(s) s.A(k), pixel_fit(sel));
        bck_sel = arrayfun(@(s) s.background, pixel_fit(sel));
    
        % Grille dense uniquement pour le modele theorique
        wavenumber_dense = linspace(min(wavenumber), max(wavenumber), 2000);
    
        % Calcul direct du modele sur la grille dense
        theo_spec = mean(A_sel) * ...
                    phaseModelSpectrum(phase_model(k), wavenumber_dense) ...
                    + mean(bck_sel);
    
    else
        wavenumber_dense = [];
        theo_spec = nan(1, n_wn);
    end

    ref_spectra(i).n_used                = n_use;
    ref_spectra(i).R2_worst_used          = R2_sorted(n_use);
    ref_spectra(i).wavenumber_theoretical = wavenumber_dense;
    ref_spectra(i).sum_spectrum           = sum_spec;
    ref_spectra(i).mean_spectrum          = mean_spec;
    ref_spectra(i).std_spectrum           = std_spec;
    ref_spectra(i).theoretical_spectrum   = theo_spec;
    ref_spectra(i).pixel_linear_idx        = sel;
    ref_spectra(i).row                     = row_sel(:);
    ref_spectra(i).col                     = col_sel(:);
    ref_spectra(i).A_values                = A_matrix;
    ref_spectra(i).A_mean                  = mean(A_matrix, 1);
    ref_spectra(i).A_std                   = std(A_matrix, 0, 1);
    ref_spectra(i).nu_target_values         = nu_target;
    ref_spectra(i).nu_target_mean           = mean(nu_target, 1);
    ref_spectra(i).nu_target_std            = std(nu_target, 0, 1);
    ref_spectra(i).FWHM_target_values       = FWHM_target;
    ref_spectra(i).FWHM_target_mean         = mean(FWHM_target, 1);
    ref_spectra(i).FWHM_target_std          = std(FWHM_target, 0, 1);
    ref_spectra(i).background_values        = background_values;
    ref_spectra(i).background_mean          = mean(background_values);
    ref_spectra(i).background_std           = std(background_values);
    ref_spectra(i).n_pool                    = numel(pool);

    if n_use < n_top(i)
        warning('plot_phase_reference_spectra:poolTooSmall', ...
            'Phase %s : seulement %d pixels disponibles (demande : %d).', ...
            phase_model(k).name, n_use, n_top(i));
    end
end

%% ================================================================
% 3. Affichage

plotReferenceSpectra(ref_spectra, wavenumber, show_theoretical);


% 4. Affichage de la carte des pixels utilisés
figure('Name', 'Carte des pixels sélectionnés par phase', 'Position', [100, 100, 800, 600]);
imagesc(combined_pixel_image);
axis image;
colormap;
colorbar('Ticks', 1:n_req, 'TickLabels', {phase_model(phase_idx).name});
title('Carte des pixels sélectionnés par phase');

end

