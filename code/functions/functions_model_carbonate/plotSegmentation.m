function plotSegmentation(phase_map, composition_map, phase_model, active_idx, phase_colors)
% Carte de segmentation (categorielle) + une carte de fraction par phase
% active.

    n_active = numel(active_idx);
    n_phases = numel(phase_model);

    n_maps   = 1 + n_active;
    n_cols   = ceil(sqrt(n_maps));
    n_rows   = ceil(n_maps/n_cols);

    figure('Color','white','Position',[100 100 1300 850]);

    subplot(n_rows, n_cols, 1);
    imagesc(phase_map.label); axis image;

    % Colormap categorielle : les labels sont des categories sans ordre
    % naturel, pas une grandeur continue -- un colormap sequentiel
    % (parula par defaut) rendrait des categories voisines difficiles a
    % distinguer. Blanc = exclu, une couleur par phase (complementaire,
    % cf. DEFAULTPHASECOLORS, ou fournie via phase_colors), gris moyen =
    % aucune phase, gris fonce = ambigu.
    % --- Labels originaux ---
    labels_original = phase_map.label;
    
    % Labels spéciaux
    label_none      = n_phases + 1;
    label_ambiguous = n_phases + 2;
    label_ambiguous_display = n_active + 2;
    
    % --- Créer une carte de labels pour l'affichage ---
    labels_display = zeros(size(labels_original));
    
    % 0 : exclu
    labels_display(labels_original == 0) = 0;
    
    % Phases actives : indices compacts 1:n_active
    for a = 1:n_active
    
        k = active_idx(a);
    
        labels_display(labels_original == k) = a;
    
    end
    
    % Aucune phase
    labels_display(labels_original == label_none) = n_active + 1;
    
    % Ambigu
    labels_display(labels_original == label_ambiguous) = ...
        label_ambiguous_display;
    
    % --- Affichage ---
    subplot(n_rows, n_cols, 1);
    
    imagesc(labels_display);
    axis image;
    
    % Couleurs uniquement des phases actives
    if isempty(phase_colors)
    
        phase_colors_full = defaultPhaseColors(n_phases);
        phase_colors = phase_colors_full(active_idx, :);
    
    end
    
    assert(isequal(size(phase_colors), [n_active, 3]), ...
        'phase_colors doit être de taille [%d x 3].', n_active);
    
    cmap = [
        0.95 0.95 0.95;      % 0 : exclu
        phase_colors;        % 1:n_active : phases actives
        0.60 0.60 0.60;      % n_active+1 : aucune phase
        0.20 0.20 0.20       % n_active+2 : ambigu
    ];
    
    colormap(gca, cmap);
    clim([0, n_active + 2]);
    
    % --- Colorbar ---
    cb = colorbar;
    
    cb.Ticks = [
        0, ...
        1:n_active, ...
        n_active + 1, ...
        n_active + 2
    ];
    
    cb.TickLabels = [
        {'Exclu'}, ...
        {phase_model(active_idx).name}, ...
        {'Aucune'}, ...
        {'Ambigu'}
    ];
    
    title('Segmentation (label)', 'FontSize', 11);
    for a = 1:n_active
        k = active_idx(a);
        subplot(n_rows, n_cols, 1+a);
        imagesc(composition_map(:,:,k)); axis image; colorbar;
        clim([0 1]);
        title(sprintf('Fraction : %s', phase_model(k).name), 'FontSize', 11);
    end

end