function I_sum = plot_wavenumber_sum_ROI( ...
    I_corr, wavenumber, nu_interval, ref_roi, colors_roi)
% plot_wavenumber_sum_ROI
%
% Somme les images I_corr sur un intervalle de nombres d'onde,
% puis affiche la carte résultante avec les ROI utilisés.
%
% INPUTS
%   I_corr       : image hyperspectrale [ny x nx x n_wn]
%   wavenumber   : vecteur des nombres d'onde [n_wn x 1] ou [1 x n_wn]
%   nu_interval  : [nu_min nu_max] en cm^-1
%   ref_roi      : structure contenant les ROI et leurs noms
%                  .roi  = [row_start row_end col_start col_end]
%                  .name = nom affiché dans la légende
%   colors_roi   : couleurs des ROI [n_roi x 3]
%
% OUTPUT
%   I_sum        : image obtenue après sommation sur l'intervalle spectral
%
% Exemple :
%
%   I_sum = plot_wavenumber_sum_ROI( ...
%       I_corr, wavenumber, [1070 1090], ...
%       ref_roi, colors_roi);

    %% ================================================================
    % 1. Mise en forme

    if ndims(I_corr) == 4
        I_corr = squeeze(I_corr);
    end

    assert(ndims(I_corr) == 3, ...
        'I_corr doit être une matrice 3D [ny x nx x n_wavenumber].');

    wavenumber = wavenumber(:);

    [n_y, n_x, n_wn] = size(I_corr);

    assert(numel(wavenumber) == n_wn, ...
        'Le nombre de wavenumbers ne correspond pas à I_corr.');

    assert(numel(nu_interval) == 2, ...
        'nu_interval doit être [nu_min nu_max].');

    nu_min = min(nu_interval);
    nu_max = max(nu_interval);

    %% ================================================================
    % 2. Sélection de l'intervalle spectral

    idx_nu = wavenumber >= nu_min & wavenumber <= nu_max;

    assert(any(idx_nu), ...
        'Aucun wavenumber dans l''intervalle [%g %g] cm^-1.', ...
        nu_min, nu_max);

    %% ================================================================
    % 3. Somme spectrale

    % Somme des images sur tous les wavenumbers sélectionnés
    I_sum = sum(I_corr(:,:,idx_nu), 3, 'omitnan');

    %% ================================================================
    % 4. Nombre de ROI

    n_roi = numel(ref_roi);

    assert(n_roi >= 1, ...
        'ref_roi doit contenir au moins un ROI.');

    assert(size(colors_roi,1) >= n_roi, ...
        'colors_roi doit contenir au moins une couleur par ROI.');

    %% ================================================================
    % 5. Affichage

    figure( ...
        'Color','white', ...
        'Position',[100 100 1000 800]);

    imagesc(I_sum);

    axis image;
    hold on;

    %% ================================================================
    % 6. Dessin des ROI

    for i = 1:n_roi

        drawROI( ...
            ref_roi(i).roi, ...
            colors_roi(i,:), ...
            ref_roi(i).name);

    end

    hold off;

    %% ================================================================
    % 7. Mise en forme

    xlabel('X (pixel)', 'FontSize',12);
    ylabel('Y (pixel)', 'FontSize',12);

    title( ...
        sprintf( ...
            'Somme spectrale [%g ; %g] cm^{-1}', ...
            nu_min, nu_max), ...
        'FontSize',13);

    cb = colorbar;
    cb.Label.String = 'Intensité intégrée';

    set(gca, ...
        'FontSize',11, ...
        'Box','on');

    %% ================================================================
    % 8. Légende

    legend( ...
        'Location','best', ...
        'Interpreter','none');

end