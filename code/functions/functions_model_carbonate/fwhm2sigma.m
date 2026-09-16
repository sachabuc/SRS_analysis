function sigma = fwhm2sigma(FWHM)
% Convertit une largeur a mi-hauteur (FWHM) en ecart-type gaussien sigma.
% FWHM <= 0 -> pas d'elargissement (sigma = 0).
    if FWHM > 0
        sigma = FWHM/2.355;
    else
        sigma = 0;
    end
end