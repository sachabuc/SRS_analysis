function plotReferenceSpectra(ref_spectra, wavenumber, show_theoretical)
% Spectre moyen +/- 1 ecart-type par phase demandee, superpose au modele
% theorique si disponible.

    figure('Color','white','Position',[100 100 1000 700]);
    hold on;

    colors = lines(numel(ref_spectra));

    wavenumber_dense = linspace(min(wavenumber), max(wavenumber), 2000);


    for i = 1:numel(ref_spectra)


        rs = ref_spectra(i);

        if rs.n_used == 0
            continue
        end

        upper = rs.sum_spectrum + rs.std_spectrum*rs.n_requested;
        lower = rs.sum_spectrum - rs.std_spectrum*rs.n_requested;
        fill([wavenumber, fliplr(wavenumber)], [upper, fliplr(lower)], ...
             colors(i,:), 'FaceAlpha', 0.15, 'EdgeColor', 'none', ...
             'HandleVisibility', 'off');

        plot(wavenumber, rs.sum_spectrum, '-x', 'Color', colors(i,:), ...
             'LineWidth', 1.5, 'DisplayName', ...
             sprintf('%s (n=%d, R^2 >= %.3f)', rs.name, rs.n_used, rs.R2_worst_used));

        % --- Modele theorique ---
        if show_theoretical
    
            plot(rs.wavenumber_theoretical, rs.theoretical_spectrum*rs.n_requested, '--', ...
                 'Color', colors(i,:), ...
                 'LineWidth', 1.5, ...
                 'DisplayName', sprintf('%s (theorique)', rs.name));
        end
    end

    xlabel('Wavenumber (cm^{-1})', 'FontSize', 12);
    ylabel('Intensity (a.u.)', 'FontSize', 12);
    title('Spectres de reference par phase (top-N par R^2)', 'FontSize', 13);
    legend('Location', 'best');
    grid on; box on; set(gca, 'FontSize', 11);

end