function G = rawPhaseSpectrum(wavenumber, nu, FWHM, ratio)
% Spectre "pur" d'une phase (sans elargissement instrumental), utilise
% comme entree de la convolution NUMERIQUE.
    ratio = ratio/sum(ratio);
    G = zeros(size(wavenumber));
    for p = 1:numel(nu)
        sigma_phase = fwhm2sigma(FWHM(p));
        G = G + ratio(p) * gaussianArea(wavenumber, nu(p), sigma_phase);
    end
end