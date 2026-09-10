function [mask_calcite, mask_acc] = detect_calcite_acc_mistral(imgs, wavenumber, cp_for_acc)
    % imgs : Stack d'images hyperspectrales de taille (Nx, Ny, Nlambda)
    % wavenumber : Vecteur des nombres d'onde (Nlambda x 1)
    % cp_for_acc : Numéro de la composante principale à utiliser pour détecter l'ACC (ex: 2, 3, ou 4)
    % mask_calcite : Masque binaire pour la calcite (1 = calcite, 0 = autre)
    % mask_acc : Masque binaire pour l'ACC (1 = ACC, 0 = autre)

    % 1. Redimensionner les données pour PCA
    [Nx, Ny, Nlambda] = size(imgs);
    X = reshape(imgs, [], Nlambda)'; % Transposer pour avoir (Nlambda, Nx*Ny)

    % 2. Centrer les données (soustraire la moyenne spectrale)
    X_mean = mean(X, 2);
    X_centered = X - X_mean;

    % 3. Appliquer PCA
    coeff = pca(X_centered');

    % 4. Afficher les contributions de toutes les composantes principales
    figure(1001);
    [wavenumber_sorted, idx] = sort(wavenumber); % Trie wavenumber par ordre croissant
    
    if size(coeff,2)<5 
        for i = 1:size(coeff, 2)
            plot(wavenumber_sorted, coeff(idx, i));
            hold on;
        end
    else 
        for i = 1:5
            plot(wavenumber_sorted, coeff(idx, i));
            hold on;
        end
    end
    legendArray = arrayfun(@(x) sprintf('CP%d', x), 1:size(coeff, 2), 'UniformOutput', false);
    legend(legendArray);
    xlabel('Nombre d''onde (cm^{-1})');
    ylabel('Contribution');
    grid on;
    title('Contributions de toutes les composantes principales');

    % 5. Projeter les données sur toutes les composantes principales
    X_pca = coeff;
    scores = X_centered' * X_pca;
    scores = scores(:, 1:size(coeff, 2)); % (Nx*Ny, nombre de composantes)

    % 6. Visualiser les relations entre les composantes principales
    figure(1002);
    scatter(scores(:, 1), scores(:, cp_for_acc), 'ro');
    xlabel(sprintf('CP1'));
    ylabel(sprintf('CP%d', cp_for_acc));
    title(sprintf('CP1 vs CP%d', cp_for_acc));

    % 7. Normaliser les scores pour une meilleure visualisation
    scores_normalized = zscore(scores);

    % 8. Reconstruire les scores en image 2D
    scores_img = reshape(scores_normalized, Nx, Ny, size(coeff, 2));

    % 9. Détecter la calcite (supposée dominante et de forte intensité)
    %    On utilise un seuil sur la CP1 (la plus variante)
    threshold_calcite = 2; % À ajuster selon les données
    mask_calcite = scores_img(:, :, 1) > threshold_calcite;

    % 10. Détecter l'ACC en utilisant la composante spécifiée
    threshold_acc = 2; % À ajuster (valeur élevée pour éviter le bruit)
    mask_acc = scores_img(:, :, cp_for_acc) > threshold_acc;

    % 11. Nettoyer les masques (optionnel : morphologie mathématique)
    %     Exemple : enlever les petits objets (bruit)
    mask_acc = bwareaopen(mask_acc, 4); % Garde seulement les objets > 3 pixels
    mask_calcite = bwareaopen(mask_calcite, 5);
end