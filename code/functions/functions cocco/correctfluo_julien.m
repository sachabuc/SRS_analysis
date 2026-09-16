function img_corrected = correctfluo_julien(imgs,tau)

    img = squeeze(imgs);
    [Nx,Ny,nk] = size(img);
    
    I1 = img(:,:,1);
    Ifluo = img(:,:,2);
    Ilast = img(:,:,nk);

    img_corrected = zeros(size(img));

    Amap = (Ifluo - Ilast).*exp(2/tau);
    Cmap = Ilast;


    for k=1:nk
        
        img_corrected(:,:,k) = img(:,:,k) - Amap(:,:).*exp(-k/tau) - Cmap(:,:);
    
    end

    figure()
    subplot(1,2,1)
    imagesc(Amap);caxis([-5;50]);colorbar;
    title('Amap');
    hold on;
    contour(I1, 3, 'w', 'LineWidth', 1);
    hold off;
    subplot(1,2,2)
    imagesc(Cmap);caxis([-5;100]);colorbar;
    title('Cmap');
    hold on;
    contour(I1, 3, 'w', 'LineWidth', 1);
    hold off;

end