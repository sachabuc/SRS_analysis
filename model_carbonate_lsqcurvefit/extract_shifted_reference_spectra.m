
function ref_spectra_shifted = extract_shifted_reference_spectra( ...
          ref_spectra, wavenumber_2ps,I_corr_B, wavenumber_B, ...
          phase_model, shift_row, shift_col, fwhm_inst_B, pixel_fit_B, ...
          show_theoretical, display_figures)
%EXTRACT_SHIFTED_REFERENCE_SPECTRA Reutilise exactement les pixels
%selectionnes par PLOT_PHASE_REFERENCE_SPECTRA sur une acquisition A,
%decales de (shift_row, shift_col), pour extraire les memes positions
%physiques sur une acquisition B (ex : meme echantillon, tau
%instrumental different).
%
%   ref_spectra_shifted = EXTRACT_SHIFTED_REFERENCE_SPECTRA(ref_spectra, ...
%       I_corr_B, wavenumber_B, phase_model, shift_row, shift_col, ...
%       fwhm_inst_B, pixel_fit_B, show_theoretical, display_figures)
%
%   Pour chaque entree de ref_spectra (une par phase), les coordonnees
%   .row/.col (celles utilisees sur l'acquisition A) sont decalees :
%       row_B = row_A + shift_row
%       col_B = col_A + shift_col
%   Les pixels qui tombent hors de l'image B sont exclus (comptes dans
%   .n_dropped). Le spectre moyen est recalcule sur I_corr_B a ces
%   positions. Si pixel_fit_B est fourni (fit deja fait sur B), les
%   memes champs de parametres que PLOT_PHASE_REFERENCE_SPECTRA sont
%   egalement extraits a ces pixels (PAS re-selectionnes par R^2 -- ce
%   sont les positions imposees par le decalage).
%
%   ENTREES
%     ref_spectra    : struct issue de PLOT_PHASE_REFERENCE_SPECTRA sur
%                     l'acquisition A (utilise .row .col .phase_idx .name
%                     .mean_spectrum)
%     I_corr_B        : cube hyperspectral de l'acquisition B,
%                     [n_y x n_x x n_wn]
%     wavenumber_B     : nombres d'onde (cm^-1) de B (suppose la MEME
%                     grille que celle utilisee pour ref_spectra -- pas
%                     de reinterpolation faite ici)
%     phase_model      : structure issue de MODEL_CARBONATE_PHASES
%     shift_row, shift_col : decalage entier (pixels) entre A et B
%     fwhm_inst_B        : FWHM (ps) de la reponse instrumentale de B,
%                     stocke tel quel pour tracabilite
%     pixel_fit_B       : struct issue de FIT_PIXEL_PHASES sur B, ou []
%                     si vous voulez seulement les spectres bruts (les
%                     champs de parametres seront alors vides/NaN)
%     show_theoretical   : booleen, ignore si pixel_fit_B = []
%                     (defaut true)
%     display_figures    : booleen (defaut true)
%
%   SORTIE
%     ref_spectra_shifted : structure, une entree par phase de
%       ref_spectra, memes champs que PLOT_PHASE_REFERENCE_SPECTRA, plus :
%         .row_original, .col_original  (coordonnees sur A, avant decalage)
%         .n_dropped                    (pixels tombes hors de B)
 
if nargin < 8  || isempty(pixel_fit_B),     pixel_fit_B = [];      end
if nargin < 9  || isempty(show_theoretical), show_theoretical = true; end
if nargin < 10 || isempty(display_figures),  display_figures = true; end
 
use_fit = ~isempty(pixel_fit_B);
if ~use_fit
    show_theoretical = false;
end
 
%% ================================================================
% 1. Mise en forme
 
if ndims(I_corr_B) == 4
    I_corr_B = squeeze(I_corr_B);
end
 
[wavenumber_B, sort_idx] = sort(wavenumber_B(:).');
I_corr_B = I_corr_B(:,:,sort_idx);
 
[n_y_B, n_x_B, n_wn] = size(I_corr_B);
I_flat_B = reshape(permute(I_corr_B, [3 1 2]), n_wn, n_y_B*n_x_B).';   % [n_pixels x n_wn]
 
n_phases = numel(phase_model);
 
if use_fit
    assert(isequal(size(pixel_fit_B), [n_y_B n_x_B]), ...
        'pixel_fit_B doit avoir la taille [n_y x n_x] de I_corr_B.');
end
 
%% ================================================================
% 2. Decalage + extraction, pour chaque phase de ref_spectra
 
n_req = numel(ref_spectra.data);
ref_spectra_shifted(n_req).phase_idx = [];   % preallocation implicite
 
for i = 1:n_req
    k = ref_spectra.data(i).phase_idx;
 
    row_orig = ref_spectra.data(i).row;
    col_orig = ref_spectra.data(i).col;
 
    row_new = row_orig + shift_row;
    col_new = col_orig + shift_col;
 
    valid = row_new >= 1 & row_new <= n_y_B & col_new >= 1 & col_new <= n_x_B;
    n_dropped = sum(~valid);
 
    row_new = row_new(valid);
    col_new = col_new(valid);
 
    ref_spectra_shifted(i).phase_idx     = k;
    ref_spectra_shifted(i).name          = ref_spectra.data(i).name;
    ref_spectra_shifted(i).n_requested           = ref_spectra.data(i).n_requested;
    ref_spectra_shifted(i).tau_fwhm       = fwhm_inst_B;
    ref_spectra_shifted(i).row_original    = row_orig;
    ref_spectra_shifted(i).col_original    = col_orig;
    ref_spectra_shifted(i).n_dropped       = n_dropped;
 
    if isempty(row_new)
        warning('extract_shifted_reference_spectra:noValidPixels', ...
            'Phase %s : tous les pixels decales tombent hors de l''image B.', ref_spectra.data(i).name);
        ref_spectra_shifted(i).n_used              = 0;
        ref_spectra_shifted(i).row                  = [];
        ref_spectra_shifted(i).col                  = [];
        ref_spectra_shifted(i).mean_spectrum         = nan(1, n_wn);
        ref_spectra_shifted(i).std_spectrum          = nan(1, n_wn);
        ref_spectra_shifted(i).theoretical_spectrum  = nan(1, n_wn);
        ref_spectra_shifted(i).A_values               = [];
        ref_spectra_shifted(i).A_mean                 = nan(1, n_phases);
        ref_spectra_shifted(i).A_std                  = nan(1, n_phases);
        ref_spectra_shifted(i).nu_target_values        = [];
        ref_spectra_shifted(i).nu_target_mean          = [];
        ref_spectra_shifted(i).nu_target_std           = [];
        ref_spectra_shifted(i).FWHM_target_values      = [];
        ref_spectra_shifted(i).FWHM_target_mean        = [];
        ref_spectra_shifted(i).FWHM_target_std         = [];
        ref_spectra_shifted(i).R2_values               = [];
        ref_spectra_shifted(i).background_values        = [];
        ref_spectra_shifted(i).background_mean         = NaN;
        ref_spectra_shifted(i).background_std          = NaN;
        continue
    end
 
    lin_idx_B = sub2ind([n_y_B n_x_B], row_new, col_new);
 
    spectra_sel = I_flat_B(lin_idx_B, :);
    mean_spec   = mean(spectra_sel, 1);
    std_spec    = std(spectra_sel, 1);
 
    ref_spectra_shifted(i).n_used        = numel(lin_idx_B);
    ref_spectra_shifted(i).row            = row_new(:);
    ref_spectra_shifted(i).col            = col_new(:);
    ref_spectra_shifted(i).mean_spectrum  = mean_spec;
    ref_spectra_shifted(i).std_spectrum   = std_spec;
 
    if use_fit
        A_matrix = reshape([pixel_fit_B(lin_idx_B).A], n_phases, numel(lin_idx_B)).';

        nu_cells   = arrayfun(@(s) s.nu{k},   pixel_fit_B(lin_idx_B), 'UniformOutput', false);
        FWHM_cells = arrayfun(@(s) s.FWHM{k}, pixel_fit_B(lin_idx_B), 'UniformOutput', false);
        nu_target   = cell2mat(nu_cells(:));     % [n_use x n_raies de la phase k]
        FWHM_target = cell2mat(FWHM_cells(:));   % [n_use x n_raies de la phase k]

        background_values = arrayfun(@(s) s.background, pixel_fit_B(lin_idx_B)).';
        R2_values = arrayfun(@(s) s.R2, pixel_fit_B(lin_idx_B)).';
        [R2_sorted, ~] = sort(R2_values, 'descend');
 
        ref_spectra_shifted(i).A_values          = A_matrix;
        ref_spectra_shifted(i).A_mean            = mean(A_matrix, 1);
        ref_spectra_shifted(i).A_std             = std(A_matrix, 0, 1);
        ref_spectra_shifted(i).nu_target_values   = nu_target;
        ref_spectra_shifted(i).nu_target_mean     = mean(nu_target, 1);
        ref_spectra_shifted(i).nu_target_std      = std(nu_target, 0, 1);
        ref_spectra_shifted(i).FWHM_target_values = FWHM_target;
        ref_spectra_shifted(i).FWHM_target_mean   = mean(FWHM_target, 1);
        ref_spectra_shifted(i).FWHM_target_std    = std(FWHM_target, 0, 1);
        ref_spectra_shifted(i).background_values  = background_values;
        ref_spectra_shifted(i).background_mean    = mean(background_values);
        ref_spectra_shifted(i).background_std     = std(background_values);
        ref_spectra_shifted(i).R2_values          = R2_values;
        ref_spectra_shifted(i).R2_worst_used          = R2_sorted(numel(lin_idx_B));
 
        if show_theoretical
            ref_spectra_shifted(i).theoretical_spectrum = ...
                mean(A_matrix(:,k)) * phaseModelSpectrum(phase_model(k), wavenumber_B) ...
                + mean(background_values);
        else
            ref_spectra_shifted(i).theoretical_spectrum = nan(1, n_wn);
        end
    else
        ref_spectra_shifted(i).A_values             = [];
        ref_spectra_shifted(i).A_mean               = nan(1, n_phases);
        ref_spectra_shifted(i).A_std                = nan(1, n_phases);
        ref_spectra_shifted(i).nu_target_values   = [];
        ref_spectra_shifted(i).nu_target_mean     = [];
        ref_spectra_shifted(i).nu_target_std      = [];
        ref_spectra_shifted(i).FWHM_target_values = [];
        ref_spectra_shifted(i).FWHM_target_mean   = [];
        ref_spectra_shifted(i).FWHM_target_std    = [];
        ref_spectra_shifted(i).background_values     = [];
        ref_spectra_shifted(i).background_mean        = NaN;
        ref_spectra_shifted(i).background_std         = NaN;
        ref_spectra_shifted(i).R2_values              = [];
        ref_spectra_shifted(i).theoretical_spectrum   = nan(1, n_wn);
    end
 
    % if n_dropped > 0
    %     warning('extract_shifted_reference_spectra:pixelsDropped', ...
    %         'Phase %s : %d pixel(s) decale(s) hors de l''image B, ignores.', ...
    %         ref_spectra(i).name, n_dropped);
    % end
end
 
%% ================================================================
% 3. Affichage : spectre original (A) vs spectre transfere (B)
 
if display_figures
    plotShiftedComparison(ref_spectra.data, ref_spectra_shifted, ...
        wavenumber_2ps,wavenumber_B);
end
 
end
 
 