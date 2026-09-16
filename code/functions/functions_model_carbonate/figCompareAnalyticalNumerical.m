function figCompareAnalyticalNumerical(phase_model, wavenumber, dw, sigma_inst, tau_fwhm)
% Figure 1 : modele analytique (sigma_eff) vs modele numerique (conv),
% sur le spectre total (somme des phases actives), pour valider la
% formule analytique de convolution gaussienne.
 
    total_analytical = zeros(size(wavenumber));
    total_raw        = zeros(size(wavenumber));


    for k = 1:numel(phase_model)
        if ~phase_model(k).use
            continue
        end
        total_analytical = total_analytical + phase_model(k).A * phase_model(k).G_analytical;
        total_raw        = total_raw + phase_model(k).A * rawPhaseSpectrum( ...
                                wavenumber, phase_model(k).nu, ...
                                phase_model(k).FWHM, phase_model(k).ratio);
    end
 
    total_numerical = numericalConvolution(wavenumber, dw, total_raw, sigma_inst);
 
    figure('Color','white','Position',[100 100 1000 700]);
 
    subplot(2,1,1); hold on;
    plot(wavenumber, total_analytical, 'b-',  'LineWidth', 2.5, 'DisplayName','Analytique (\sigma_{eff})');
    plot(wavenumber, total_numerical,  'r--', 'LineWidth', 1.5, 'DisplayName','Numerique (conv)');
    xlabel('Wavenumber (cm^{-1})','FontSize',12);
    ylabel('Intensity (a.u.)','FontSize',12);
    title(sprintf('Modele analytique vs numerique -- \\tau_{FWHM} = %.1f ps', tau_fwhm),'FontSize',13);
    legend('Location','best');
    
            % Amplitudes des phases actives 
    for k = 1:numel(phase_model)
        if ~phase_model(k).use
            continue
        end
        plot(NaN, NaN, 'LineStyle', 'none', 'Marker', 'none', ...
             'DisplayName', sprintf('%s : A = %.2f', phase_model(k).name, phase_model(k).A));
    end
    grid on; box on; set(gca,'FontSize',11);
 
    subplot(2,1,2);
    plot(wavenumber, total_numerical - total_analytical, 'k-', 'LineWidth', 1.2);
    xlabel('Wavenumber (cm^{-1})','FontSize',12);
    ylabel('Numerique - Analytique','FontSize',12);
    title('Residu de validation','FontSize',13);
    grid on; box on; set(gca,'FontSize',11);
end