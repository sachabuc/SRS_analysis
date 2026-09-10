
function [I_corr, background_map, noise_map] = estimate_background_noise( ...
          imgs, wavenumber, off_resonance_wn, low_intensity_fraction, background_roi_mask)
%ESTIMATE_BACKGROUND_NOISE Fond continu et bruit par pixel, a partir soit
%de nombres d'onde hors resonance fournis, soit des points de plus
%faible intensite du spectre de chaque pixel. Le bruit peut en plus etre
%recalcule a partir d'un ROI de substrat connu (plus fiable).
%
%   [I_corr, background_map, noise_map] = ESTIMATE_BACKGROUND_NOISE( ...
%       imgs, wavenumber, off_resonance_wn, low_intensity_fraction, ...
%       background_roi_mask)
%
%   FOND CONTINU -- DEUX MODES (au choix, selon off_resonance_wn),
%   TOUJOURS PAR PIXEL (le niveau de fond peut varier spatialement) :
%     - off_resonance_wn NON VIDE : les MEMES points de mesure (les plus
%       proches des valeurs fournies) sont utilises pour tous les
%       pixels -- pertinent si vous savez ou se trouvent des points sans
%       resonance dans votre fenetre spectrale.
%     - off_resonance_wn VIDE ([]) : pour CHAQUE pixel independamment,
%       les low_intensity_fraction (defaut 25%) points de plus faible
%       intensite de SON PROPRE spectre sont utilises. S'adapte pixel
%       par pixel, mais suppose qu'au moins cette fraction de points
%       n'est pas dominee par un vrai signal de phase -- attention si
%       une phase tres large (ex ACC, FWHM=20) couvre une grande partie
%       de votre fenetre de mesure : le fond serait alors surestime.
%
%   BRUIT -- si background_roi_mask est fourni (masque logique [n_y x n_x]
%   de pixels connus sans signal de phase), le bruit est recalcule a
%   partir de CE ROI plutot que par pixel : chaque spectre du ROI est
%   d'abord recentre sur sa propre moyenne (pour ne pas confondre une
%   variation spatiale du fond avec du bruit), puis un seul ecart-type
%   GLOBAL est calcule sur l'ensemble des points recentres (tous pixels
%   du ROI x tous nombres d'onde confondus) -- plus d'echantillon, donc
%   plus stable qu'une estimation pixel par pixel, et surtout garanti
%   sans contamination par du vrai signal. noise_map est alors uniforme
%   (meme valeur partout). Si background_roi_mask est vide ([], defaut),
%   le bruit reste estime par pixel comme avant (ecart-type des points
%   utilises pour le fond).
%
%   Pour chaque pixel, hors mode ROI : background = moyenne des points
%   selectionnes, noise = ecart-type des memes points. I_corr = imgs -
%   background, soustrait pixel par pixel sur tout le spectre.
%
%   ENTREES
%     imgs                   : cube brut [n_y x n_x x n_wn] (dimension
%                              canal, si presente et = 1, retiree
%                              automatiquement)
%     wavenumber               : nombres d'onde (cm^-1) des points de
%                              mesure, pas necessairement tries
%     off_resonance_wn          : vecteur de nombres d'onde consideres
%                              hors resonance (approches par le point de
%                              mesure le plus proche), ou [] pour le
%                              mode automatique
%     low_intensity_fraction    : fraction de points de plus faible
%                              intensite en mode automatique (defaut 0.25)
%     background_roi_mask        : masque logique [n_y x n_x] de pixels
%                              de substrat/sans signal, ou [] (defaut)
%                              pour garder le bruit par pixel
%
%   SORTIES
%     I_corr         : cube corrige du fond, [n_y x n_x x n_wn]
%     background_map : [n_y x n_x], fond estime par pixel
%     noise_map      : [n_y x n_x], bruit estime (uniforme si ROI fourni,
%                     par pixel sinon)

if nargin < 4 || isempty(low_intensity_fraction)
    low_intensity_fraction = 0.25;
end
if nargin < 5
    background_roi_mask = [];
end

%% ================================================================
% 1. Mise en forme

if ndims(imgs) == 4
    imgs = squeeze(imgs);
end

[wavenumber, sort_idx] = sort(wavenumber(:).');
imgs = imgs(:,:,sort_idx);

n_wn = size(imgs, 3);

%% ================================================================
% 2. Selection des points "fond" + calcul fond/bruit -- vectorise,
%    aucune boucle pixel

if ~isempty(off_resonance_wn)
    idx_bg = nan(size(off_resonance_wn));
    for j = 1:numel(off_resonance_wn)
        [~, idx_bg(j)] = min(abs(wavenumber - off_resonance_wn(j)));
    end
    idx_bg = unique(idx_bg);

    bg_points      = imgs(:,:,idx_bg);
    background_map = mean(bg_points, 3);
    noise_map      = std(bg_points, 0, 3);
else
    n_low = max(round(low_intensity_fraction*n_wn), 1);

    sorted_imgs = sort(imgs, 3, 'ascend');
    low_points  = sorted_imgs(:,:,1:n_low);

    background_map = mean(low_points, 3);
    noise_map       = std(low_points, 0, 3);
end

%% ================================================================
% 3. Bruit recalcule a partir du ROI substrat, si fourni (remplace
%    noise_map par une valeur globale unique, plus fiable qu'une
%    estimation par pixel)

if ~isempty(background_roi_mask)
    assert(isequal(size(background_roi_mask), size(imgs,[1 2])), ...
        'background_roi_mask doit avoir la taille [n_y x n_x] de imgs.');

    [n_y, n_x, ~] = size(imgs);
    I_flat_roi = reshape(permute(imgs, [3 1 2]), n_wn, n_y*n_x).';
    roi_spectra = I_flat_roi(background_roi_mask(:), :);          % [n_roi x n_wn]

    roi_centered = roi_spectra - mean(roi_spectra, 2);             % retire le niveau propre a chaque pixel du ROI
    global_noise = std(roi_centered(:));

    noise_map = global_noise * ones(n_y, n_x);
end

%% ================================================================
% 4. Soustraction du fond (diffusion implicite sur la 3e dimension)

I_corr = imgs - background_map;

end
