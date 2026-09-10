function mask_good_fit = analyze_map_fluo(A_map, tau_map, C_map, Imean_map, R2_map, seuil_R2,I1)
    % fonction qui colore les pixels dont le fit a un R² > seuil_R2
    % seuil_R2 : Seuil pour le coefficient de détermination (R²)
    % A_map, tau_map, C_map : Cartes des paramètres de fit pour chaque pixel
    % Imean_map : Carte de l'intensité moyenne corrigée
    % R2_map : Carte des valeurs de R² pour chaque pixel
    % mask_good_fit : Masque binaire (1 = R² > seuil_R2, 0 = sinon)



    % Création du masque des pixels avec R² > seuil_R2
    mask_good_fit = R2_map > seuil_R2;

    % Affichage des cartes de paramètres
    figure(2000);
    subplot(2, 3, 1);
    imagesc(A_map);caxis([50 1200]);
    title('Carte de A');
    colorbar;
    axis image;
    hold on;
    contour(I1, 3, 'w', 'LineWidth', 1);
    hold off;

    subplot(2, 3, 2);
    imagesc(tau_map);caxis([0 1]);
    title('Carte de \tau');
    colorbar;
    axis image;
    hold on;
    contour(I1, 3, 'w', 'LineWidth', 1);
    hold off;

    subplot(2, 3, 3);
    imagesc(C_map);caxis([-40 -20]);
    title('Carte de C');
    colorbar;
    axis image;
    hold on;
    contour(I1, 3, 'w', 'LineWidth', 1);
    hold off;

    subplot(2, 3, 4);
    imagesc(R2_map);caxis([0.9 1])
    title('Carte de R^2');
    colorbar;
    axis image;
    hold on;
    contour(I1, 3, 'w', 'LineWidth', 1);
    hold off;

    subplot(2, 3, 5);
    imagesc(R2_map);caxis([0 1])
    title('Carte de R^2');
    colorbar;
    axis image;
    hold on;
    contour(I1, 3, 'w', 'LineWidth', 1);
    hold off;

    subplot(2, 3, 6);
    imagesc(Imean_map);caxis([-40 -20]);
    title('Carte Imean');
    colorbar;
    axis image;
    hold on;
    contour(I1, 3, 'w', 'LineWidth', 1);
    hold off;

    % % Superposition du masque en rouge
    % [rows, cols] = find(mask_good_fit);
    % for k = 1:length(rows)
    %     plot(cols(k), rows(k), 'r.', 'MarkerSize', 10);
    % end

end