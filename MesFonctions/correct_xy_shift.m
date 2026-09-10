function img_shifted = correct_xy_shift(img,xshift,yshift)

    % Initialize the corrected images array
    img_shifted = zeros(size(img));
    img_shifted(:, :) = circshift(img(:, :), [yshift, xshift]);
        % img_shifted(:, :, j) = imtranslate(imgs(:, :, j), [xshift, yshift], 'FillValues', 0);



    % % Initialisation de l'image décalée avec la valeur de fond
    % img_shifted = zeros(size(imgs));
    % 
    % % Copie des pixels
    % 
    % for i = 1:i0-1 
    %     img_shifted = imgs(:, :, i);  % Extract the current image
    % end
    % 
    % for j = i0:size(imgs,3)
    %             % Taille de l'image
    %     [rows, cols] = size(imgs(:,:,j));
    % 
    % 
    %     % Calcul des indices valides après décalage
    %     row_indices = max(1, 1 + yshift) : min(rows, rows + yshift);
    %     col_indices = max(1, 1 + xshift) : min(cols, cols + xshift);
    % 
    %     % Décalage des pixels valides
    %     if yshift >= 0
    %         target_rows = row_indices - yshift;
    %     else
    %         target_rows = row_indices + abs(yshift);
    %     end
    % 
    %     if xshift >= 0
    %         target_cols = col_indices - xshift;
    %     else
    %         target_cols = col_indices + abs(xshift);
    %     end
    %     img_shifted(target_rows, target_cols,i) = imgs(row_indices, col_indices);
    % end


    
    % % Initialize the corrected images array
    % img_shifted = zeros(size(imgs));
    % 
    % %image not corrected 
    % for i=1:i0 
    %     img_shifted(:, :, i) = imgs(:, :, i);
    % end
    % 
    % %image corrected
    % for j = i0:size(imgs, 3)
    %     img_shifted(:, :, j) = circshift(imgs(:, :, j), [yshift, xshift,0]);
    %     % img_shifted(:, :, j) = imtranslate(imgs(:, :, j), [xshift, yshift], 'FillValues', 0);
    % end


end