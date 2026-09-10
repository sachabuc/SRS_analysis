function correctfluo_intensityprofile(imgs,wn,nfluo,A,tau,C)
    

    I_raw = squeeze(imgs);

    figure('Name','Sélection ROI','NumberTitle','off');
    imagesc(I_raw(:,:,nfluo));
    axis image;
    colormap parula;
    colorbar;
    title('1) Sélectionnez le ROI BACKGROUND puis double-clic');
    
    % -------- ROI BACKGROUND --------
    roi_bg = drawrectangle('Color','b');
    wait(roi_bg);   % attendre double-clic
    mask_bg = createMask(roi_bg);
    
    title('2) Sélectionnez le ROI SIGNAL puis double-clic');
    
    % -------- ROI SIGNAL --------
    roi_sig = drawrectangle('Color','r');
    wait(roi_sig);
    mask_sig = createMask(roi_sig);
    
    % close(gcf);
    
    % -------- Extraction du spectre --------
    
    n_files = size(imgs,4);
    spectrum_sig = zeros(n_files,1);
    spectrum_bg  = zeros(n_files,1);
    
    time = (1:n_files);  
    
    for nj = 1:n_files
        img = squeeze(imgs(1,:,:,nj));
    
        spectrum_sig(nj) = mean(img(mask_sig));
        spectrum_bg(nj)  = mean(img(mask_bg));
    end
    
    % Soustraction du background
    spectrum_corr = spectrum_sig - spectrum_bg;
    %mean_spec = mean(spectrum_corr);
        %-------- Retrait de la composante fluo --------
    
      
    time = time(:);
    spectrum_corr = spectrum_corr(:);

    % Modèle de fluorescence
    Cbis = C;
    % spectrum_corr(nfluo)
    % exp(nfluo/tau)

    %eq Virginie : 
    %carto_nofluo(:,:,tt) = I_corr(:,:,tt) - I_corr(:,:,nfluo)*( exp(-time(tt) / tau) + C )./( exp(-time(nfluo) / tau) + C );

    % I_attenuation_bis = (spectrum_corr(nfluo) - Cbis)*exp(nfluo/tau);

    %I_attenuation = mean_fluo/mean_spec;
    % fprintf('Imean_fluo/Imean_ROI = %.4f\n', I_attenuation);
    fprintf('(spectrum_corr(nfluo) - Cbis)*exp(nfluo/tau) = %.4f\n', I_attenuation_bis);

    if C~=0
        % fluo = (A/I_attenuation*I_attenuation) * exp(-time / tau) - C ;
        fluo = 
* exp(-time / tau) + C ;
    else 
        fluo = I_attenuation_bis * exp(-time / tau);
    end
    
    % if C~=0
    %     fluo = (A/I_attenuation*I_attenuation) * exp(-time / tau) - C ;
    % else 
    %     fluo = (A/I_attenuation*I_attenuation) * exp(-time / tau);
    % end

    % Signal corrigé
    spectrum_nofluo = spectrum_corr - fluo;
    
    %-------- Plot final --------
    if isempty(wn) % étude fluo fonction des acquisitions 
        figure;
        plot(time,spectrum_corr,'-o','LineWidth',1.5);
        xlabel('acquisitions');
        ylabel('Intensity (a.u.)');
        title(['Intensity profile ']);
        grid on;
    else %étude du spectre
        % disp(['before: ', num2str(spectrum_nofluo')]);
        data = [wn(:), spectrum_corr(:)];
        data_nofluo = [wn(:), spectrum_nofluo(:)];

        data_sorted = sortrows(data, 1);
        data_sorted_nofluo = sortrows(data_nofluo, 1);

        wavenumber_sorted = data_sorted(:,1);
        sp_sorted = data_sorted(:,2);
        wavenumber_sorted_nofluo = data_sorted_nofluo(:,1);
        sp_sorted_nofluo = data_sorted_nofluo(:,2);
        % disp(['after: ', num2str(sp_sorted_nofluo')]);


        figure;
        plot(wavenumber_sorted, sp_sorted, 'o-', 'LineWidth', 1); hold on;
        % plot(time, fluo, 'r--', 'LineWidth', 2);
        plot(wavenumber_sorted_nofluo, sp_sorted_nofluo, 'g-', 'LineWidth', 2);
    
        xlabel('wavenumber (cm-1)');
        ylabel('Intensity (a.u.)');
        title('Intensity profile (correction fluo)');
        legend('Signal brut', 'Signal corrigé',sprintf('facteur d attenuation : (I_attenuation = %.2f)', I_attenuation), 'Location', 'best');
        grid on;
    end
end