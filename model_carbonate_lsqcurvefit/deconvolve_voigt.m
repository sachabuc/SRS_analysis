function [fwhm_phase, fwhm_inst] = deconvolve_voigt(fwhm_mesure, fwhm_phase, fwhm_inst)
% DECONVOLVE_VOIGT Calcule la FWHM spectrale instrumentale ou celle de la calcite
% à partir d'une largeur convoluée mesurée (Profil de Voigt).
%
% Usage:
%   [f_calcite, f_inst] = deconvolve_voigt(14.4, 0, 12.0) % cherche la calcite
%   [f_calcite, f_inst] = deconvolve_voigt(14.4, 4.2, 0)  % cherche l'instrumentale

    % Constantes de l'approximation de Voigt
    c1 = 0.5346;
    c2 = 0.2166;

    % Vérification et calcul de la FWHM instrumentale manquante
    if isempty(fwhm_inst) || fwhm_inst == 0
        term = (fwhm_mesure - c1 * fwhm_phase)^2 - c2 * (fwhm_phase^2);
        if term < 0
            error('Erreur: La FWHM mesurée est trop petite par rapport à la FWHM de la calcite.');
        end
        fwhm_inst = sqrt(term);

    % Vérification et calcul de la FWHM de la calcite manquante
    elseif isempty(fwhm_phase) || fwhm_phase == 0
        % Inversion numérique de la formule de Voigt pour isoler la FWHM Lorentzienne
        func = @(f_calc) (c1 * f_calc + sqrt(c2 * f_calc^2 + fwhm_inst^2)) - fwhm_mesure;
        fwhm_phase = fzero(func, [0, fwhm_mesure]);
    end
end