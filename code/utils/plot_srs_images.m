function plot_srs_images(I_corr, ni, Imin, Imax, titles, diff_ranges)
    % PLOT_SRS_IMAGES - Affiche des images SRS dans une figure avec subplots.
    %   I_corr : Stack d'images 3D (H x W x N).
    %   ni : Vecteur de 4 éléments [n1, n2, n3, n4] (numéros des images).
    %   Imin : Valeur minimale pour caxis (scalaire ou vecteur de 4 éléments).
    %   Imax : Valeur maximale pour caxis (scalaire ou vecteur de 4 éléments).
    %   titles : Cell array de 4 éléments pour les titres (optionnel).
    %   diff_ranges : Plages pour les différences [min_diff, max_diff] (optionnel, défaut : [-5 5]).

    % Vérifications
    if nargin < 4 || isempty(Imin) || isempty(Imax)
        error('Imin et Imax doivent être fournis.');
    end
    if nargin < 5 || isempty(titles)
        titles = {'Image 1', 'Image 2', 'Image 3', 'Image 4'};
    end
    if nargin < 6 || isempty(diff_ranges)
        diff_ranges = [-5, 5];
    end

    % Extraire les images
    I1 = I_corr(:,:,ni(1));
    I2 = I_corr(:,:,ni(2));
    I3 = I_corr(:,:,ni(3));
    I4 = I_corr(:,:,ni(4));

    % Créer la figure
    figure; clf;

    % Subplot 1: I1
    subplot(2,3,1);
    imagesc(I1);
    if length(Imin) == 4
        caxis([Imin(1) Imax(1)]);
    else
        caxis([Imin Imax]);
    end
    colorbar;
    title(titles{1});

    % Subplot 2: I3 (Calcite)
    subplot(2,3,2);
    imagesc(I3);
    if length(Imin) == 4
        caxis([Imin(3) Imax(3)]);
    else
        caxis([Imin 300]); % Cas spécial pour Calcite (comme dans ton code)
    end
    colorbar;
    title(titles{3});

    % Subplot 3: I2
    subplot(2,3,3);
    imagesc(I2);
    if length(Imin) == 4
        caxis([Imin(2) Imax(2)]);
    else
        caxis([Imin Imax]);
    end
    colorbar;
    title(titles{2});

    % Subplot 4: I4
    subplot(2,3,4);
    imagesc(I4);
    if length(Imin) == 4
        caxis([Imin(4) Imax(4)]);
    else
        caxis([Imin Imax]);
    end
    colorbar;
    title(titles{4});

    % Subplot 5: I4 - I3
    subplot(2,3,5);
    imagesc(I4 - I3);
    caxis(diff_ranges);
    colorbar;
    title('I4 - I3');

    % Subplot 6: I4 - I1
    subplot(2,3,6);
    imagesc(I4 - I1);
    caxis(diff_ranges);
    colorbar;
    title('I4 - I1');

    % Titre global
    sgtitle('Map ACC + Calcite', 'FontSize', 12, 'FontWeight', 'bold');
end