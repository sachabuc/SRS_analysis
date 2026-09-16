function [I_corr, background_spectrum, noise_spectral, ...
          noise_spatial, fit_params] = ...
    estimate_background_noise_final(imgs, wavenumber, ...
                              x1_s, x1_e, x2_s, x2_e, ...
                              wi, idl, idc)

% ESTIMATE_BACKGROUND_NOISE
%
% Estime le background et les deux composantes du bruit :
%
%   1) BRUIT SPECTRAL :
%      calculé sur un ROI de background.
%      Pour chaque nombre d'onde, on calcule l'écart-type spatial
%      des spectres du ROI après retrait du niveau moyen de chaque pixel.
%
%   2) BRUIT SPATIAL :
%      calculé sur une image à un nombre d'onde wi.
%      Un profil horizontal et vertical est extrait dans le ROI.
%      Un fit linéaire est réalisé et l'écart-type des résidus
%      donne le bruit spatial.
%
%
% ENTREES
%
% imgs        : cube [ny x nx x n_wn]
% wavenumber  : nombres d'onde
%
% ROI background :
% x1_s, x1_e : bornes verticales (lignes)
% x2_s, x2_e : bornes horizontales (colonnes)
%
% wi         : indice du nombre d'onde utilisé pour l'étude spatiale
%
% idl        : ligne utilisée pour le profil horizontal
% idc        : colonne utilisée pour le profil vertical
%
%
% SORTIES
%
% I_corr              : cube corrigé du background
% background_spectrum : background moyen du ROI [n_wn x 1]
% noise_spectral      : bruit spectral [n_wn x 1]
% noise_spatial       : bruit spatial (.line et .column)
% fit_params          : paramètres des fits linéaires
%
% -------------------------------------------------------------------------


%% ================================================================
% 1. Mise en forme
% ================================================================

if ndims(imgs) == 4
    imgs = squeeze(imgs);
end

[ny, nx, n_wn] = size(imgs);

wavenumber = wavenumber(:);

if numel(wavenumber) ~= n_wn
    error('Le nombre de nombres d''onde ne correspond pas à imgs.');
end


%% ================================================================
% 2. Tri spectral
% ================================================================

[wavenumber, sort_idx] = sort(wavenumber);

imgs = imgs(:,:,sort_idx);


%% ================================================================
% 3. Extraction du ROI background
% ================================================================

ROI_background = imgs(x1_s:x1_e, x2_s:x2_e, :);

[n_roi_y, n_roi_x, ~] = size(ROI_background);


%% ================================================================
% 4. Background spectral
% ================================================================

% Moyenne spatiale du ROI pour chaque nombre d'onde

background_spectrum = squeeze( ...
    mean(mean(ROI_background,1,'omitnan'),2,'omitnan'));

background_spectrum = background_spectrum(:);


%% ================================================================
% 5. Bruit spectral en fonction du nombre d'onde
% ================================================================

% Chaque ligne correspond à un pixel du ROI.
%
% [n_pixels x n_wn]

ROI_spectra = reshape( ...
    ROI_background, ...
    n_roi_y*n_roi_x, n_wn);


% Niveau moyen propre à chaque pixel

pixel_mean = mean(ROI_spectra,2,'omitnan');


% On retire le niveau moyen de chaque pixel.
%
% Cela évite de considérer une différence de niveau entre deux
% pixels comme du bruit.

ROI_centered = ROI_spectra - pixel_mean;


% Ecart-type spatial pour chaque nombre d'onde

noise_spectral = std(ROI_centered,0,1,'omitnan');

noise_spectral = noise_spectral(:);


%% ================================================================
% 6. Soustraction du background
% ================================================================

I_corr = imgs - reshape(background_spectrum,1,1,[]);


%% ================================================================
% 7. Vérification de wi
% ================================================================

if wi < 1 || wi > n_wn
    error('wi doit être compris entre 1 et %d.',n_wn);
end


%% ================================================================
% 8. Image utilisée pour l'étude du bruit spatial
% ================================================================

img_wi = imgs(:,:,wi);


%% ================================================================
% 9. Profil horizontal
% ================================================================

x_line = x2_s:x2_e;

line_profile = img_wi(idl,x_line);


%% ================================================================
% 10. Fit linéaire horizontal
% ================================================================

valid_line = isfinite(line_profile);

p_line = polyfit( ...
    x_line(valid_line), ...
    line_profile(valid_line), ...
    1);

fit_line = polyval(p_line,x_line);

residuals_line = line_profile - fit_line;

noise_line = std( ...
    residuals_line(valid_line), ...
    0,'omitnan');


%% ================================================================
% 11. Profil vertical
% ================================================================

x_column = x1_s:x1_e;

column_profile = img_wi(x_column,idc);


%% ================================================================
% 12. Fit linéaire vertical
% ================================================================

valid_column = isfinite(column_profile);

p_column = polyfit( ...
    x_column(valid_column), ...
    column_profile(valid_column), ...
    1);

fit_column = polyval(p_column,x_column);

residuals_column = column_profile - fit_column;

noise_column = std( ...
    residuals_column(valid_column), ...
    0,'omitnan');


%% ================================================================
% 13. Sauvegarde des résultats
% ================================================================

noise_spatial.line   = noise_line;
noise_spatial.column = noise_column;

fit_params.line   = p_line;
fit_params.column = p_column;


%% ================================================================
% 14. FIGURE 1 : IMAGE
% ================================================================

figure('Name','Image et ROI','Color','w');

imagesc(img_wi);
axis image;
colorbar;
colormap(gray);

hold on;

% ROI background

rectangle( ...
    'Position',[ ...
    x2_s, ...
    x1_s, ...
    x2_e-x2_s, ...
    x1_e-x1_s], ...
    'EdgeColor','r', ...
    'LineWidth',2);


% Ligne utilisée pour le profil horizontal

line( ...
    [x2_s x2_e], ...
    [idl idl], ...
    'LineStyle','--', ...
    'LineWidth',1.5);


% Colonne utilisée pour le profil vertical

line( ...
    [idc idc], ...
    [x1_s x1_e], ...
    'LineStyle','--', ...
    'LineWidth',1.5);

hold off;

title(sprintf( ...
    'Image à \\nu = %.2f cm^{-1}', ...
    wavenumber(wi)));

xlabel('x');
ylabel('y');


%% ================================================================
% 15. FIGURE 2 : ETUDE DU BRUIT
% ================================================================

figure('Name','Noise study','Color','w');


% ------------------------------------------------
% 15.1 Profil horizontal
% ------------------------------------------------

subplot(1,3,1);

plot(x_line,line_profile,'o-');
hold on;

plot( ...
    x_line, ...
    fit_line, ...
    '--', ...
    'LineWidth',1.5);

hold off;

xlabel('Pixel x');
ylabel('Intensité');

title(sprintf( ...
    'Bruit spatial horizontal = %.3g', ...
    noise_line));

legend('Profil','Fit linéaire', ...
       'Location','best');

grid on;


% ------------------------------------------------
% 15.2 Profil vertical
% ------------------------------------------------

subplot(1,3,2);

plot(x_column,column_profile,'o-');
hold on;

plot( ...
    x_column, ...
    fit_column, ...
    '--', ...
    'LineWidth',1.5);

hold off;

xlabel('Pixel y');
ylabel('Intensité');

title(sprintf( ...
    'Bruit spatial vertical = %.3g', ...
    noise_column));

legend('Profil','Fit linéaire', ...
       'Location','best');

grid on;


% ------------------------------------------------
% 15.3 Bruit spectral
% ------------------------------------------------

subplot(1,3,3);

plot( ...
    wavenumber, ...
    noise_spectral, ...
    'o-', ...
    'MarkerSize',4);

xlabel('Wavenumber (cm^{-1})');
ylabel('\sigma_{noise}');

title('Bruit spectral');

grid on;
box on;


end