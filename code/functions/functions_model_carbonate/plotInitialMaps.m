
function plotInitialMaps(pixel_data, phase_model, active_idx)
% Subplot : une carte d'amplitude A0 par phase active, + carte de R^2,
% + carte de bruit estime, + carte des pixels valides.

    [n_y, n_x] = size(pixel_data);
    n_active   = numel(active_idx);

    n_maps = n_active + 3;   % + R2 + bruit + valid_pixel
    n_cols = ceil(sqrt(n_maps));
    n_rows = ceil(n_maps/n_cols);

    figure('Color','white','Position',[100 100 1300 850]);

    for a = 1:n_active
        k = active_idx(a);
        map_k = reshape(cellfun(@(A0) A0(k), {pixel_data.A0}), n_y, n_x);

        subplot(n_rows, n_cols, a);
        imagesc(map_k); axis image; colorbar;
        title(sprintf('A0 : %s', phase_model(k).name), 'FontSize', 11);
    end

    subplot(n_rows, n_cols, n_active+1);
    imagesc(reshape([pixel_data.R2], n_y, n_x)); axis image; clim([0 1]);colorbar;
    title('R^2 (fit lineaire)', 'FontSize', 11);

    subplot(n_rows, n_cols, n_active+3);
    imagesc(reshape([pixel_data.noise], n_y, n_x)); axis image; colorbar;
    title('Bruit estime (residu)', 'FontSize', 11);

    subplot(n_rows, n_cols, n_active+2);
    imagesc(reshape([pixel_data.valid_pixel], n_y, n_x)); axis image; colorbar;
    title('Pixels valides', 'FontSize', 11);
    colormap(gca, gray);

end