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

        plot(wavenumber, rs.mean_spectrum, '-', 'Color', colors(i,:), ...
             'LineWidth', 2.5, 'DisplayName', ...
             sprintf('%s (n=%d, tri=%s, R^2 >= %.3f)', rs.name, rs.n_used, rs.selection_method, rs.R2_worst_used));

        if show_theoretical
            plot(wavenumber, rs.theoretical_spectrum, '--', 'Color', colors(i,:), ...
                 'LineWidth', 1.5, 'DisplayName', sprintf('%s (theorique)', rs.name));
        end
    end

    xlabel('Wavenumber (cm^{-1})', 'FontSize', 12);
    ylabel('Intensity (a.u.)', 'FontSize', 12);
    title('Spectres de reference par phase (top-N par R^2)', 'FontSize', 13);
    legend('Location', 'best');
    grid on; box on; set(gca, 'FontSize', 11);

end