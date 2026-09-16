function carto_nofluo = correctfluo_intensityprofile_virginie(imgs,nfluo,A,tau,C)
   

    I_raw = squeeze(imgs);
    
    I_corr = I_raw - mean(mean(I_raw(10:20,10:20,:),1),2);
 
    % -------- Extraction du spectre --------
    % figure(15);
    % for k=1:size(I_corr,3);
    %     subplot(1,size(I_corr,3),k); imagesc(I_corr(:,:,k));
    % end

    n_files = size(imgs,4);
    
    time = (1:n_files);
    time = time(:);

    for tt =1:size(time,1)
        carto_nofluo(:,:,tt) = I_corr(:,:,tt) - I_corr(:,:,nfluo)*( exp(-time(tt) / tau) + C )./( exp(-time(nfluo) / tau) + C );
        carto_nofluoA(:,:,tt) = I_corr(:,:,tt) - I_corr(:,:,nfluo)*( A*exp(-time(tt) / tau) + C )./( A*exp(-time(nfluo) / tau) + C );
    end

    tt=3;
    alphaA = (A*exp(-time(tt) / tau) + C )./( A*exp(-time(nfluo) / tau) + C )
    alpha = (exp(-time(tt) / tau) + C )./( exp(-time(nfluo) / tau) + C)

    % figure(16);
    % for k=1:size(I_corr,3);
    %     subplot(1,size(I_corr,3),k); imagesc(carto_nofluo(:,:,k));
    % end
    % 
    % figure(17);
    % for k=1:size(I_corr,3);
    %     subplot(1,size(I_corr,3),k); imagesc(carto_nofluoA(:,:,k));
    % end

    % figure(18);
    % imagesc(carto_nofluo(:,:,3)-carto_nofluo(:,:,1));caxis([-10,10]);colorbar;
    % 
    % figure(19);
    % imagesc(carto_nofluoA(:,:,3)-carto_nofluoA(:,:,1));caxis([-10,150]);colorbar;

end