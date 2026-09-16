function plotFitMaps(pixel_fit, phase_model, active_idx)
% Subplot : une carte d'amplitude ajustee par phase active, + carte de
% R^2, + carte du fond continu ajuste.

    [n_y, n_x] = size(pixel_fit);
    n_active   = numel(active_idx);

    n_maps = n_active + 3;   % + R2 + background + nb phases significatives
    n_cols = ceil(sqrt(n_maps));
    n_rows = ceil(n_maps/n_cols);

    figure('Color','white','Position',[100 100 1300 850]);

    for a = 1:n_active
        k = active_idx(a);
        map_k = reshape(cellfun(@(A) A(k), {pixel_fit.A}), n_y, n_x);

        subplot(n_rows, n_cols, a);
        imagesc(map_k); axis image; colorbar;
        title(sprintf('A : %s', phase_model(k).name), 'FontSize', 11);
    end

    subplot(n_rows, n_cols, n_active+1);
    imagesc(reshape([pixel_fit.R2], n_y, n_x)); axis image; colorbar;
    title('R^2 (fit non-lineaire)', 'FontSize', 11);

    subplot(n_rows, n_cols, n_active+2);
    imagesc(reshape([pixel_fit.background], n_y, n_x)); axis image; colorbar;
    title('Fond residuel', 'FontSize', 11);

    subplot(n_rows, n_cols, n_active+3);
    n_sig_map = reshape( ...
        cellfun(@(s) sum(s(active_idx)), {pixel_fit.A_significant}), n_y, n_x);
    imagesc(n_sig_map); axis image; colorbar;
    title('Nb phases significatives', 'FontSize', 11);

end