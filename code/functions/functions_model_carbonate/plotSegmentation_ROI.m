function plotSegmentation_ROI(phase_map, phase_model, active_idx, ...
    phase_colors, colors_roi, ref_roi, sub_dir_save, exportgraphics_segm_roi)

% Carte de segmentation catégorielle + contours des ROI.
%
% Fonctionne avec 1 ou plusieurs ROI.
%
% ref_roi(i) contient notamment :
%   .roi
%   .name
%
% active_idx contient les indices des phases actives.

    %% ================================================================
    % 1. Paramètres

    n_active = numel(active_idx);
    n_phases = numel(phase_model);
    n_roi    = numel(ref_roi);

    %% ================================================================
    % 2. Vérifications

    assert(n_active >= 1, ...
        'active_idx doit contenir au moins une phase.');

    assert(size(colors_roi,1) >= n_roi, ...
        'colors_roi doit contenir au moins une couleur par ROI.');

    colors_roi = colors_roi(1:n_roi,:);

    %% ================================================================
    % 3. Labels originaux

    labels_original = phase_map.label;

    % Labels spéciaux
    label_none      = n_phases + 1;
    label_ambiguous = n_phases + 2;

    % Labels compacts pour l'affichage
    label_none_display      = n_active + 1;
    label_ambiguous_display = n_active + 2;

    %% ================================================================
    % 4. Création de la carte de labels d'affichage

    labels_display = zeros(size(labels_original));

    % ------------------------------------------------------------
    % 0 = exclu
    labels_display(labels_original == 0) = 0;

    % ------------------------------------------------------------
    % Phases actives
    %
    % Les indices réels des phases sont convertis en indices
    % compacts 1:n_active pour l'affichage.

    for a = 1:n_active

        k = active_idx(a);

        labels_display(labels_original == k) = a;

    end

    % ------------------------------------------------------------
    % Aucune phase

    labels_display(labels_original == label_none) = ...
        label_none_display;

    % ------------------------------------------------------------
    % Ambigu

    labels_display(labels_original == label_ambiguous) = ...
        label_ambiguous_display;

    %% ================================================================
    % 5. Figure

    figure( ...
        'Color','white', ...
        'Position',[100 100 1300 850]);

    imagesc(labels_display);

    axis image;
    hold on;

    %% ================================================================
    % 6. Dessin des ROI
    %
    % IMPORTANT :
    % fonctionne avec 1, 2 ou davantage de ROI.

    for i = 1:n_roi

        drawROI( ...
            ref_roi(i).roi, ...
            colors_roi(i,:), ...
            ref_roi(i).name);

    end

    hold off;

    %% ================================================================
    % 7. Couleurs des phases actives

    if isempty(phase_colors)

        phase_colors_full = defaultPhaseColors(n_phases);

        phase_colors = phase_colors_full(active_idx,:);

    end

    assert(isequal(size(phase_colors), [n_active, 3]), ...
        'phase_colors doit être de taille [%d x 3].', ...
        n_active);

    %% ================================================================
    % 8. Colormap

    % 0 : exclu
    % 1:n_active : phases actives
    % n_active+1 : aucune phase
    % n_active+2 : ambigu

    cmap = [0.95 0.95 0.95; phase_colors]; 
    colormap(gca, cmap); 
    clim([0, n_active]);

    %% ================================================================
    % 9. Colorbar

    cb = colorbar;

    cb.Ticks = 0:(n_active + 2);

    % Noms des phases actives
    phase_names = {phase_model(active_idx).name};

    cb.TickLabels = [ ...
        {'Exclu'}, ...
        phase_names, ...
        {'Aucune phase'}, ...
        {'Ambigu'}];

    %% ================================================================
    % 10. Titre

    % title( ...
    %     sprintf('Segmentation map with %d ROI', n_roi), ...
    %     'FontSize',11);

    %% ================================================================
    % 11. Export éventuel

    if exportgraphics_segm_roi

        if ~exist(sub_dir_save, 'dir')
            mkdir(sub_dir_save);
        end

        plot2svg( ...
            fullfile(sub_dir_save, 'segmentation.svg'), ...
            gcf);

    end

end