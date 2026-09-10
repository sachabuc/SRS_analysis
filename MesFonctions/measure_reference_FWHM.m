function [FWHM_mesure, FWHM_error, fit_result, ROI_background, ROI_phase] = ...
    measure_reference_FWHM(imgs, wavenumber)
%MEASURE_REFERENCE_FWHM
%
% Sélection interactive de deux ROI :
%   ROI 1 : background
%   ROI 2 : phase pure de référence
%
% Le spectre moyen de la ROI 1 est soustrait au spectre moyen de la ROI 2.
% Le spectre corrigé est ensuite ajusté par une gaussienne + offset.
%
% L'erreur sur la FWHM est estimée à partir de la dispersion des FWHM
% obtenues en ajustant individuellement les pixels de la ROI 2.
%
% ENTREES
%   imgs       : cube [ny x nx x n_wn]
%   wavenumber : vecteur des nombres d'onde [n_wn x 1]
%
% SORTIES
%   FWHM_mesure : FWHM du spectre moyen corrigé
%   FWHM_error  : STD des FWHM mesurées pixel par pixel
%   fit_result  : paramètres du fit du spectre moyen
%   ROI_background : masque logique de la ROI background
%   ROI_phase      : masque logique de la ROI phase
%
% fit_result contient :
%   .amplitude
%   .center
%   .sigma
%   .FWHM
%   .offset
%   .R2
%
% ================================================================


%% ================================================================
% 1. Mise en forme

if ndims(imgs) ~= 3
    error('imgs doit être un cube 3D [ny x nx x n_wn].');
end

wavenumber = wavenumber(:);

[ny,nx,n_wn] = size(imgs);

if numel(wavenumber) ~= n_wn
    error('Le nombre de nombres d''onde ne correspond pas au cube imgs.');
end


%% ================================================================
% 2. Image utilisée pour sélectionner les ROI

% Image intégrée spectralement
sum_img = sum(imgs,3,'omitnan');

figure('Name','Selection des ROI','Color','w');

imagesc(sum_img);
axis image;
colormap parula;
colorbar;

title({'Sélection des ROI', ...
       'ROI 1 : BACKGROUND puis ROI 2 : PHASE PURE'});


%% ================================================================
% 3. Sélection ROI background

disp(' ');
disp('---------------------------------------------');
disp('Sélection ROI 1 : BACKGROUND');
disp('Dessinez un rectangle puis double-cliquez.');

h1 = drawrectangle();

wait(h1);

pos1 = round(h1.Position);

x1 = max(1,pos1(1));
y1 = max(1,pos1(2));

x2 = min(nx,x1 + pos1(3) - 1);
y2 = min(ny,y1 + pos1(4) - 1);

ROI_background = false(ny,nx);
ROI_background(y1:y2,x1:x2) = true;


%% ================================================================
% 4. Sélection ROI phase pure

disp(' ');
disp('---------------------------------------------');
disp('Sélection ROI 2 : PHASE PURE DE REFERENCE');
disp('Dessinez un rectangle puis double-cliquez.');

h2 = drawrectangle();

wait(h2);

pos2 = round(h2.Position);

x1 = max(1,pos2(1));
y1 = max(1,pos2(2));

x2 = min(nx,x1 + pos2(3) - 1);
y2 = min(ny,y1 + pos2(4) - 1);

ROI_phase = false(ny,nx);
ROI_phase(y1:y2,x1:x2) = true;

close;


%% ================================================================
% 5 Extraction des spectres des ROI

% Pixels de la ROI background
idx_bg = find(ROI_background);

% Pixels de la ROI phase
idx_phase = find(ROI_phase);

% Reshape du cube :
% [ny*nx x n_wn]
imgs_2D = reshape(imgs, ny*nx, n_wn);

% Spectres des pixels des ROI
background_pixels = imgs_2D(idx_bg, :);
phase_pixels       = imgs_2D(idx_phase, :);

% Supprimer les pixels contenant des NaN/Inf
background_pixels = background_pixels( ...
    all(isfinite(background_pixels),2), :);

phase_pixels = phase_pixels( ...
    all(isfinite(phase_pixels),2), :);


%% ================================================================
% 6. Spectres moyens

background_spectrum = mean(background_pixels,1);
phase_spectrum      = mean(phase_pixels,1);


%% ================================================================
% 7. Soustraction du background

phase_corrected = phase_spectrum - background_spectrum;


%% ================================================================
% 8. Tri spectral

[wavenumber,sort_idx] = sort(wavenumber);

background_spectrum = background_spectrum(sort_idx);
phase_corrected = phase_corrected(sort_idx);

phase_pixels = phase_pixels(:,sort_idx);
background_pixels = background_pixels(:,sort_idx);

wavenumber = wavenumber(:);
phase_corrected = phase_corrected(:);
background_spectrum = background_spectrum(:);


%% ================================================================
% 9. Estimation initiale des paramètres

% Retrait d'un éventuel offset initial
offset0 = median(phase_corrected);

signal = phase_corrected - offset0;

[amplitude0,idx_max] = max(signal);

center0 = wavenumber(idx_max);

% Estimation grossière de la largeur à mi-hauteur
half_max = offset0 + amplitude0/2;

idx_half = find(phase_corrected >= half_max);

if numel(idx_half) >= 2
    FWHM0 = wavenumber(idx_half(end)) - ...
            wavenumber(idx_half(1));
else
    FWHM0 = 10;
end

sigma0 = FWHM0 / 2.355;


%% ================================================================
% 10. Fit du spectre moyen
%
% modèle :
%
% y = A exp(-(x-x0)^2/(2 sigma^2)) + B

model_fun = @(p,x) ...
    p(1).*exp(-(x-p(2)).^2./(2*p(3).^2)) + p(4);

p0 = [amplitude0, center0, sigma0, offset0];

% Bornes
lb = [0, ...
      min(wavenumber), ...
      0.1, ...
      -Inf];

ub = [Inf, ...
      max(wavenumber), ...
      100, ...
      Inf];

options = optimoptions('lsqcurvefit', ...
    'Display','off');


%% ================================================================
% 11. Fit

[p_fit,resnorm,residual,exitflag,output] = ...
    lsqcurvefit( ...
        model_fun, ...
        p0, ...
        wavenumber, ...
        phase_corrected, ...
        lb, ...
        ub, ...
        options);


%% ================================================================
% 12. Paramètres du fit

A_fit = p_fit(1);
center_fit = p_fit(2);
sigma_fit = p_fit(3);
offset_fit = p_fit(4);

FWHM_mesure = 2.355 * sigma_fit;


%% ================================================================
% 13. R²

y_fit = model_fun(p_fit,wavenumber);

SS_res = sum((phase_corrected-y_fit).^2);

SS_tot = sum((phase_corrected-mean(phase_corrected)).^2);

R2 = 1 - SS_res/SS_tot;


%% ================================================================
% 14. Fit pixel par pixel
%
% Permet d'estimer la dispersion réelle de la FWHM dans la ROI.

n_pixels = size(phase_pixels,1);

FWHM_pixels = nan(n_pixels,1);

for ip = 1:n_pixels

    % Spectre du pixel
    y_pixel = phase_pixels(ip,:).';
    y_pixel = y_pixel - background_spectrum;

    if any(~isfinite(y_pixel))
        continue
    end

    % Initialisation
    offset_pixel = median(y_pixel);

    signal_pixel = y_pixel - offset_pixel;

    [A_pixel,idx_pixel] = max(signal_pixel);

    if A_pixel <= 0
        continue
    end

    center_pixel = wavenumber(idx_pixel);

    % estimation largeur
    half_pixel = offset_pixel + A_pixel/2;

    idx_half = find(y_pixel >= half_pixel);

    if numel(idx_half) >= 2
        FWHM_pixel0 = ...
            wavenumber(idx_half(end)) - ...
            wavenumber(idx_half(1));
    else
        FWHM_pixel0 = FWHM_mesure;
    end

    sigma_pixel0 = max(FWHM_pixel0/2.355,0.1);

    p0_pixel = [A_pixel,...
                center_pixel,...
                sigma_pixel0,...
                offset_pixel];

    try

        p_pixel = lsqcurvefit( ...
            model_fun,...
            p0_pixel,...
            wavenumber,...
            y_pixel,...
            lb,...
            ub,...
            options);

        FWHM_pixels(ip) = 2.355*p_pixel(3);

    catch

        FWHM_pixels(ip) = NaN;

    end

end


%% ================================================================
% 15. Erreur sur la FWHM

valid_FWHM = isfinite(FWHM_pixels);

if sum(valid_FWHM) >= 2

    FWHM_error = std(FWHM_pixels(valid_FWHM));

else

    FWHM_error = NaN;

    warning('Pas assez de pixels valides pour estimer la STD de FWHM.');

end


%% ================================================================
% 16. Résultats du fit

fit_result.amplitude = A_fit;
fit_result.center = center_fit;
fit_result.sigma = sigma_fit;
fit_result.FWHM = FWHM_mesure;
fit_result.offset = offset_fit;
fit_result.R2 = R2;

fit_result.resnorm = resnorm;
fit_result.residual = residual;
fit_result.exitflag = exitflag;
fit_result.output = output;

fit_result.FWHM_pixels = FWHM_pixels;
fit_result.FWHM_pixels_std = FWHM_error;
fit_result.n_pixels = sum(valid_FWHM);


%% ================================================================
% 17. Affichage du résultat

%% ================================================================
% Affichage du spectre corrigé et du fit

% Grille dense pour afficher le fit de manière lisse
wavenumber_dense = linspace( ...
    min(wavenumber), ...
    max(wavenumber), ...
    2000).';

% Fit évalué sur la grille dense
y_fit_dense = model_fun(p_fit, wavenumber_dense);

figure('Name','Mesure FWHM phase de référence','Color','w');

% Spectre expérimental corrigé
plot(wavenumber, phase_corrected, ...
    'o', ...
    'MarkerSize', 4, ...
    'LineWidth', 1);
hold on;

% Fit lisse
plot(wavenumber_dense, y_fit_dense, ...
    'LineWidth', 2);

xlabel('Wavenumber (cm^{-1})');
ylabel('Intensity (a.u.)');

legend( ...
    'Spectre corrigé', ...
    'Fit gaussien', ...
    'Location','best');

grid on;
box on;

title(sprintf( ...
    'FWHM_{mesure} = %.3f \\pm %.3f cm^{-1}   |   R^2 = %.4f', ...
    FWHM_mesure, ...
    FWHM_error, ...
    R2));


%% ================================================================
% 18. Affichage numérique

fprintf('\n');
fprintf('=============================================\n');
fprintf('     MESURE FWHM PHASE DE REFERENCE\n');
fprintf('=============================================\n');

fprintf('Nombre de pixels ROI phase : %d\n',n_pixels);
fprintf('Pixels avec fit valide     : %d\n',sum(valid_FWHM));

fprintf('\n');
fprintf('Centre spectral : %.4f cm^-1\n',center_fit);
fprintf('Sigma           : %.4f cm^-1\n',sigma_fit);
fprintf('FWHM mesure     : %.4f cm^-1\n',FWHM_mesure);
fprintf('STD FWHM        : %.4f cm^-1\n',FWHM_error);
fprintf('R²              : %.5f\n',R2);

fprintf('\n');
fprintf('RESULTAT : FWHM = %.4f +/- %.4f cm^-1\n', ...
    FWHM_mesure,FWHM_error);

fprintf('=============================================\n');


end