function plot_pixel_fits_from_ref_spectra( ...
          ref_spectra, I_corr, wavenumber, pixel_fit, phase_model, ...
          fwhm_instr, n_worst_detail)
%PLOT_PIXEL_FITS_FROM_REF_SPECTRA Verification visuelle des fits pour
%les pixels retenus par PLOT_PHASE_REFERENCE_SPECTRA (ref_spectra), pour
%reperer d'eventuels fits divergents dans le lot.
%
%   plot_pixel_fits_from_ref_spectra(ref_spectra, I_corr, wavenumber, ...
%       pixel_fit, phase_model, fwhm_instr, n_worst_detail)
%
%   Pour chaque phase de ref_spectra :
%     1) Une vue d'ensemble : tous les spectres bruts des pixels retenus,
%        superposes en transparence (les fits divergents ressortent
%        visuellement du "nuage"), avec le spectre moyen en trait plein.
%     2) Un detail individuel des n_worst_detail pixels au R^2 le plus
%        bas PARMI ceux retenus (spectre brut + courbe ajustee
%        reconstruite, cf. RECONSTRUCTFITTEDSPECTRUM) -- ce sont les
%        candidats les plus probables a un fit divergent.
%
%   ENTREES
%     ref_spectra      : structure issue de PLOT_PHASE_REFERENCE_SPECTRA
%                        (utilise .row .col .name .mean_spectrum .n_used)
%     I_corr            : cube hyperspectral [n_y x n_x x n_wn], MEME
%                        acquisition que celle utilisee pour ref_spectra
%     wavenumber         : nombres d'onde (cm^-1), pas necessairement
%                        tries (retries ici, coherent avec les autres
%                        fonctions)
%     pixel_fit          : structure issue de FIT_PIXEL_PHASES sur cette
%                        meme acquisition (utilise .A .nu .FWHM
%                        .background .R2)
%     phase_model         : structure issue de MODEL_CARBONATE_PHASES
%     fwhm_instr            : FWHM (ps) de la reponse instrumentale de
%                        cette acquisition (doit correspondre a celui
%                        utilise pour generer pixel_fit)
%     n_worst_detail       : nombre de pixels a detailler individuellement
%                        (les moins bons R^2 du lot retenu), defaut 9

if nargin < 7 || isempty(n_worst_detail)
    n_worst_detail = 9;
end

%% ================================================================
% 1. Mise en forme

if ndims(I_corr) == 4
    I_corr = squeeze(I_corr);
end

[wavenumber, sort_idx] = sort(wavenumber(:).');
I_corr = I_corr(:,:,sort_idx);

[n_y, n_x, n_wn] = size(I_corr);
I_flat = reshape(permute(I_corr, [3 1 2]), n_wn, n_y*n_x).';   % [n_pixels x n_wn]

active_idx = find([phase_model.use]);

%% ================================================================
% 2. Une phase a la fois

for i = 1:numel(ref_spectra)

    if ref_spectra(i).n_used == 0
        continue
    end

    rows = ref_spectra(i).row;
    cols = ref_spectra(i).col;
    lin_idx = sub2ind([n_y n_x], rows, cols);

    spectra_sel = I_flat(lin_idx, :);                      % [n_used x n_wn]
    R2_sel = arrayfun(@(r,c) pixel_fit(r,c).R2, rows, cols);

    %% --------------------------------------------------------------
    % Vue d'ensemble : tous les spectres bruts superposes
    figure('Color', 'white', 'Position', [100 100 900 600]);
    hold on;

    for p = 1:size(spectra_sel, 1)
        plot(wavenumber, spectra_sel(p,:), '-', 'Color', [0.3 0.3 0.3 0.12], ...
             'LineWidth', 1, 'HandleVisibility', 'off');
    end
    plot(wavenumber, ref_spectra(i).mean_spectrum, 'r-', 'LineWidth', 2.5, ...
         'DisplayName', 'Spectre moyen');

    xlabel('Wavenumber (cm^{-1})', 'FontSize', 12);
    ylabel('Intensity (a.u.)', 'FontSize', 12);
    title(sprintf('%s : %d pixels retenus -- vue d''ensemble', ...
          ref_spectra(i).name, ref_spectra(i).n_used), 'FontSize', 13);
    legend('Location', 'best');
    grid on; box on; set(gca, 'FontSize', 11);

    %% --------------------------------------------------------------
    % Detail des pires fits du lot (R^2 le plus bas PARMI les retenus)
    [~, order] = sort(R2_sel, 'ascend');
    n_show = min(n_worst_detail, numel(order));
    worst = order(1:n_show);

    n_cols_grid = ceil(sqrt(n_show));
    n_rows_grid = ceil(n_show/n_cols_grid);

    figure('Color', 'white', 'Position', [100 100 1200 850]);

    for w = 1:n_show
        idx = worst(w);
        iy = rows(idx); ix = cols(idx);

        I_model = reconstructFittedSpectrum( ...
            pixel_fit(iy,ix), phase_model, active_idx, wavenumber, fwhm_instr);

        subplot(n_rows_grid, n_cols_grid, w);
        plot(wavenumber, spectra_sel(idx,:), 'ko', 'MarkerSize', 3, ...
             'DisplayName', 'Donnees');
        hold on;
        plot(wavenumber, I_model, 'r-', 'LineWidth', 1.5, 'DisplayName', 'Fit');
        title(sprintf('(%d,%d) R^2=%.3f', iy, ix, R2_sel(idx)), 'FontSize', 9);
        set(gca, 'FontSize', 8);
    end

    sgtitle(sprintf('%s : %d pires fits parmi les pixels retenus', ...
            ref_spectra(i).name, n_show), 'FontSize', 13);

end

end
