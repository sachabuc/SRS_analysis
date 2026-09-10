function [dx, dy, I_ref_crop, I_crop, I_diff, val_max] = find_shift_fft_norm( ...
          I_ref, I, preprocess_mode, mask_ref, mask_I)
%FIND_SHIFT_FFT_NORM Trouve le decalage (dx,dy) entre deux images par
%correlation croisee NORMALISEE (normxcorr2), et extrait la zone commune
%apres recalage.
%
%   [dx, dy, I_ref_crop, I_crop, I_diff, val_max] = FIND_SHIFT_FFT_NORM( ...
%       I_ref, I, preprocess_mode, mask_ref, mask_I)
%
%   dx, dy : decalage (colonnes, lignes) de I par rapport a I_ref.
%   val_max : valeur du pic de correlation normalisee (entre -1 et 1) --
%   un pic faible (< ~0.3-0.4) signifie qu'aucune vraie correspondance
%   structurelle n'a ete trouvee, le decalage renvoye n'est pas fiable.
%
%   PRETRAITEMENT (preprocess_mode, defaut 'raw') : la correlation brute
%   peut etre dominee par des tendances basse frequence (gradient
%   d'intensite du faisceau, fond qui varie doucement) plutot que par la
%   vraie structure de l'echantillon -- surtout genant si les deux
%   acquisitions ont un contraste/fond different (fwhm_instr different).
%     - 'raw'      : aucun pretraitement (comportement d'origine)
%     - 'highpass' : soustrait une version lissee de l'image (retire les
%                    tendances a grande echelle, garde la structure fine)
%     - 'edges'    : norme du gradient (Sobel) -- registre sur les
%                    contours plutot que sur l'intensite
%
%   mask_ref, mask_I : masques logiques optionnels [n_y x n_x] (meme
%   taille que I_ref/I) pour exclure des zones peu fiables (bruit,
%   substrat sans structure) de la correlation. [] = pas de masquage.
%
%   NB : normxcorr2 est utilisee (et non xcorr2) car elle est invariante
%   au contraste/intensite globale de l'image.
 
if nargin < 3 || isempty(preprocess_mode), preprocess_mode = 'raw'; end
if nargin < 4, mask_ref = []; end
if nargin < 5, mask_I   = []; end
 
I_ref_proc = preprocessForRegistration(I_ref, preprocess_mode, mask_ref);
I_proc     = preprocessForRegistration(I,     preprocess_mode, mask_I);
 
%% ================================================================
% Correlation croisee normalisee : I_ref est le "template" cherche dans I
C = normxcorr2(I_ref_proc, I_proc);
 
[val_max, idx] = max(C(:));
[ypeak, xpeak] = ind2sub(size(C), idx);
 
% Decalage (formule standard normxcorr2(template, image) avec template = I_ref)
dx = xpeak - size(I_ref,2);
dy = ypeak - size(I_ref,1);
fprintf('Decalage trouve : dx = %d pixels, dy = %d pixels (pic de correlation = %.3f)\n', dx, dy, val_max);
 
if val_max < 0.4
    warning('find_shift_fft_norm:weakPeak', ...
        ['Pic de correlation faible (%.2f) -- le decalage trouve est peu fiable. ' ...
         'Essayez preprocess_mode=''highpass'' ou ''edges'', un autre canal ' ...
         '(moins sensible a fwhm_instr), ou un masque pour exclure le bruit/substrat.'], val_max);
end
 
figure
imagesc(C); axis image; colorbar;
hold on
plot(xpeak, ypeak, 'or', 'MarkerSize', 10, 'LineWidth', 1.5);
hold off
title(sprintf('Cross-correlation normalisee (pic = %.3f)', val_max));
 
%% ================================================================
% Determination de la zone commune (sur les images ORIGINALES, pas
% pretraitees)
 
[nrows, ncols] = size(I_ref);
 
x_ref_start = max(1, 1-dx);
x_ref_end   = min(ncols, ncols-dx);
y_ref_start = max(1, 1-dy);
y_ref_end   = min(nrows, nrows-dy);
 
x_I_start = max(1, 1+dx);
x_I_end   = min(ncols, ncols+dx);
y_I_start = max(1, 1+dy);
y_I_end   = min(nrows, nrows+dy);
 
I_ref_crop = I_ref(y_ref_start:y_ref_end, x_ref_start:x_ref_end);
I_crop     = I(y_I_start:y_I_end, x_I_start:x_I_end);
 
%% ================================================================
% Soustraction
 
I_diff = I_crop - I_ref_crop;
 
%% ================================================================
% Normalisation pour affichage
 
I_ref_disp = (I_ref_crop - min(I_ref_crop(:))) / ...
             (max(I_ref_crop(:)) - min(I_ref_crop(:)));
I_disp = (I_crop - min(I_crop(:))) / ...
         (max(I_crop(:)) - min(I_crop(:)));
 
m = max(abs(I_diff(:)));
I_diff_disp = I_diff / m;
 
%% ================================================================
% Affichage
 
figure
subplot(1,3,1)
imagesc(I_ref_disp,[0 1]); axis image; colorbar;
title('Image de reference'); colormap(gca,parula);
 
subplot(1,3,2)
imagesc(I_disp,[0 1]); axis image; colorbar;
title(sprintf('Image recalee (dx=%d, dy=%d)',dx,dy)); colormap(gca,parula);
 
subplot(1,3,3)
imagesc(I_diff_disp,[-1 1]); axis image; colorbar;
title('Difference'); colormap(gca,parula);
% Si le recalage est bon, cette carte doit ressembler a du bruit sans
% structure -- des contours/formes encore visibles indiquent un
% decalage incorrect ou incomplet.
 
end
 
 
%% ====================================================================
%  FONCTION LOCALE
%% ====================================================================
 
function Ip = preprocessForRegistration(I, mode, mask)
    I = double(I);
    I(~isfinite(I)) = 0;
    if ~isempty(mask)
        I(~mask) = 0;
    end
 
    switch mode
        case 'raw'
            Ip = I;
        case 'highpass'
            k = max(3, round(max(size(I))/10));
            h = ones(k)/k^2;
            I_lowpass = conv2(I, h, 'same');
            Ip = I - I_lowpass;
        case 'edges'
            hx = [-1 0 1; -2 0 2; -1 0 1];   % Sobel
            hy = hx.';
            Gx = conv2(I, hx, 'same');
            Gy = conv2(I, hy, 'same');
            Ip = sqrt(Gx.^2 + Gy.^2);
        otherwise
            error('find_shift_fft_norm:unknownMode', ...
                'preprocess_mode inconnu : %s (attendu ''raw'', ''highpass'' ou ''edges'')', mode);
    end
end