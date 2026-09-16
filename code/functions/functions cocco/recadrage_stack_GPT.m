function stack_out = recadrage_stack_GPT(stack_4D, xshift, yshift, refIdx, thetashift)
    % RECADRAGE_STACK recadre un stack d'images avec translation (+ rotation optionnelle)
    %
    % Inputs:
    %   stack_in  : (Nx, Ny, Nlambda) stack d'images
    %   xshift    : décalage en x (pixels) (scalaire ou vecteur de taille Nlambda)
    %   yshift    : décalage en y (pixels) (scalaire ou vecteur de taille Nlambda)
    %   refIdx    : indice de l'image de référence
    %   thetashift: (optionnel) rotation en degrés (scalaire ou vecteur)
    %
    % Output:
    %   stack_out : stack recadré

    stack_in = squeeze(stack_4D);
    
    [Nx, Ny, Nlambda] = size(stack_in);
    
    % Gestion des entrées scalaires → vecteurs
    if isscalar(xshift)
        xshift = xshift * ones(1, Nlambda);
    end
    if isscalar(yshift)
        yshift = yshift * ones(1, Nlambda);
    end
    
    if nargin < 5
        thetashift = zeros(1, Nlambda);
    elseif isscalar(thetashift)
        thetashift = thetashift * ones(1, Nlambda);
    end
    
    % Centrage des shifts par rapport à l'image de référence
    xshift = xshift - xshift(refIdx);
    yshift = yshift - yshift(refIdx);
    thetashift = thetashift - thetashift(refIdx);
    
    % Détermination des bornes de recadrage
    xmin = max(1, 1 + ceil(max(xshift)));
    xmax = min(Nx, Nx + floor(min(xshift)));
    
    ymin = max(1, 1 + ceil(max(yshift)));
    ymax = min(Ny, Ny + floor(min(yshift)));
    
    Nx_new = xmax - xmin + 1;
    Ny_new = ymax - ymin + 1;
    
    stack_out = zeros(Nx_new, Ny_new, Nlambda);
    
    % Boucle principale
    for k = 1:Nlambda
        
        img = stack_in(:,:,k);
        
        % Rotation (si nécessaire)
        if thetashift(k) ~= 0
            img = imrotate(img, thetashift(k), 'bilinear', 'crop');
        end
        
        % Translation
        tx = xshift(k);
        ty = yshift(k);
        
        img_shifted = imtranslate(img, [ty, tx], 'FillValues', 0);
        
        % Recadrage
        stack_out(:,:,k) = img_shifted(xmin:xmax, ymin:ymax);
    end

end