function [Cmaps,Spectra,n_comp] = MCR_Raman_pipeline_GPT(Istack)

    % Istack = cube hyperspectral (Nx,Ny,Nlambda)
    
    [Nx,Ny,Nlambda] = size(Istack);
    
    % --------------------------------
    % 1. reshape (pixels × spectre)
    % --------------------------------
    D = reshape(Istack,Nx*Ny,Nlambda);
    
    % centrer les spectres
    D = D - mean(D,2);
    
    % --------------------------------
    % 2. Estimation automatique du nombre de composantes
    % --------------------------------
    [U,S,V] = svd(D,'econ');
    
    singular_values = diag(S);
    
    % critère : variance expliquée
    variance = singular_values.^2 / sum(singular_values.^2);
    
    cumvar = cumsum(variance);
    
    n_comp = find(cumvar > 0.995,1);   % 99.5% variance
    
    fprintf('Nombre estimé de composantes : %d\n',n_comp)
    
    % --------------------------------
    % 3. initialisation spectrale
    % --------------------------------
    S_init = V(:,1:n_comp)';
    
    % --------------------------------
    % 4. MCR-ALS
    % --------------------------------
    max_iter = 200;
    
    C = rand(size(D,1),n_comp);
    S = S_init;
    
    for iter = 1:max_iter
    
        % update concentrations
        C = D / S;
        C(C<0) = 0;
    
        % update spectra
        S = C \ D;
        S(S<0) = 0;
    
    end
    
    % --------------------------------
    % 5. cartes chimiques
    % --------------------------------
    Cmaps = reshape(C,Nx,Ny,n_comp);
    
    Spectra = S;
    
    % --------------------------------
    % 6. visualisation
    % --------------------------------
    figure
    
    for k=1:n_comp
        subplot(1,n_comp,k)
        imagesc(Cmaps(:,:,k))
        axis image
        colorbar
        title(['Component ',num2str(k)])
    end
    
    figure
    plot(S')
    xlabel('Wavenumber index')
    ylabel('Intensity')
    title('Resolved spectra')

end