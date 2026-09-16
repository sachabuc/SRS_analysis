function pixel_data = init_pixel_amplitudes( ...
          I_corr, phase_model, wavenumber, ...
          R2_min, threshold_sigma, display_figures)
%INIT_PIXEL_AMPLITUDES Initialise, pixel par pixel, les amplitudes A de
%chaque phase active par moindres carres non-negatifs (lsqnonneg), a
%partir du modele theorique deja construit par MODEL_CARBONATE_PHASES.
%
%   pixel_data = INIT_PIXEL_AMPLITUDES(I_corr, phase_model, wavenumber,
%   R2_min, threshold_sigma, display_figures)
%
%   PRINCIPE
%   A (nu, FWHM) fixes -- ceux deja definis dans phase_model -- le modele
%   spectral est LINEAIRE en les amplitudes A :
%
%       I(wavenumber) = sum_k A_k * G_k(wavenumber) + bruit
%
%   ou G_k est le spectre de la phase k, deja convolue par la reponse
%   instrumentale. La matrice de design M (une colonne par
%   phase active, evaluee aux points de mesure reels) est donc construite
%   UNE SEULE FOIS via PHASEMODELSPECTRUM qui reutilise .sigma_eff
%
%   ENTREES
%     I_corr           : cube hyperspectral [n_y x n_x x n_wn] (ou
%                         [n_ch x n_y x n_x x n_wn] avec n_ch = 1, auquel
%                         cas la dimension canal est retiree
%                         automatiquement), fond continu deja soustrait
%                         (valeur moyenne retiree en pretraitement)
%     phase_model       : structure issue de MODEL_CARBONATE_PHASES
%                         (utilise .use, .nu, .ratio, .sigma_eff, .name)
%     wavenumber        : vecteur de nombre d'onde (cm^-1) des points de
%                         mesure, PAS NECESSAIREMENT TRIE -- cette
%                         fonction le trie et reordonne I_corr en
%                         consequence avant de fitter
%     R2_min            : R^2 minimal pour considerer le pixel comme
%                         correctement explique par le modele lineaire
%                         (defaut 0.8 si omis)
%     threshold_sigma   : facteur multiplicatif applique au bruit estime
%                         (cf. note ci-dessous) sous lequel une
%                         amplitude de phase est consideree comme non
%                         detectee et mise a 0 (defaut 2 si omis)
%     display_figures   : booleen, affiche ou non les cartes obtenues
%                         (defaut true si omis)
%
%   SORTIE
%     pixel_data : structure [n_y x n_x], un element par pixel :
%                    .row, .col     : coordonnees du pixel
%                    .A0            : amplitudes initiales (1 valeur par
%                                     phase de phase_model, dans son
%                                     ordre ; 0 si phase desactivee ou
%                                     sous le seuil de bruit)
%                    .R2            : R^2 du fit lineaire initial
%                    .noise         : bruit estime pour ce pixel (cf. note)
%                    .valid_pixel   : booleen, R2 >= R2_min
%
%   NOTE SUR LE BRUIT (a affiner par la suite)
%   Faute d'une carte de bruit dediee, le bruit est ici estime a partir
%   du residu du fit lineaire lui-meme (ecart-type de I_pixel - M*A),
%   pixel par pixel -- une premiere approximation. Une veritable etude du
%   bruit (acquisitions repetees, bruit electronique/shot noise...)
%   permettrait de remplacer cette heuristique par une estimation plus
%   rigoureuse et d'associer une vraie barre d'erreur a chaque A0 (ex :
%   via la matrice de covariance du fit lineaire).

%% ================================================================
% 0. Valeurs par defaut

if nargin < 4 || isempty(R2_min),          R2_min = 0.8; end
if nargin < 5 || isempty(threshold_sigma), threshold_sigma = 2;   end
if nargin < 6 || isempty(display_figures), display_figures = true; end

%% ================================================================
% 1. Mise en forme des entrees

if ndims(I_corr) == 4
    I_corr = squeeze(I_corr);   % retire une dimension "canal" si presente et = 1
end

[wavenumber, sort_idx] = sort(wavenumber(:).');
I_corr = I_corr(:,:,sort_idx);

[n_y, n_x, n_wn] = size(I_corr);
assert(n_wn == numel(wavenumber), ...
    'Le nombre de points spectraux de I_corr ne correspond pas a wavenumber.');

n_pixels = n_y*n_x;
I_flat   = reshape(permute(I_corr, [3 1 2]), n_wn, n_pixels);

%% ================================================================
% 2. Matrice de design (une colonne par phase active), construite UNE
%    SEULE FOIS a partir de phase_model.sigma_eff (pas de recalcul de la
%    convolution, cf. PHASEMODELSPECTRUM)

active_idx = find([phase_model.use]);
n_active   = numel(active_idx);
n_phases   = numel(phase_model);

% fprintf('active_idx = %f',active_idx)
% fprintf('n_active = %f',n_active)
% fprintf('n_phases = %f',n_phases)

M = zeros(n_wn, n_active);
for a = 1:n_active
    assert(~isempty(phase_model(active_idx(a)).sigma_eff), ...
        'phase_model(%d).sigma_eff est vide : phase_model doit venir de model_carbonate_phases.', ...
        active_idx(a));
    Gk = phaseModelSpectrum(phase_model(active_idx(a)), wavenumber);
    M(:,a) = Gk(:);
end

%% ================================================================
% 3. Boucle sur les pixels : uniquement lsqnonneg (rapide, lineaire)

opts = optimset('lsqnonneg');
opts = optimset(opts, 'Display', 'off');

pixel_data(n_y, n_x).row = [];   % preallocation implicite de la structure

for ip = 1 : n_pixels

    [iy, ix] = ind2sub([n_y, n_x], ip);

    I_pixel = I_flat(:,ip);

    A_active = lsqnonneg(M, I_pixel, opts);

    I_fit = M*A_active;
    resid = I_pixel - I_fit;

    SS_res = sum(resid.^2);
    SS_tot = sum((I_pixel - mean(I_pixel)).^2);
    R2     = 1 - SS_res/max(SS_tot, eps);
     
    noise_estimate = std(resid);
    A_active(A_active < threshold_sigma*noise_estimate) = 0;

    A0 = zeros(n_phases,1);
    A0(active_idx) = A_active;

    pixel_data(iy,ix).row         = iy;
    pixel_data(iy,ix).col         = ix;
    pixel_data(iy,ix).A0          = A0;
    pixel_data(iy,ix).R2          = R2;
    pixel_data(iy,ix).noise       = noise_estimate;
    pixel_data(iy,ix).valid_pixel = (R2 >= R2_min);

    % NB : boucle triviale a paralleliser si besoin (chaque pixel est
    % independant) -- remplacer "for ip = 1:n_pixels" par
    % "parfor ip = 1:n_pixels" si la Parallel Computing Toolbox est
    % disponible et que la taille des images le justifie.

end

%% ================================================================
% 4. Affichage des cartes initiales
%% ================================================================

if display_figures
    plotInitialMaps(pixel_data, phase_model, active_idx);
end

end



