function [label_map, score_img] = PCA_ACC_calcite_classification(Istack, wavenumber)

    % Istack : image stack (Nx, Ny, Nlambda)
    % wavenumber : vecteur des longueurs d'onde Raman
    
    [Nx, Ny, Nlambda] = size(Istack);
    
    % -----------------------------
    % 1. Reshape : pixel → spectre
    % -----------------------------
    X = reshape(Istack, Nx*Ny, Nlambda);
    
    % suppression offset (utile si valeurs négatives)
    X = X - mean(X,2);
    
    % -----------------------------
    % 2. PCA
    % -----------------------------
    [coeff, score, ~] = pca(X);
    
    % score = coordonnées des pixels dans l'espace PCA
    score_img = reshape(score(:,1:3), Nx, Ny, 3);
    
    % -----------------------------
    % 3. Détection du bruit
    % -----------------------------
    spectral_energy = std(X,0,2);
    
    noise_threshold = median(spectral_energy)/3;
    
    noise_pixels = spectral_energy < noise_threshold;
    
    % -----------------------------
    % 4. Dominance spectrale
    % -----------------------------
    calcite_signal = X(:,1);
    
    ACC_signal = mean(X(:,[3 4]),2);
    
    % -----------------------------
    % 5. Attribution des labels
    % -----------------------------
    label = zeros(Nx*Ny,1);
    
    for i = 1:Nx*Ny
        
        if noise_pixels(i)
            label(i) = 0; % bruit
            
        elseif calcite_signal(i) > ACC_signal(i)
            label(i) = 1; % calcite
            
        else
            label(i) = 2; % ACC
            
        end
        
    end
    
    % -----------------------------
    % 6. Reshape vers image
    % -----------------------------
    label_map = reshape(label, Nx, Ny);
    
    % -----------------------------
    % 7. Visualisation
    % -----------------------------
    figure
    
    RGB = zeros(Nx,Ny,3);
    
    % calcite = blanc
    RGB(:,:,1) = label_map==1;
    RGB(:,:,2) = label_map==1;
    RGB(:,:,3) = label_map==1;
    
    % ACC = rouge
    RGB(:,:,1) = RGB(:,:,1) + (label_map==2);
    
    % bruit = noir
    
    imshow(RGB)
    
    title('Classification PCA : bruit / calcite / ACC')

end