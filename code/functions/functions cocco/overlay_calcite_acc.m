function I3 = overlay_ACC_coccolith(I1,I2)

    % conversion double
    I1 = double(I1);
    I2 = double(I2);
    
    % -----------------------------
    % 1. Réduction du bruit
    % -----------------------------
    % I1f = medfilt2(I1,[3 3]);
    % I2f = medfilt2(I2,[3 3]);
    
    I1f = imgaussfilt(I1,1);
    I2f = imgaussfilt(I2,1);
    
    % -----------------------------
    % 2. Différence ACC-calcite
    % -----------------------------
    diff = I2f - I1f;
    
    % estimation robuste du bruit
    sigma = std(diff(:));
    
    % seuil sensible
    mask = diff > 0.7*sigma;
    
    % supprimer artefacts isolés
    mask = bwareaopen(mask,15);
    
    % -----------------------------
    % 3. Image de fond (garde dynamique même si négatif)
    % -----------------------------
    I2disp = (I2 - min(I2(:))) / (max(I2(:)) - min(I2(:)));
    
    I3 = repmat(I2disp,[1 1 3]);
    
    % -----------------------------
    % 4. Heatmap ACC
    % -----------------------------
    ACCmap = diff;
    ACCmap = (ACCmap - min(ACCmap(:))) / (max(ACCmap(:))-min(ACCmap(:)));
    
    alpha = 0.7;
    
    I3(:,:,1) = I3(:,:,1) + alpha*ACCmap.*mask;
    I3(:,:,2) = I3(:,:,2).*(~mask);
    I3(:,:,3) = I3(:,:,3).*(~mask);
    
    I3(I3>1)=1;
    
    % -----------------------------
    % 5. Affichage
    % -----------------------------
    figure
    imshow(I3)
    hold on
    
    contour(I1f,5,'w','LineWidth',1.5)
    
    title('ACC (rouge) et calcite (contours)')
    
    hold off

end