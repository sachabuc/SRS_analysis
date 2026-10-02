
function [I_corr, background_spectrum, noise_map, ...
          noise_global, noise_spectrum] = ...
          estimate_background_noise_roi( ...
          I_raw, wavenumber, x1_s, x1_e, x2_s, x2_e)
%ESTIMATE_BACKGROUND_NOISE_ROI
% Estimation du fond spectral et de la dispersion robuste par canal.
%
% ENTREES
%   I_raw       : cube [n_y x n_x x n_wn]
%   wavenumber  : nombres d'onde
%   x1_s,x1_e   : limites ROI sur la dimension 1
%   x2_s,x2_e   : limites ROI sur la dimension 2
%
% SORTIES
%   I_corr              : cube après soustraction du fond spectral
%   background_spectrum : médiane de la ROI par canal
%   noise_map           : référence globale constante
%   noise_global        : médiane des dispersions robustes par canal
%   noise_spectrum      : dispersion robuste par canal spectral
%
% IMPORTANT :
%   noise_spectrum estime la dispersion spatiale dans la ROI.
%   Elle ne sépare pas le bruit instrumental de l'hétérogénéité
%   spatiale sans hypothèses ou acquisitions supplémentaires.

%% 1. Vérifications

if ndims(I_raw) ~= 3
    error('I_raw doit être un cube 3D [n_y x n_x x n_wn].');
end

wavenumber = wavenumber(:);
[n_y, n_x, n_wn] = size(I_raw);

if numel(wavenumber) ~= n_wn
    error('Le nombre de nombres d''onde ne correspond pas au cube.');
end

if any(~isfinite([x1_s x1_e x2_s x2_e])) || ...
        any([x1_s x1_e x2_s x2_e] ~= ...
            round([x1_s x1_e x2_s x2_e])) || ...
        x1_s < 1 || x1_e > n_y || ...
        x2_s < 1 || x2_e > n_x || ...
        x1_s > x1_e || x2_s > x2_e
    error('Les coordonnées de la ROI sont invalides.');
end

%% 2. Extraction de la ROI

ROI_cube = I_raw(x1_s:x1_e, x2_s:x2_e, :);

ROI_spectra = reshape(ROI_cube, [], n_wn);

%% 3. Fond spectral : médiane spatiale par canal

background_spectrum = median(ROI_spectra, 1, 'omitnan');

%% 4. Dispersion robuste par canal : MAD

noise_spectrum = nan(1, n_wn);

for k = 1:n_wn

    values = ROI_spectra(:, k);
    values = values(isfinite(values));

    if numel(values) >= 2

        med_k = median(values);
        noise_spectrum(k) = ...
            1.4826 * median(abs(values - med_k));

    end
end

%% 5. Référence globale

valid_noise = noise_spectrum(isfinite(noise_spectrum));

if isempty(valid_noise)
    noise_global = NaN;
else
    noise_global = median(valid_noise);
end

% Cette carte est une référence constante, pas une estimation locale.
noise_map = noise_global * ones(n_y, n_x);

%% 6. Soustraction du fond spectral

I_corr = I_raw - reshape( ...
    background_spectrum, 1, 1, n_wn);

end


% function [I_corr, background_spectrum, noise_map, noise_global] = ...
%     estimate_background_noise_roi(I_raw, wavenumber, x1_s, x1_e, x2_s, x2_e)
% %ESTIMATE_BACKGROUND_NOISE_ROI
% % Estime le fond spectral et le niveau de bruit à partir d'une ROI
% % considérée comme dépourvue de signal Raman/SRS.
% %
% % ENTREES
% %   I_raw       : cube [n_y x n_x x n_wn]
% %   wavenumber  : nombres d'onde [n_wn x 1] ou [1 x n_wn]
% %   x1_s,x1_e   : début/fin de la ROI suivant la dimension 1
% %   x2_s,x2_e   : début/fin de la ROI suivant la dimension 2
% %
% % SORTIES
% %   I_corr             : cube corrigé du fond [n_y x n_x x n_wn]
% %   background_spectrum: fond spectral [1 x n_wn]
% %   noise_map          : référence de bruit [n_y x n_x]
% %   noise_global       : niveau de bruit global de la ROI
% %
% % Le fond est estimé comme la médiane de la ROI à chaque nombre d'onde.
% %
% % Le bruit est calculé après retrait du niveau moyen de chaque pixel
% % de la ROI, afin de ne pas confondre les variations spatiales du fond
% % avec du bruit spectral.
% 
% %% ================================================================
% % 1. Mise en forme
% 
% if ndims(I_raw) ~= 3
%     error('I_raw doit être un cube 3D [n_y x n_x x n_wn].');
% end
% 
% wavenumber = wavenumber(:);
% n_wn = size(I_raw,3);
% 
% if numel(wavenumber) ~= n_wn
%     error('Le nombre de nombres d''onde doit correspondre à size(I_raw,3).');
% end
% 
% [n_y,n_x,~] = size(I_raw);
% 
% if x1_s < 1 || x1_e > n_y || x2_s < 1 || x2_e > n_x
%     error('La ROI sort des dimensions de I_raw.');
% end
% 
% %% ================================================================
% % 2. Extraction de la ROI
% 
% ROI_cube = I_raw(x1_s:x1_e, x2_s:x2_e, :);
% 
% n_roi_y = size(ROI_cube,1);
% n_roi_x = size(ROI_cube,2);
% 
% %% ================================================================
% % 3. Estimation du fond spectral
% 
% background_spectrum = zeros(1,n_wn);
% 
% for ii = 1:n_wn
% 
%     ROI = ROI_cube(:,:,ii);
% 
%     % Médiane = robuste aux pixels aberrants
%     background_spectrum(ii) = median(ROI(:),'omitnan');
% 
% end
% 
% %% ================================================================
% % 4. Estimation du bruit à partir de la ROI
% %
% % Chaque pixel de la ROI est recentré sur sa propre moyenne.
% % Cela évite que les différences de niveau entre pixels soient
% % interprétées comme du bruit.
% 
% ROI_spectra = reshape(ROI_cube, ...
%                       n_roi_y*n_roi_x, ...
%                       n_wn);
% 
% % moyenne spectrale propre à chaque pixel
% pixel_mean = mean(ROI_spectra,2,'omitnan');
% 
% % retrait du niveau moyen de chaque pixel
% ROI_centered = ROI_spectra - pixel_mean;
% 
% % bruit global
% noise_global = std(ROI_centered(:),'omitnan');
% 
% %% ================================================================
% % 5. Construction du noise_map
% %
% % Pour l'instant on utilise le même niveau de bruit comme référence
% % pour tous les pixels.
% 
% noise_map = noise_global * ones(n_y,n_x);
% 
% %% ================================================================
% % 6. Soustraction du fond
% 
% I_corr = I_raw;
% 
% for ii = 1:n_wn
% 
%     I_corr(:,:,ii) = I_raw(:,:,ii) - background_spectrum(ii);
% 
% end
% 
% end