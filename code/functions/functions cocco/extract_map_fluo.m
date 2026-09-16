
function [A_map, tau_map, C_map, Imean_map, R2_map] = extract_map_fluo(imgs4D)
    % Fonction pour fitter le spectre de chaque pixel de imgs
    % imgs : Stack d'images de taille (Nx, Ny, n_files)
    % A_map, tau_map, C_map : Cartes des paramètres de fit pour chaque pixel
    % R2_map : Carte des valeurs de R² pour chaque pixel


    % Initialisation des cartes de sortie
    imgs = squeeze(imgs4D);

    [Nx, Ny, n_files] = size(imgs);
    A_map = zeros(Nx, Ny);
    tau_map = zeros(Nx, Ny);
    C_map = zeros(Nx, Ny);
    Imean_map = zeros(Nx, Ny);
    R2_map = zeros(Nx, Ny);

    % Modèle de fit
    ft = fittype('A*exp(-x/tau) + C', 'independent', 'x', 'coefficients', {'A', 'tau', 'C'});

    
    % Boucle sur chaque pixel
    for ix = 1:Nx
        fprintf('processing line %f on %f',ix,Nx);
        for iy = 1:Ny
            % Extraction du spectre temporel du pixel (ix, iy)
            spectrum_corr = imgs(ix, iy, :);

            % Normalisation du temps
            time = 1:n_files;

            % Valeurs initiales pour le fit
            A0 = max(spectrum_corr);
            tau0 = (max(time) - min(time)) / 2;
            C0 = min(spectrum_corr);

            % Fit
            try
                [fitresult, gof] = fit(time(:), spectrum_corr(:), ft, ...
                    'StartPoint', [A0, tau0, C0], ...
                    'Lower', [0, 0, -Inf], ...  % Bornes pour éviter des valeurs aberrantes
                    'Upper', [Inf, Inf, Inf]);

                % Stockage des résultats
                A_map(ix, iy) = fitresult.A;
                tau_map(ix, iy) = fitresult.tau;
                C_map(ix, iy) = fitresult.C;
                Imean_map(ix, iy) = mean(spectrum_corr);
                R2_map(ix, iy) = gof.rsquare;
            catch
                % En cas d'échec du fit, stocker des valeurs par défaut
                A_map(ix, iy) = NaN;
                tau_map(ix, iy) = NaN;
                C_map(ix, iy) = NaN;
                Imean_map(ix, iy) = NaN;
                R2_map(ix, iy) = 0;
            end
        end
    end


    % % Affichage des cartes de paramètres
    % figure;
    % subplot(2, 3, 1);
    % imagesc(A_map);
    % title('Carte de A');
    % colorbar;
    % axis image;
    % 
    % subplot(2, 3, 2);
    % imagesc(tau_map);
    % title('Carte de \tau');
    % colorbar;
    % axis image;
    % 
    % subplot(2, 3, 3);
    % imagesc(C_map);
    % title('Carte de C');
    % colorbar;
    % axis image;
    % 
    % subplot(2, 3, 4);
    % imagesc(R2_map);
    % title('Carte de R^2');
    % colorbar;
    % axis image;
    % 
    % subplot(2, 3, 5);
    % imagesc(Imean_map);
    % title('Carte de Imean');
    % colorbar;
    % axis image;
end