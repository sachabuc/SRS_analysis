function label_map = ACC_calcite_detection_GPT(Istack)

    [Nx,Ny,Nlambda] = size(Istack);
    
    % reshape cube hyperspectral
    D = reshape(Istack,Nx*Ny,Nlambda);
    
    % -------------------------
    % 1. normalisation spectrale
    % -------------------------
    D = D ./ (sqrt(sum(D.^2,2)) + eps);
    
    % -------------------------
    % 2. réduction du bruit (PCA)
    % -------------------------
    [coeff,score,~] = pca(D);
    
    n_pc = 3;
    X = score(:,1:n_pc);
    
    % -------------------------
    % 3. clustering spectral
    % -------------------------
    n_clusters = 4;
    
    [idx,C] = kmeans(X,n_clusters,'Replicates',5);
    
    % -------------------------
    % 4. spectres moyens des clusters
    % -------------------------
    spectra = zeros(n_clusters,Nlambda);
    
    for k=1:n_clusters
        spectra(k,:) = mean(D(idx==k,:),1);
    end
    
    % -------------------------
    % 5. classification des clusters
    % -------------------------
    cluster_label = zeros(n_clusters,1);
    
    for k=1:n_clusters
        
        s = spectra(k,:);
        
        calcite_signal = s(1);
        ACC_signal = mean(s([3 4]));
        
        if max(s) < 0.05
            cluster_label(k) = 0; % bruit
            
        elseif ACC_signal > calcite_signal
            cluster_label(k) = 2; % ACC
            
        else
            cluster_label(k) = 1; % calcite
            
        end
        
    end
    
    % -------------------------
    % 6. création carte finale
    % -------------------------
    labels = cluster_label(idx);
    
    label_map = reshape(labels,Nx,Ny);
    
    % -------------------------
    % 7. visualisation
    % -------------------------
    RGB = zeros(Nx,Ny,3);
    
    % calcite blanc
    RGB(:,:,1) = label_map==1;
    RGB(:,:,2) = label_map==1;
    RGB(:,:,3) = label_map==1;
    
    % ACC rouge
    RGB(:,:,1) = RGB(:,:,1) + (label_map==2);
    
    figure
    imshow(RGB)
    
    title('Carte minérale : bruit / calcite / ACC')

end