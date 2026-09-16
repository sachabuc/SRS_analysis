function display_reference_statistics(ref_spectra, fwhm_inst)
%DISPLAY_REFERENCE_STATISTICS
% Affiche les statistiques des spectres de référence et déconvolue
% la FWHM mesurée de chaque phase de la réponse instrumentale.
%
% INPUTS
%   ref_spectra : structure contenant les statistiques des références
%
%   fwhm_inst   : FWHM spectrale de la réponse instrumentale [cm^-1]
%
% La fonction utilise :
%
%   rs.FWHM_target_mean
%
% comme FWHM mesurée (effective) de la phase.
%
% La déconvolution est effectuée avec :
%
%   [fwhm_phase, ~] = deconvolve(fwhm_mesure, 0, fwhm_inst)
%
% avec :
%
%   FWHMeff^2 = FWHM_phase^2 + FWHM_inst^2


    % fprintf('\n');
    % fprintf('============================================================\n');
    % fprintf('          STATISTIQUES DES SPECTRES DE REFERENCE\n');
    % fprintf('============================================================\n');

        %% Résolution instrumentale utilisée

    fprintf('\n============================================================\n');
    fprintf('FWHM instrumentale utilisée : %.4f cm^-1\n', fwhm_inst);
    

    for i = 1:numel(ref_spectra)

        rs = ref_spectra(i);

        fprintf('\n------------------------------------------------------------\n');
        fprintf('Phase %d : %s\n', rs.phase_idx, rs.name);
        fprintf('------------------------------------------------------------\n');


        %% Informations générales

        if isfield(rs,'fwhm_inst')
            fprintf('fwhm_inst             : %.3f ps\n', rs.fwhm_inst);
        end

        fprintf('n_requested          : %d\n', rs.n_requested);
        fprintf('n_used               : %d\n', rs.n_used);

        fprintf('R2_worst_used        : %.5f\n', rs.R2_worst_used);


        %% Amplitudes de toutes les phases

        fprintf('\nAmplitude des phases :\n');

        for k = 1:size(rs.A_values,2)

            fprintf('  Phase %-3d : A_mean = %.5g +/- %.5g\n', ...
                k, ...
                rs.A_mean(k), ...
                rs.A_std(k));

        end


        %% Paramètres de la phase cible

        fprintf('\nParametres de %s :\n', rs.name);


        %% Positions des raies

        if ~isempty(rs.nu_target_mean)

            for j = 1:numel(rs.nu_target_mean)

                fprintf('  Raie %d : nu = %.4f +/- %.4f cm^-1\n', ...
                    j, ...
                    rs.nu_target_mean(j), ...
                    rs.nu_target_std(j));

            end

        end


        %% FWHM

        if ~isempty(rs.FWHM_target_mean)

            fprintf('\nLargeur spectrale :\n');

            for j = 1:numel(rs.FWHM_target_mean)

                % FWHM mesurée = largeur effective après convolution
                fwhm_mesure = rs.FWHM_target_mean(j);

                fwhm_mesure_std = rs.FWHM_target_std(j);


                fprintf('  Raie %d : FWHM_deconvolve = %.4f +/- %.4f cm^-1\n', ...
                    j, ...
                    fwhm_mesure, ...
                    fwhm_mesure_std);

            end

        end


        %% Background

        fprintf('\nBackground :\n');

        fprintf('  Mean = %.5g\n', rs.background_mean);
        fprintf('  Std  = %.5g\n', rs.background_std);


        %% Nombre de pixels

        if isfield(rs, 'pixel_linear_idx')

            fprintf('\nPixels gardes : %d\n', ...
                numel(rs.pixel_linear_idx));

        end

    end

end