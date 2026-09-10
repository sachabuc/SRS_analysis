function [A,tau,Imean] = extract_fluo(imgs, nfluo)
    % Fonction pour tracer le profil d'intensité au cours des acquisitions et extraire tau.
    % imgs : Stack d'images de taille (Nx, Ny, n_files)
    % nfluo : Numéro de l'image de fluorescence à afficher pour la sélection des ROIs
    % tau : Facteur de décroissance de la fluorescence obtenu à partir du fit du profil d'intensité

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

    title('2) Sélectionnez le ROI SIGNAL fluo puis double-clic');

    % -------- ROI SIGNAL --------
    roi_sig = drawrectangle('Color','r');
    wait(roi_sig);
    mask_sig = createMask(roi_sig);

    % -------- Extraction du spectre --------

    n_files = size(imgs, 4);
    spectrum_sig = zeros(n_files, 1);
    spectrum_bg  = zeros(n_files, 1);

    time = (1:n_files);

    for nj = 1:n_files
        img = squeeze(imgs(1,:,:,nj));

        spectrum_sig(nj) = mean(img(mask_sig));
        spectrum_bg(nj)  = mean(img(mask_bg));
    end

    % Soustraction du background
    spectrum_corr = spectrum_sig - spectrum_bg;
    Imean = mean(spectrum_corr);  % Calculate the mean intensity after background correction

    %-------- Plot final --------
    figure;
    plot(time, spectrum_corr, '-o', 'LineWidth', 1.5);
    xlabel('Acquisitions');
    ylabel('Intensity (a.u.)');
    title('Intensity profile');
    grid on;

    %-------- Fit exponentiel --------
        % Modèle : A * exp(-t/tau)
    ft = fittype('A*exp(-x/tau)', 'independent', 'x', 'coefficients', {'A','tau'});

    % Valeurs initiales (important pour convergence)
    A0 = max(spectrum_corr);
    
    tau0 = (max(time)-min(time))/2;

    % Fit
    [fitresult, gof] = fit(time(:), spectrum_corr(:), ft, ...
        'StartPoint', [A0, tau0]);

    % Extraction de A et tau
    A = fitresult.A;
    tau = fitresult.tau;


    %-------- Ajout au plot --------
    hold on;
    t_fit = linspace(min(time), max(time), 200);
    plot(t_fit, fitresult.A * exp(-t_fit / tau), 'r-', 'LineWidth', 2);

    legend('Data', sprintf('Fit exp (A = %.2f, \\tau = %.2f)', A, tau), 'Location', 'best');

    % Affichage console
    fprintf('Tau extrait = %.4f\n', tau);
    fprintf('A extrait = %.4f\n', A);
    fprintf('R^2 = %.4f\n', gof.rsquare);

end