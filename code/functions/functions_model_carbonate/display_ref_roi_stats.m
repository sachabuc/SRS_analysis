function display_ref_roi_stats(ref_roi, phase_model, active_idx)
%DISPLAY_COMPARE_SPECTRUMS_STATS
% Affiche dans la console les statistiques des fits de compare_spectrums_advance.
%
% INPUTS
%   ref_roi     : structure contenant les resultats des fits ROI
%   phase_model : structure definissant les phases
%   active_idx  : indices des phases actives dans phase_model
%
% Affiche pour chaque ROI :
%   - l'amplitude A_fit de chaque phase active
%   - la position de chaque raie ajustee nu_fit
%   - la FWHM de chaque raie ajustee FWHM_fit

    fprintf('\nCompare_spectrums_advance STATS\n');

    for i = 1:numel(ref_roi)

        rs = ref_roi(i);

        fprintf('\n------------------------------------------------------------\n');
        fprintf('Phase %d : %s\n', rs.phase_idx, rs.name);
        fprintf('------------------------------------------------------------\n');


        %% ========================================================
        % Amplitudes de toutes les phases
        % =========================================================

        for k = 1:numel(active_idx)

            j = active_idx(k);

            fprintf('  Phase %s : A_fit = %.5g\n', ...
                phase_model(j).name, ...
                rs.A_fit(j));

        end


        %% ========================================================
        % Positions des raies
        % =========================================================

        if ~isempty(rs.nu_fit)

            for j = 1:numel(rs.nu_fit)

                if ~isempty(rs.nu_fit{j})

                    nu_j = rs.nu_fit{j};

                    for p = 1:numel(nu_j)

                        fprintf('  Phase %s : Raie %d : nu = %.4f cm^-1\n', ...
                            phase_model(j).name, ...
                            p, ...
                            nu_j(p));

                    end

                end

            end

        end


        %% ========================================================
        % FWHM
        % =========================================================

        if ~isempty(rs.FWHM_fit)

            for j = 1:numel(rs.FWHM_fit)

                if ~isempty(rs.FWHM_fit{j})

                    FWHM_j = rs.FWHM_fit{j};

                    for p = 1:numel(FWHM_j)

                        fprintf('  Phase %s : FWHM %d : FWHM = %.4f cm^-1\n', ...
                            phase_model(j).name, ...
                            p, ...
                            FWHM_j(p));

                    end

                end

            end

        end

    end

end