function plotDetectabilityVsTau(summary)
 
    figure('Color','white','Position',[100 100 1100 800]);
    colors = lines(numel(summary));
 
    subplot(2,2,1); hold on;
    for p = 1:numel(summary)
        plot(summary(p).tau_fwhm, summary(p).A_own, '-o', 'Color', colors(p,:), ...
             'LineWidth', 2, 'DisplayName', summary(p).name);
    end
    xlabel('\tau_{FWHM} (ps)'); ylabel('Amplitude (aire, a.u.)');
    title('Aire ajustee (controle)', 'FontSize', 12);
    legend('Location', 'best'); grid on; box on;
 
    subplot(2,2,2); hold on;
    for p = 1:numel(summary)
        plot(summary(p).tau_fwhm, summary(p).peak_height_meas, '-o', 'Color', colors(p,:), ...
             'LineWidth', 2, 'DisplayName', summary(p).name);
    end
    xlabel('\tau_{FWHM} (ps)'); ylabel('Hauteur de pic (a.u.)');
    title('Hauteur de pic mesuree', 'FontSize', 12);
    legend('Location', 'best'); grid on; box on;
 
    subplot(2,2,3); hold on;
    for p = 1:numel(summary)
        plot(summary(p).tau_fwhm, summary(p).n_pool, '-o', 'Color', colors(p,:), ...
             'LineWidth', 2, 'DisplayName', summary(p).name);
    end
    xlabel('\tau_{FWHM} (ps)'); ylabel('Nb de pixels dominants');
    title('Taille du pool (detectabilite)', 'FontSize', 12);
    legend('Location', 'best'); grid on; box on;
 
    subplot(2,2,4); hold on;
    for p = 1:numel(summary)
        plot(summary(p).tau_fwhm, summary(p).R2_worst_used, '-o', 'Color', colors(p,:), ...
             'LineWidth', 2, 'DisplayName', summary(p).name);
    end
    xlabel('\tau_{FWHM} (ps)'); ylabel('R^2 (pire pixel garde)');
    title('Qualite du fit', 'FontSize', 12);
    legend('Location', 'best'); grid on; box on;
 
end