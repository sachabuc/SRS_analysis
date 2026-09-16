function G = phaseModelSpectrum(phase, wavenumber)
%PHASEMODELSPECTRUM Spectre d'une phase evalue a partir des sigma_eff
%DEJA STOCKES dans phase_model (calcules une fois par
%MODEL_CARBONATE_PHASES), sans recalculer la convolution avec la reponse
%instrumentale.
%
%   G = PHASEMODELSPECTRUM(phase, wavenumber) ou phase = phase_model(k),
%   une entree individuelle de la structure retournee par
%   MODEL_CARBONATE_PHASES (doit contenir .nu, .ratio, .sigma_eff).
%
%   A utiliser partout ou phase_model existe deja et que nu/FWHM restent
%   fixes : construction de la matrice de design pour lsqnonneg
%   (INIT_PIXEL_AMPLITUDES), modele direct d'un fit non-lineaire, etc.
%   Contrairement a ANALYTICALPHASESPECTRUM, cette fonction ne prend pas
%   sigma_inst en entree : elle fait confiance a .sigma_eff, deja
%   calcule une seule fois pour tout le pipeline.
    ratio = phase.ratio;
    ratio = ratio/sum(ratio);
    G = zeros(size(wavenumber));
    for p = 1:numel(phase.nu)
        G = G + ratio(p) * gaussianArea(wavenumber, phase.nu(p), phase.sigma_eff(p));
    end
end
