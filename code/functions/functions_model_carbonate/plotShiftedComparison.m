function plotShiftedComparison(ref_spectra, ref_spectra_shifted,...
    wavenumber_2ps, wavenumber_B)
% Superpose, pour chaque phase, le spectre moyen original (acquisition A)
% et le spectre moyen aux memes pixels decales (acquisition B).
% NB : suppose que ref_spectra et wavenumber_B partagent la meme grille
% de nombre d'onde -- pas de reinterpolation faite ici.
 
    n_req = numel(ref_spectra);
    figure('Color', 'white', 'Position', [100 100 1000 700]);
    hold on;
    colors = lines(n_req);
 
    for i = 1:n_req
        if ref_spectra(i).n_used > 0
            plot(wavenumber_2ps, ref_spectra(i).mean_spectrum, '-', ...
                 'Color', colors(i,:), 'LineWidth', 2, ...
                 'DisplayName', sprintf('%s (A, tau=%.1f)', ref_spectra(i).name, ref_spectra(i).tau_fwhm));
        end
        if ref_spectra_shifted(i).n_used > 0
            plot(wavenumber_B, ref_spectra_shifted(i).mean_spectrum, '--', ...
                 'Color', colors(i,:), 'LineWidth', 2, ...
                 'DisplayName', sprintf('%s (B, tau=%.1f, n=%d)', ...
                 ref_spectra_shifted(i).name, ref_spectra_shifted(i).tau_fwhm, ref_spectra_shifted(i).n_used));
        end
    end
 
    xlabel('Wavenumber (cm^{-1})', 'FontSize', 12);
    ylabel('Intensity (a.u.)', 'FontSize', 12);
    title('Memes pixels, acquisition A vs B (decalage applique)', 'FontSize', 13);
    legend('Location', 'best');
    grid on; box on; set(gca, 'FontSize', 11);
 