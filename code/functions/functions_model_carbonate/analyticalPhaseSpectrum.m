function [G, sigma_eff] = analyticalPhaseSpectrum(wavenumber, nu, FWHM, ratio, sigma_inst)
% Spectre d'une phase (somme ponderee de ses raies), chaque raie etant
% convoluee ANALYTIQUEMENT avec la reponse instrumentale gaussienne :
%   sigma_eff(p) = sqrt(sigma_phase(p)^2 + sigma_inst^2)
    ratio = ratio/sum(ratio);
    G = zeros(size(wavenumber));
    sigma_eff = zeros(size(nu));
 
    for p = 1:numel(nu)
        sigma_phase  = fwhm2sigma(FWHM(p));
        sigma_eff(p) = sqrt(sigma_phase^2 + sigma_inst^2);
        G = G + ratio(p) * gaussianArea(wavenumber, nu(p), sigma_eff(p));
    end
end