function [roi_sig_coords,data_sorted] = intensityprofile(imgs,wn,nfluo,xb,yb,xs,ys,ws,hs)
    % fonction plot profil d'intensité au cours des acquistions. 
    I_raw = squeeze(imgs);

    figure('Name','Sélection ROI','NumberTitle','off');
    imagesc(I_raw(:,:,nfluo));
    axis image;
    colormap parula;
    colorbar;
    title('1) Sélectionnez le ROI BACKGROUND puis double-clic');
    
    % -------- ROI BACKGROUND --------
    if xb == 0 
        roi_bg = drawrectangle('Color','b');
        wait(roi_bg);   % attendre double-clic
        mask_bg = createMask(roi_bg);
    else 
        roi_bg = drawrectangle('Position', [xb, yb, 10, 10], 'Color', 'b');
        mask_bg= createMask(roi_bg);
        % mask_bg = false(size(imgs(:,:,1)));    % même taille que img, initialement faux
        % mask_bg(xb:yb, xb:yb) = true;  % région rectangulaire à true
    end
    
    title('2) Sélectionnez le ROI SIGNAL puis double-clic');
    
    % -------- ROI SIGNAL --------
    if xs == 0 % si pas de roi en entrée
        roi_sig = drawrectangle('Color','r');
        wait(roi_sig);
        mask_sig = createMask(roi_sig);
    
        % Récupérer les coordonnées du ROI SIGNAL
        roi_sig_coords = roi_sig.Position; % [x, y, width, height]
        fprintf('Coordonnées du ROI SIGNAL : [x=%.2f, y=%.2f, largeur=%.2f, hauteur=%.2f]\n', ...
        roi_sig_coords(1), roi_sig_coords(2), roi_sig_coords(3), roi_sig_coords(4));    
    else 
        roi_sig = drawrectangle('Position', [xs, ys, ws, hs], 'Color', 'r');
        mask_sig = createMask(roi_sig);
        roi_sig_coords = 0;
    end
    % close(gcf);
    
    % -------- Extraction du spectre --------
    imgs = squeeze(imgs);
    n_files = size(imgs,3);
    spectrum_sig = zeros(n_files,1);
    spectrum_bg  = zeros(n_files,1);
    
    time = (1:n_files);  
    
    for nj = 1:n_files
        img = imgs(:,:,nj);
    
        spectrum_sig(nj) = mean(img(mask_sig));
        spectrum_bg(nj)  = mean(img(mask_bg));
    end
    
    % Soustraction du background
    spectrum_corr = spectrum_sig - spectrum_bg;

    % wn(:)
    % spectrum_corr(:)
    %-------- Plot final --------
    if isempty(wn) % étude fluo fonction des acquisitions 
        figure;
        plot(time,spectrum_corr,'-o','LineWidth',1.5);
        xlabel('acquisitions', 'FontSize', 16);
        ylabel('Intensity (a.u.)', 'FontSize', 16);
        title('fluorescent degrowth', 'FontSize', 18);
        grid on;
    else %étude du spectre
        % disp(['before: ', num2str(spectrum_corr')]);
        data = [wn(:), spectrum_corr(:)];
        data_sorted = sortrows(data, 1);
        wavenumber_sorted = data_sorted(:,1);
        sp_sorted = data_sorted(:,2);
        % disp(['after: ', num2str(sp_sorted')]);
        figure;
        plot(wavenumber_sorted, sp_sorted, '-o', 'LineWidth', 1.5);
        xlabel('Wavenumber (cm^{-1})');
        ylabel('Intensity (a.u.)');
        title(['Intensity profile']);
        grid on;
    end
end