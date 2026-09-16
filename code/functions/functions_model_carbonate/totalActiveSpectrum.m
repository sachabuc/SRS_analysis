function total = totalActiveSpectrum(phase_model, wavenumber, sigma_inst)
% Somme, pour toutes les phases actives, du spectre analytique (raies
% convoluees par sigma_eff), pondere par l'amplitude A(k).
    total = zeros(size(wavenumber));
    for k = 1:numel(phase_model)
        if ~phase_model(k).use
            continue
        end
        G = analyticalPhaseSpectrum(wavenumber, phase_model(k).nu, ...
                phase_model(k).FWHM, phase_model(k).ratio, sigma_inst);
        total = total + phase_model(k).A * G;
    end
end