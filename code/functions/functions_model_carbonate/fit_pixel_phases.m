function pixel_fit = fit_pixel_phases( ...
          I_corr, phase_model, wavenumber, pixel_data, ...
          nu_is_variable, FWHM_is_variable, fwhm_instr, ...
          nu_LB, nu_UB, FWHM_LB, FWHM_UB, ...
          lineshape_type, ci_alpha, display_figures)

%FIT_PIXEL_PHASES Fit non lineaire (lsqcurvefit) des phases du carbonate,
%pixel par pixel, en partant de l'initialisation lineaire de
%INIT_PIXEL_AMPLITUDES.
%
%   pixel_fit = FIT_PIXEL_PHASES(I_corr, phase_model, wavenumber, ...
%       pixel_data, nu_is_variable, FWHM_is_variable, fwhm_instr, ...
%       nu_LB, nu_UB, FWHM_LB, FWHM_UB, lineshape_type, ci_alpha, ...
%       display_figures)
%
%   PRINCIPE
%   Pour chaque phase active, l'amplitude est TOUJOURS libre. La
%   position (nu) et la largeur (FWHM) sont libres. Un terme de
%   fond continu global (background) est ajoute et toujours libre.
%
%   La structure des parametres (quels indices de x correspondent a
%   quoi, et les bornes lb/ub) est IDENTIQUE pour tous les pixels -- elle
%   est donc construite une seule fois (BUILDPARAMMAP), avant la boucle.
%   Seule l'amplitude initiale change d'un pixel a l'autre : elle est
%   reprise de pixel_data(iy,ix).A0 (calculee par lsqnonneg dans
%   INIT_PIXEL_AMPLITUDES), ce qui donne a lsqcurvefit un point de
%   depart deja coherent plutot que 0 ou 1 partout.
%
%
%   ENTREES
%     I_corr            : cube hyperspectral [n_y x n_x x n_wn] (la
%                         dimension canal, si presente et = 1, est
%                         retiree automatiquement)
%     phase_model        : structure issue de MODEL_CARBONATE_PHASES
%     wavenumber         : nombres d'onde (cm^-1)
%     pixel_data         : structure issue de INIT_PIXEL_AMPLITUDES
%                         (utilise .A0)
%     nu_is_variable     : vecteur logique, meme longueur que
%                         phase_model -- position libre (true) ou fixee
%                         (false) pour chaque phase
%     FWHM_is_variable   : idem pour la largeur
%     fwhm_instr           : FWHM (cm^-1) de la reponse instrumentale, DOIT
%                         correspondre a celui utilise pour construire
%                         phase_model
%     nu_LB, nu_UB       : vecteurs [n_phases], bornes MIN et MAX
%                         absolues (cm^-1) autorisees pour nu si
%                         nu_is_variable(k) = true 
%     FWHM_LB, FWHM_UB   : vecteurs [n_phases], bornes MIN et MAX
%                         absolues (cm^-1) autorisees pour FWHM si
%                         FWHM_is_variable(k) = true
%     lineshape_type     : 'gaussian' (seule forme implementee pour
%                         l'instant, defaut 'gaussian')
%     ci_alpha           : niveau pour l'intervalle de confiance sur
%                         chaque amplitude (1-ci_alpha), ex 0.05 -> IC a
%                         95% (defaut 0.05)
%     display_figures    : booleen (defaut true)
%
%   SORTIE
%     pixel_fit : structure [n_y x n_x], un element par pixel :
%                   .row, .col     : coordonnees
%                   .A             : amplitudes ajustees (1 par phase de
%                                    phase_model, 0 si phase desactivee)
%                   .A_CI          : [n_phases x 2], intervalle de
%                                    confiance (borne inf, borne sup) de
%                                    chaque amplitude, base sur le
%                                    Jacobien du fit (NaN si phase
%                                    desactivee)
%                   .A_significant : [n_phases x 1] booleen, true si la
%                                    borne inferieure de A_CI est > 0
%                                    (amplitude significativement
%                                    differente de 0) -- a utiliser pour
%                                    la future segmentation/quantification,
%                                    PAS pour filtrer des pixels ici
%                   .nu            : cell (1 par phase) des positions
%                                    ajustees (ou fixees, recopiees)
%                   .FWHM          : cell (1 par phase) des largeurs
%                                    ajustees (ou fixees, recopiees)
%                   .background    : fond continu ajuste pour ce pixel
%                   .R2            : R^2 du fit non-lineaire
%                   .resnorm       : somme des residus au carre (sortie
%                                    brute de lsqcurvefit)
%                   .exitflag      : code de sortie de lsqcurvefit
%
%   NOTE SUR LES INTERVALLES DE CONFIANCE
%   Calcules par linearisation locale du modele autour de la solution
%   (approche standard des moindres carres non-lineaires), via nlparci
%   (Statistics and Machine Learning Toolbox) si disponible, sinon un
%   repli manuel equivalent mais avec un quantile normal fixe plutot que
%   le quantile de Student exact (COMPUTECONFIDENCEINTERVALS). Cette
%   approximation est moins fiable pour une amplitude ajustee tres pres
%   de sa borne inferieure (lb = 0) -- a garder en tete dans
%   l'interpretation de A_significant.
%
%   NOTE : tous les pixels sont ajustes, y compris ceux marques
%   valid_pixel = false par INIT_PIXEL_AMPLITUDES -- ce champ reste une
%   information de diagnostic, pas un filtre, pour ne pas perdre de
%   donnees a ce stade (cf. discussion sur le bruit).

%% ================================================================
% 0. Valeurs par defaut

if nargin < 8  || isempty(nu_LB)
    nu_LB = arrayfun(@(p) min(p.nu) - 3, phase_model);
end
if nargin < 9  || isempty(nu_UB)
    nu_UB = arrayfun(@(p) max(p.nu) + 3, phase_model);
end
if nargin < 10 || isempty(FWHM_LB)
    FWHM_LB = arrayfun(@(p) 0.5*min(p.FWHM), phase_model);
end
if nargin < 11 || isempty(FWHM_UB)
    FWHM_UB = arrayfun(@(p) 2*max(p.FWHM), phase_model);
end
if nargin < 12 || isempty(lineshape_type),  lineshape_type = 'gaussian'; end
if nargin < 13 || isempty(ci_alpha),        ci_alpha = 0.05;             end
if nargin < 14 || isempty(display_figures), display_figures = true;     end

%% ================================================================
% 1. Mise en forme des entrees (coherent avec INIT_PIXEL_AMPLITUDES)

if ndims(I_corr) == 4
    I_corr = squeeze(I_corr);
end

[wavenumber, sort_idx] = sort(wavenumber(:).');
I_corr = I_corr(:,:,sort_idx);

[n_y, n_x, n_wn] = size(I_corr);
assert(n_wn == numel(wavenumber), ...
    'Le nombre de points spectraux de I_corr ne correspond pas a wavenumber.');
assert(isequal(size(pixel_data), [n_y n_x]), ...
    'pixel_data doit avoir la meme taille spatiale que I_corr.');

n_phases = numel(phase_model);
assert(numel(nu_is_variable) == n_phases && numel(FWHM_is_variable) == n_phases, ...
    'nu_is_variable et FWHM_is_variable doivent avoir %d elements (comme phase_model).', n_phases);
assert(numel(nu_LB) == n_phases && numel(nu_UB) == n_phases && ...
       numel(FWHM_LB) == n_phases && numel(FWHM_UB) == n_phases, ...
    'nu_LB, nu_UB, FWHM_LB et FWHM_UB doivent avoir %d elements (comme phase_model).', n_phases);
assert(all(nu_LB(:) <= nu_UB(:)), 'nu_LB doit etre <= nu_UB pour chaque phase.');
assert(all(FWHM_LB(:) <= FWHM_UB(:)), 'FWHM_LB doit etre <= FWHM_UB pour chaque phase.');

sigma_inst = fwhm2sigma(fwhm_instr);

%% ================================================================
% 2. Structure de parametres (x0, bornes, indices) construite UNE
%    SEULE FOIS -- identique pour tous les pixels sauf l'amplitude

active_idx = find([phase_model.use]);

[param_map, idx_background, x0_template, lb, ub] = buildParamMap( ...
    phase_model, active_idx, nu_is_variable, FWHM_is_variable, ...
    nu_LB, nu_UB, FWHM_LB, FWHM_UB); %tout les paramètres sont rassemblés 
                                     %dans le vecteur ligne "param_map"

opts = optimoptions('lsqcurvefit', 'Display', 'off');

model_fun = @(x, xdata) pixelForwardModel( ...
    x, xdata, param_map, idx_background, sigma_inst, lineshape_type);

%% ================================================================
% 3. Boucle sur les pixels

n_pixels = n_y*n_x;

pixel_fit_lin(n_pixels) = struct('row',[],'col',[],'A',[],'A_CI',[], ...
    'A_significant',[],'nu',[],'FWHM',[],'background',[],'R2',[], ...
    'resnorm',[],'exitflag',[]); % preallocation implicite de la structure

warning('off','MATLAB:nearlySingularMatrix');

disp('lsqcurvefit on each pixel ...');
parfor ip = 1 : n_pixels

    [iy, ix] = ind2sub([n_y, n_x], ip);

    I_pixel = squeeze(I_corr(iy,ix,:));
    I_pixel = I_pixel(:);
    I_pixel = I_pixel';

    x0 = x0_template;
    A0_pixel = pixel_data(iy,ix).A0;
    for a = 1:numel(param_map)
        x0(param_map(a).idx_A) = max(A0_pixel(param_map(a).k), 0);
    end

    % disp(size(wavenumber));
    % disp(size(I_pixel));
    % disp(size(model_fun(x0,wavenumber)));

    [x_fit, resnorm, residual, exitflag, ~, ~, jacobian] = lsqcurvefit( ...
        model_fun, x0, wavenumber, I_pixel, lb, ub, opts);

    SS_tot = sum((I_pixel - mean(I_pixel)).^2);
    R2 = 1 - resnorm/max(SS_tot, eps);

    ci = computeConfidenceIntervals(x_fit, residual, jacobian, ci_alpha);

    A_fit         = zeros(n_phases,1);
    A_CI          = nan(n_phases,2);
    A_significant = false(n_phases,1);
    nu_fit        = cell(n_phases,1);
    FWHM_fit      = cell(n_phases,1);

    for a = 1:numel(param_map)
        k = param_map(a).k;
        A_fit(k)         = x_fit(param_map(a).idx_A);
        A_CI(k,:)        = ci(param_map(a).idx_A,:);
%         A_significant(k) = 1;
        A_significant(k) = A_CI(k,1) > 0;   % borne inferieure de l'IC > 0
        

        if ~isempty(param_map(a).idx_nu)
            nu_fit{k} = reshape(x_fit(param_map(a).idx_nu), 1, []);
        else
            nu_fit{k} = param_map(a).nu_fixed;
        end

        if ~isempty(param_map(a).idx_FWHM)
            FWHM_fit{k} = reshape(x_fit(param_map(a).idx_FWHM), 1, []);
        else
            FWHM_fit{k} = param_map(a).FWHM_fixed;
        end
    end

pixel_fit_lin(ip) = struct('row',iy,'col',ix,'A',A_fit,'A_CI',A_CI, ...
    'A_significant',A_significant,'nu',{nu_fit},'FWHM',{FWHM_fit}, ...
    'background',x_fit(idx_background),'R2',R2,'resnorm',resnorm, ...
    'exitflag',exitflag);

    % NB : boucle parallelisable (chaque pixel est independant) --
    % remplacer "for ip = 1:n_pixels" par "parfor ip = 1:n_pixels" si la
    % Parallel Computing Toolbox est disponible. lsqcurvefit etant plus
    % couteux que lsqnonneg, c'est ici que parfor est le plus utile.

end
disp('lsqcurvefit ended')

pixel_fit = reshape(pixel_fit_lin, n_y, n_x);

%% ================================================================
% 4. Affichage
%% ================================================================

if display_figures
    plotFitMaps(pixel_fit, phase_model, active_idx);

    
end

end

