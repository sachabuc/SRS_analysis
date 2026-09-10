function [fwhm_phase, fwhm_inst] = deconvolve(fwhm_mesure, fwhm_phase, fwhm_inst)
%DECONVOLVE Déconvolution de deux profils gaussiens.
%
% Relation utilisée :
%
%   FWHM_mesure^2 = FWHM_phase^2 + FWHM_inst^2
%
% Entrées :
%   fwhm_mesure : FWHM mesurée expérimentalement
%   fwhm_phase  : FWHM intrinsèque de la phase
%   fwhm_inst   : FWHM de la réponse instrumentale
%
% Si fwhm_phase = 0 :
%   -> calcule fwhm_phase à partir de fwhm_mesure et fwhm_inst
%
% Si fwhm_inst = 0 :
%   -> calcule fwhm_inst à partir de fwhm_mesure et fwhm_phase
%
% Sorties :
%   fwhm_phase : FWHM intrinsèque de la phase
%   fwhm_inst  : FWHM instrumentale

    % Vérification des entrées
    if fwhm_mesure < 0
        error('fwhm_mesure doit être positive.');
    end

    if fwhm_phase < 0
        error('fwhm_phase doit être positive ou nulle.');
    end

    if fwhm_inst < 0
        error('fwhm_inst doit être positive ou nulle.');
    end

    % -------------------------------------------------------------
    % Cas 1 : on cherche la FWHM intrinsèque de la phase
    % -------------------------------------------------------------
    if fwhm_phase == 0 && fwhm_inst > 0

        valeur = fwhm_mesure^2 - fwhm_inst^2;

        if valeur < 0
            error(['Impossible de calculer fwhm_phase : ' ...
                   'fwhm_inst est supérieure à fwhm_mesure.']);
        end

        fwhm_phase = sqrt(valeur);

    % -------------------------------------------------------------
    % Cas 2 : on cherche la FWHM instrumentale
    % -------------------------------------------------------------
    elseif fwhm_inst == 0 && fwhm_phase > 0

        valeur = fwhm_mesure^2 - fwhm_phase^2;

        if valeur < 0
            error(['Impossible de calculer fwhm_inst : ' ...
                   'fwhm_phase est supérieure à fwhm_mesure.']);
        end

        fwhm_inst = sqrt(valeur);

    % -------------------------------------------------------------
    % Cas 3 : les deux sont fournis
    % -------------------------------------------------------------
    elseif fwhm_phase > 0 && fwhm_inst > 0

        % Vérification de la cohérence
        fwhm_calculee = sqrt(fwhm_phase^2 + fwhm_inst^2);

        fprintf(['FWHM mesurée = %.4f cm^{-1}\n' ...
                 'FWHM calculée = %.4f cm^{-1}\n'], ...
                 fwhm_mesure, fwhm_calculee);

    % -------------------------------------------------------------
    % Cas 4 : impossible
    % -------------------------------------------------------------
    else
        error(['Il faut mettre soit fwhm_phase = 0, soit ' ...
               'fwhm_inst = 0, mais pas les deux.']);
    end

end