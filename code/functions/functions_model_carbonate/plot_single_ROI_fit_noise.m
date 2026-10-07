
function result = plot_single_ROI_fit_noise( ...
    I_corr, wavenumber, phase_model, phase_map, roi, ...
    fwhm_instr, active_idx, phase_colors, params, ...
    background_spectrum, noise_spectrum)

%PLOT_SINGLE_ROI_FIT
%
% Ajuste le spectre moyen d'un ROI avec le modèle de phases carbonate
% utilisé dans FIT_PIXEL_PHASES, puis affiche :
%
%   FIGURE 1 :
%       - spectre expérimental moyen
%       - fit total
%       - background de référence
%
%   FIGURE 2 :
%       - spectre expérimental normalisé
%       - composantes individuelles des phases
%       - somme des phases ajustées
%
% IMPORTANT :
%
%   1) Le fit est réalisé sur I_corr, donc le background mesuré dans
%      background_spectrum n'est PAS réinjecté dans le modèle.
%
%   2) background_spectrum est uniquement affiché comme référence.
%
%   3) Un UNIQUE facteur de normalisation est utilisé pour :
%         - données expérimentales
%         - fit total
%         - composantes de phases
%         - background
%
%   4) Les figures couvrent TOUT l'intervalle de wavenumber fourni.
%      params.nu_interval n'est PAS utilisé pour limiter les figures.
%
%   5) La reconstruction des composantes utilise exactement la même
%      convolution instrumentale que le modèle de FIT_PIXEL_PHASES.
%
% SORTIE :
%
%   result.name
%   result.roi
%   result.mean_spectrum
%   result.std_spectrum
%   result.sum_spectrum
%   result.A_fit
%   result.nu_fit
%   result.FWHM_fit
%   result.background_fit
%   result.R2
%   result.resnorm
%   result.wavenumber_theoretical
%   result.fit_total
%   result.components
%   result.norm_factor
%   result.mean_spectrum_norm
%   result.fit_total_norm
%   result.components_norm
%   result.background_norm
%   result.max_ACC
%   result.max_ARA
%   result.ratio_ACC_ARA
%   result.noise_analysis
%
% ========================================================================


%% ========================================================================
% 0. PARAMETRES / SWITCHES
% ========================================================================

% -------------------------------------------------------------------------
% Affichage
% -------------------------------------------------------------------------

display_figures = true;

% Nombre de points de la grille théorique
n_theoretical_points = 1000;


% -------------------------------------------------------------------------
% Analyse du bruit
% -------------------------------------------------------------------------

use_noise_spectral = true;

use_snr_phases = true;

use_residual_noise = true;

use_amplitude_ci = false;

use_background_analysis = true;


% -------------------------------------------------------------------------
% Région utilisée pour estimer le bruit spectral.
%
% IMPORTANT :
% Cette région doit être une région SANS bande carbonate.
%
% A adapter à ton spectre.
% -------------------------------------------------------------------------

noise_range = [1120 1150];

MAD_factor = 1.4826;

noise_threshold_sigma = 3;

CI_level = 0.95;


%% ========================================================================
% 1. MISE EN FORME DES ENTREES
% ========================================================================

if ndims(I_corr) == 4

    I_corr = squeeze(I_corr);

end


if ndims(I_corr) ~= 3

    error( ...
        'I_corr doit être un cube [n_y x n_x x n_wn].');

end


% -------------------------------------------------------------------------
% Wavenumber en colonne
% -------------------------------------------------------------------------

wavenumber = wavenumber(:);


% -------------------------------------------------------------------------
% Tri spectral
% -------------------------------------------------------------------------

[wavenumber, sort_idx] = sort(wavenumber);


I_corr = I_corr(:,:,sort_idx);


[n_y,n_x,n_wn] = size(I_corr);


if n_wn ~= numel(wavenumber)

    error( ...
        ['Le nombre de points spectraux de I_corr (%d) ne correspond ', ...
         'pas à wavenumber (%d).'], ...
        n_wn, ...
        numel(wavenumber));

end


% -------------------------------------------------------------------------
% Vérification ROI
% -------------------------------------------------------------------------

if numel(roi) ~= 4

    error( ...
        'roi doit être [row_start row_end col_start col_end].');

end


row_start = roi(1);
row_end   = roi(2);

col_start = roi(3);
col_end   = roi(4);


if row_start < 1 || row_end > n_y || row_start > row_end

    error('Limites de lignes du ROI invalides.');

end


if col_start < 1 || col_end > n_x || col_start > col_end

    error('Limites de colonnes du ROI invalides.');

end


%% ========================================================================
% 2. NOM DU ROI
% ========================================================================

if isfield(params,'name') && ~isempty(params.name)

    roi_name = char(params.name);

else

    roi_name = sprintf( ...
        'ROI_r%d-%d_c%d-%d', ...
        row_start, ...
        row_end, ...
        col_start, ...
        col_end);

end


%% ========================================================================
% 3. EXTRACTION DU ROI
% ========================================================================

I_roi = I_corr( ...
    row_start:row_end, ...
    col_start:col_end, :);


n_pixels_roi = ...
    (row_end-row_start+1) * ...
    (col_end-col_start+1);


% -------------------------------------------------------------------------
% [pixels x wavenumber]
% -------------------------------------------------------------------------

I_roi_2D = reshape( ...
    I_roi, ...
    n_pixels_roi, ...
    n_wn);


%% ========================================================================
% 4. SPECTRE EXPERIMENTAL
% ========================================================================

sum_spectrum = sum( ...
    I_roi_2D, ...
    1, ...
    'omitnan');

sum_spectrum = sum_spectrum(:);


mean_spectrum = mean( ...
    I_roi_2D, ...
    1, ...
    'omitnan');

mean_spectrum = mean_spectrum(:);


std_spectrum = std( ...
    I_roi_2D, ...
    0, ...
    1, ...
    'omitnan');

std_spectrum = std_spectrum(:);


%% ========================================================================
% 5. VERIFICATION DES PHASES ACTIVES
% ========================================================================

if isempty(active_idx)

    active_idx = find([phase_model.use]);

end


active_idx = active_idx(:).';


n_active = numel(active_idx);


if n_active == 0

    error('Aucune phase active dans active_idx.');

end


n_phases = numel(phase_model);


%% ========================================================================
% 6. PARAMETRES DE FIT
%
% On reprend la même logique que FIT_PIXEL_PHASES :
%
% Pour chaque phase active :
%
%   A
%   nu       si nu_is_variable
%   FWHM     si FWHM_is_variable
%
% puis :
%
%   background
%
% ========================================================================


% -------------------------------------------------------------------------
% Paramètres variables
% -------------------------------------------------------------------------

if isfield(params,'nu_is_variable')

    nu_is_variable = params.nu_is_variable;

else

    nu_is_variable = false(1,n_phases);

end


if isfield(params,'FWHM_is_variable')

    FWHM_is_variable = params.FWHM_is_variable;

else

    FWHM_is_variable = false(1,n_phases);

end


% -------------------------------------------------------------------------
% Bornes
% -------------------------------------------------------------------------

if isfield(params,'nu_LB')

    nu_LB = params.nu_LB;

else

    nu_LB = -Inf(1,n_phases);

end


if isfield(params,'nu_UB')

    nu_UB = params.nu_UB;

else

    nu_UB = Inf(1,n_phases);

end


if isfield(params,'FWHM_LB')

    FWHM_LB = params.FWHM_LB;

else

    FWHM_LB = zeros(1,n_phases);

end


if isfield(params,'FWHM_UB')

    FWHM_UB = params.FWHM_UB;

else

    FWHM_UB = Inf(1,n_phases);

end


% -------------------------------------------------------------------------
% Type de ligne
% -------------------------------------------------------------------------

if isfield(params,'lineshape_type') && ...
        ~isempty(params.lineshape_type)

    lineshape_type = params.lineshape_type;

else

    lineshape_type = 'gaussian';

end


%% ========================================================================
% 7. REPONSE INSTRUMENTALE
% ========================================================================

sigma_instr = ...
    fwhm2sigma(fwhm_instr);


%% ========================================================================
% 8. CONSTRUCTION DU VECTEUR DE PARAMETRES
% ========================================================================

[param_map, ...
 idx_background, ...
 x0_template, ...
 lb, ...
 ub] = buildParamMap( ...
    phase_model, ...
    active_idx, ...
    nu_is_variable, ...
    FWHM_is_variable, ...
    nu_LB, ...
    nu_UB, ...
    FWHM_LB, ...
    FWHM_UB);


%% ========================================================================
% 9. INITIALISATION DES AMPLITUDES
% ========================================================================

% -------------------------------------------------------------------------
% Initialisation simple à partir du maximum du spectre
% -------------------------------------------------------------------------

signal_range = ...
    max(sum_spectrum) - min(sum_spectrum);


if ~isfinite(signal_range) || signal_range <= 0

    signal_range = max(abs(sum_spectrum));

end


if ~isfinite(signal_range) || signal_range <= 0

    signal_range = 1;

end


for a = 1:numel(param_map)

    x0_template(param_map(a).idx_A) = ...
        signal_range;

end


% -------------------------------------------------------------------------
% Background initial
% -------------------------------------------------------------------------

x0_template(idx_background) = ...
    median(sum_spectrum);


%% ========================================================================
% 10. MODELE DIRECT
% ========================================================================

model_fun = @(x,xdata) ...
    pixelForwardModel( ...
        x, ...
        xdata, ...
        param_map, ...
        idx_background, ...
        sigma_instr, ...
        lineshape_type);


%% ========================================================================
% 11. FIT DU SPECTRE DU ROI
% ========================================================================

opts = optimoptions( ...
    'lsqcurvefit', ...
    'Display','off');


[x_fit, ...
 resnorm, ...
 residual, ...
 exitflag, ...
 ~, ...
 ~, ...
 jacobian] = ...
    lsqcurvefit( ...
        model_fun, ...
        x0_template, ...
        wavenumber, ...
        sum_spectrum, ...
        lb, ...
        ub, ...
        opts);


%% ========================================================================
% 12. QUALITE DU FIT
% ========================================================================

SS_tot = sum( ...
    (sum_spectrum - mean(sum_spectrum)).^2, ...
    'omitnan');


R2 = ...
    1 - resnorm/max(SS_tot,eps);


%% ========================================================================
% 13. EXTRACTION DES PARAMETRES
% ========================================================================

A_fit = zeros(n_phases,1);

A_CI = nan(n_phases,2);

A_significant = false(n_phases,1);

nu_fit = cell(n_phases,1);

FWHM_fit = cell(n_phases,1);


for a = 1:numel(param_map)

    k = param_map(a).k;


    % ------------------------------------------------------------
    % Amplitude
    % ------------------------------------------------------------

    A_fit(k) = ...
        x_fit(param_map(a).idx_A);


    % ------------------------------------------------------------
    % Position
    % ------------------------------------------------------------

    if ~isempty(param_map(a).idx_nu)

        nu_fit{k} = ...
            reshape( ...
                x_fit(param_map(a).idx_nu), ...
                1, []);

    else

        nu_fit{k} = ...
            param_map(a).nu_fixed;

    end


    % ------------------------------------------------------------
    % FWHM
    % ------------------------------------------------------------

    if ~isempty(param_map(a).idx_FWHM)

        FWHM_fit{k} = ...
            reshape( ...
                x_fit(param_map(a).idx_FWHM), ...
                1, []);

    else

        FWHM_fit{k} = ...
            param_map(a).FWHM_fixed;

    end

end


%% ========================================================================
% 14. INTERVALLES DE CONFIANCE SUR LES AMPLITUDES
% ========================================================================

if use_amplitude_ci

    try

        ci = nlparci( ...
            x_fit, ...
            residual, ...
            'jacobian', ...
            jacobian, ...
            'alpha',1-CI_level);


        for a = 1:numel(param_map)

            k = param_map(a).k;

            idx_A = param_map(a).idx_A;

            A_CI(k,:) = ci(idx_A,:);

            A_significant(k) = ...
                ci(idx_A,1) > 0;

        end


    catch

        warning( ...
            ['Impossible de calculer les intervalles de confiance ', ...
             'avec nlparci.']);

    end

end


%% ========================================================================
% 15. FIT SUR LA GRILLE EXPERIMENTALE
% ========================================================================

fit_total_sum = ...
    model_fun( ...
        x_fit, ...
        wavenumber);


% -------------------------------------------------------------------------
% Passage en intensité MOYENNE PAR PIXEL
%
% Le fit a été réalisé sur la SOMME du ROI.
% -------------------------------------------------------------------------

fit_total = ...
    fit_total_sum / n_pixels_roi;


%% ========================================================================
% 16. GRILLE THEORIQUE
%
% TOUT l'intervalle spectral.
%
% Il n'y a volontairement PAS de params.nu_interval ici.
% ========================================================================

wavenumber_theoretical = linspace( ...
    min(wavenumber), ...
    max(wavenumber), ...
    n_theoretical_points);


wavenumber_theoretical = ...
    wavenumber_theoretical(:);


%% ========================================================================
% 17. RECONSTRUCTION DES COMPOSANTES DE PHASE
% ========================================================================

components_sum = ...
    zeros( ...
        n_theoretical_points, ...
        n_active);


for a = 1:n_active

    k = active_idx(a);


    % ------------------------------------------------------------
    % Amplitude
    % ------------------------------------------------------------

    A = A_fit(k);


    if A <= 0

        continue;

    end


    % ------------------------------------------------------------
    % Paramètres ajustés
    % ------------------------------------------------------------

    nu_k = nu_fit{k};

    FWHM_k = FWHM_fit{k};


    % ------------------------------------------------------------
    % Ratios des raies
    % ------------------------------------------------------------

    ratio_k = phase_model(k).ratio;

    ratio_k = ratio_k(:).';


    if isempty(ratio_k)

        ratio_k = ones(size(nu_k));

    end


    if numel(ratio_k) ~= numel(nu_k)

        error( ...
            ['La phase %s possède %d positions mais %d ratios.'], ...
            phase_model(k).name, ...
            numel(nu_k), ...
            numel(ratio_k));

    end


    ratio_k = ...
        ratio_k / sum(ratio_k);


    % ------------------------------------------------------------
    % Construction de la phase
    % ------------------------------------------------------------

    G_phase = ...
        zeros( ...
            size(wavenumber_theoretical));


    for p = 1:numel(nu_k)

        sigma_phase = ...
            fwhm2sigma(FWHM_k(p));


        % --------------------------------------------------------
        % CONVOLUTION ANALYTIQUE
        %
        % sigma_eff^2 =
        % sigma_phase^2 + sigma_instr^2
        % --------------------------------------------------------

        sigma_eff = ...
            sqrt( ...
                sigma_phase.^2 + ...
                sigma_instr.^2);


        G_phase = ...
            G_phase + ...
            ratio_k(p) .* ...
            lineShapeArea( ...
                wavenumber_theoretical, ...
                nu_k(p), ...
                sigma_eff, ...
                lineshape_type);

    end


    % ------------------------------------------------------------
    % Contribution de la phase
    %
    % Sur l'échelle de SOMME
    % ------------------------------------------------------------

    components_sum(:,a) = ...
        A .* G_phase;

end


%% ========================================================================
% 18. PASSAGE DES COMPOSANTES EN MOYENNE PAR PIXEL
% ========================================================================

components = ...
    components_sum / n_pixels_roi;


%% ========================================================================
% 19. SOMME DES PHASES
% ========================================================================

total_phase_fit = ...
    sum(components,2,'omitnan');


%% ========================================================================
% 20. BACKGROUND DU FIT
% ========================================================================

background_fit_sum = ...
    x_fit(idx_background);


background_fit = ...
    background_fit_sum / n_pixels_roi;


%% ========================================================================
% 21. FACTEUR DE NORMALISATION UNIQUE
%
% IMPORTANT :
%
% Le facteur est calculé à partir du SIGNAL DE PHASE ajusté.
%
% Il est ensuite appliqué à TOUT :
%
%   experimental
%   fit
%   components
%   background
%
% ========================================================================

norm_factor = ...
    max( ...
        total_phase_fit, ...
        [], ...
        'omitnan');


if ~isfinite(norm_factor) || norm_factor <= 0

    warning( ...
        ['Le maximum du signal de phase ajusté est invalide. ', ...
         'norm_factor = 1.']);

    norm_factor = 1;

end


%% ========================================================================
% 22. NORMALISATION DE TOUTES LES COURBES
% ========================================================================

% -------------------------------------------------------------------------
% EXPERIMENTAL
% -------------------------------------------------------------------------

mean_spectrum_norm = ...
    mean_spectrum / norm_factor;


std_spectrum_norm = ...
    std_spectrum / norm_factor;


% -------------------------------------------------------------------------
% FIT TOTAL
% -------------------------------------------------------------------------

fit_total_norm = ...
    fit_total / norm_factor;


% -------------------------------------------------------------------------
% COMPOSANTES
% -------------------------------------------------------------------------

components_norm = ...
    components / norm_factor;


% -------------------------------------------------------------------------
% SOMME DES PHASES
% -------------------------------------------------------------------------

total_phase_fit_norm = ...
    total_phase_fit / norm_factor;


% -------------------------------------------------------------------------
% BACKGROUND AJUSTE
% -------------------------------------------------------------------------

background_fit_norm = ...
    background_fit / norm_factor;


%% ========================================================================
% 23. BACKGROUND DE REFERENCE
%
% background_spectrum provient de l'ROI sans échantillon.
%
% Il est supposé être exprimé dans les mêmes unités que I_corr.
%
% IMPORTANT :
% Il ne doit PAS être réinjecté dans le fit puisque I_corr est déjà
% corrigé du background.
% ========================================================================

background_reference = [];


if ~isempty(background_spectrum)

    background_reference = ...
        background_spectrum(:);


    % ------------------------------------------------------------
    % Vérification dimensionnelle
    % ------------------------------------------------------------

    if numel(background_reference) ~= n_wn

        error( ...
            ['background_spectrum contient %d points alors que ', ...
             'wavenumber en contient %d.'], ...
            numel(background_reference), ...
            n_wn);

    end


    % ------------------------------------------------------------
    % Même tri spectral
    % ------------------------------------------------------------

    background_reference = ...
        background_reference(sort_idx);


    % ------------------------------------------------------------
    % NORMALISATION AVEC EXACTEMENT LE MEME FACTEUR
    % ------------------------------------------------------------

    background_reference_norm = ...
        background_reference / norm_factor;

else

    background_reference_norm = [];

end


%% ========================================================================
% 24. ANALYSE DU BRUIT
% ========================================================================

noise_analysis = struct();


noise_analysis.enabled = false;


%% ------------------------------------------------------------------------
% 24.1 Bruit spectral
% -------------------------------------------------------------------------

if use_noise_spectral && ~isempty(noise_spectrum)

    noise_spectrum_vec = ...
        noise_spectrum(:);


    if numel(noise_spectrum_vec) ~= n_wn

        warning( ...
            ['noise_spectrum ne possède pas le même nombre de points ', ...
             'que wavenumber. Analyse spectrale du bruit désactivée.']);

    else

        noise_spectrum_vec = ...
            noise_spectrum_vec(sort_idx);


        idx_noise = ...
            wavenumber >= noise_range(1) & ...
            wavenumber <= noise_range(2);


        if any(idx_noise)

            noise_sigma_per_pixel = ...
                median( ...
                    noise_spectrum_vec(idx_noise), ...
                    'omitnan');


        else

            noise_sigma_per_pixel = ...
                median( ...
                    noise_spectrum_vec, ...
                    'omitnan');

        end


        % --------------------------------------------------------
        % Bruit sur une somme de N pixels
        %
        % Approximation :
        %
        % sigma_sum ≈ sqrt(N) sigma_pixel
        %
        % --------------------------------------------------------

        noise_sigma_sum = ...
            sqrt(n_pixels_roi) .* ...
            noise_sigma_per_pixel;


        % --------------------------------------------------------
        % Conversion en moyenne par pixel
        % --------------------------------------------------------

        noise_sigma_mean = ...
            noise_sigma_per_pixel;


        % --------------------------------------------------------
        % Normalisation
        % --------------------------------------------------------

        noise_sigma_mean_norm = ...
            noise_sigma_mean / norm_factor;


        noise_analysis.enabled = true;

        noise_analysis.noise_spectrum = ...
            noise_spectrum_vec;

        noise_analysis.noise_range = ...
            noise_range;

        noise_analysis.noise_sigma_per_pixel = ...
            noise_sigma_per_pixel;

        noise_analysis.noise_sigma_sum = ...
            noise_sigma_sum;

        noise_analysis.noise_sigma_mean = ...
            noise_sigma_mean;

        noise_analysis.noise_sigma_mean_norm = ...
            noise_sigma_mean_norm;

    end

end


%% ------------------------------------------------------------------------
% 24.2 SNR des phases
% -------------------------------------------------------------------------

if use_snr_phases && ...
        isfield(noise_analysis,'noise_sigma_mean') && ...
        isfinite(noise_analysis.noise_sigma_mean)

    noise_sigma = ...
        noise_analysis.noise_sigma_mean;


    SNR_phases = nan(n_active,1);


    for a = 1:n_active

        phase_peak = ...
            max( ...
                components(:,a), ...
                [], ...
                'omitnan');


        SNR_phases(a) = ...
            phase_peak / max(noise_sigma,eps);

    end


    noise_analysis.SNR_phases = ...
        SNR_phases;

end


%% ------------------------------------------------------------------------
% 24.3 Bruit des résidus
% -------------------------------------------------------------------------

if use_residual_noise

    residual_mean = ...
        mean_spectrum - fit_total;


    residual_sigma = ...
        1.4826 .* ...
        median( ...
            abs( ...
                residual_mean - ...
                median(residual_mean,'omitnan')), ...
            'omitnan');


    noise_analysis.residual = ...
        residual_mean;


    noise_analysis.residual_sigma = ...
        residual_sigma;


    if isfield(noise_analysis,'noise_sigma_mean') && ...
            noise_analysis.noise_sigma_mean > 0

        noise_analysis.residual_to_noise = ...
            residual_sigma / ...
            noise_analysis.noise_sigma_mean;

    else

        noise_analysis.residual_to_noise = NaN;

    end

end


%% ------------------------------------------------------------------------
% 24.4 Analyse du background
% -------------------------------------------------------------------------

if use_background_analysis

    noise_analysis.background_fit = ...
        background_fit;


    noise_analysis.background_fit_norm = ...
        background_fit_norm;


    noise_analysis.background_reference = ...
        background_reference;


    noise_analysis.background_reference_norm = ...
        background_reference_norm;


    if ~isempty(background_reference)

        noise_analysis.background_reference_peak = ...
            max(abs(background_reference),[],'omitnan');


        noise_analysis.background_reference_peak_norm = ...
            max(abs(background_reference_norm),[],'omitnan');

    else

        noise_analysis.background_reference_peak = NaN;

        noise_analysis.background_reference_peak_norm = NaN;

    end

end


%% ========================================================================
% 25. HAUTEURS ACC / ARA
% ========================================================================

%% ================================================================
% Identification ACC / ARA dans les phases actives
% ================================================================

idx_ACC = [];
idx_ARA = [];

for j = 1:numel(active_idx)

    k = active_idx(j);

    phase_name = string(phase_model(k).name);

    if contains(phase_name, "ACC", 'IgnoreCase', true)
        idx_ACC = j;

    elseif contains(phase_name, "aragonite", 'IgnoreCase', true) || ...
           strcmpi(phase_name, "ARA")
        idx_ARA = j;
    end

end


% -------------------------------------------------------------------------
% ACC
% -------------------------------------------------------------------------

if ~isempty(idx_ACC)

    max_ACC = ...
        max( ...
            components_norm(:,idx_ACC), ...
            [], ...
            'omitnan');

else

    max_ACC = NaN;

end


% -------------------------------------------------------------------------
% ARA
% -------------------------------------------------------------------------

if ~isempty(idx_ARA)

    max_ARA = ...
        max( ...
            components_norm(:,idx_ARA), ...
            [], ...
            'omitnan');

else

    max_ARA = NaN;

end


% -------------------------------------------------------------------------
% Ratio
% -------------------------------------------------------------------------

if isfinite(max_ACC) && ...
        isfinite(max_ARA) && ...
        max_ARA > 0

    ratio_ACC_ARA = ...
        max_ACC / max_ARA;

else

    ratio_ACC_ARA = NaN;

end


%% ========================================================================
% 26. FIGURE 1
%
% EXPERIMENTAL + FIT TOTAL + BACKGROUND
%
% IMPORTANT :
% TOUT LE SPECTRE est affiché.
% ========================================================================

if display_figures

    figure( ...
        'Color','white', ...
        'Position',[100 100 1100 650]);


    hold on;
    box on;


    % ------------------------------------------------------------
    % Données expérimentales
    % ------------------------------------------------------------

    plot( ...
        wavenumber, ...
        mean_spectrum_norm, ...
        'k-', ...
        'LineWidth',1.3, ...
        'DisplayName','Experimental');


    % ------------------------------------------------------------
    % Bande +/- sigma expérimentale
    % ------------------------------------------------------------

    upper = ...
        mean_spectrum_norm + ...
        std_spectrum_norm;


    lower = ...
        mean_spectrum_norm - ...
        std_spectrum_norm;


    fill( ...
        [wavenumber; flipud(wavenumber)], ...
        [upper; flipud(lower)], ...
        [0.5 0.5 0.5], ...
        'FaceAlpha',0.15, ...
        'EdgeColor','none', ...
        'HandleVisibility','off');


    % ------------------------------------------------------------
    % Fit total
    % ------------------------------------------------------------

    plot( ...
        wavenumber, ...
        fit_total_norm, ...
        'r-', ...
        'LineWidth',2.0, ...
        'DisplayName', ...
        sprintf('Total fit (R^2 = %.4f)',R2));


    % ------------------------------------------------------------
    % Background de référence
    %
    % MEME NORM_FACTOR que les données.
    % ------------------------------------------------------------

    if ~isempty(background_reference_norm)

        plot( ...
            wavenumber, ...
            background_reference_norm, ...
            '--', ...
            'Color',[0.2 0.2 0.2], ...
            'LineWidth',1.3, ...
            'DisplayName','Background reference');

    end


    % ------------------------------------------------------------
    % Background libre du fit
    %
    % On le montre seulement si sa valeur est non nulle.
    % ------------------------------------------------------------

    if abs(background_fit_norm) > 1e-12

        plot( ...
            wavenumber, ...
            background_fit_norm .* ...
            ones(size(wavenumber)), ...
            ':', ...
            'Color',[0.5 0.5 0.5], ...
            'LineWidth',1.2, ...
            'DisplayName','Fitted offset');

    end


    % ------------------------------------------------------------
    % Ligne zéro
    % ------------------------------------------------------------

    yline( ...
        0, ...
        'k:', ...
        'LineWidth',0.8, ...
        'HandleVisibility','off');


    xlabel( ...
        'Raman shift (cm^{-1})', ...
        'FontSize',12);


    ylabel( ...
        'Normalized intensity', ...
        'FontSize',12);


    title( ...
        sprintf( ...
            '%s — experimental spectrum and total fit', ...
            roi_name), ...
        'Interpreter','none', ...
        'FontWeight','normal');


    legend( ...
        'Location','best', ...
        'Box','off');


    % ------------------------------------------------------------
    % TOUT LE DOMAINE
    % ------------------------------------------------------------

    xlim([ ...
        min(wavenumber), ...
        max(wavenumber)]);


    grid on;
    box on;


    set(gca, ...
        'FontSize',11, ...
        'LineWidth',1, ...
        'TickDir','out');


    hold off;

end


%% ========================================================================
% 27. FIGURE 2
%
% COMPOSANTES DE PHASE NORMALISEES
% ========================================================================

if display_figures

    figure( ...
        'Color','white', ...
        'Position',[100 100 1100 650]);


    hold on;
    box on;


    % ------------------------------------------------------------
    % Données expérimentales
    % ------------------------------------------------------------

    plot( ...
        wavenumber, ...
        mean_spectrum_norm, ...
        'k-', ...
        'LineWidth',1.0, ...
        'DisplayName','Experimental');


    % ------------------------------------------------------------
    % Composantes de phases
    % ------------------------------------------------------------

    for a = 1:n_active

        k = active_idx(a);


        % --------------------------------------------------------
        % Couleur
        % --------------------------------------------------------

        if size(phase_colors,1) >= k

            this_color = ...
                phase_colors(k,:);

        elseif size(phase_colors,1) >= a

            this_color = ...
                phase_colors(a,:);

        else

            this_color = ...
                [0 0 0];

        end


        % --------------------------------------------------------
        % Nom
        % --------------------------------------------------------

        this_name = ...
            char(phase_model(k).name);


        % --------------------------------------------------------
        % Composante
        % --------------------------------------------------------

        plot( ...
            wavenumber_theoretical, ...
            components_norm(:,a), ...
            '-', ...
            'Color',this_color, ...
            'LineWidth',1.8, ...
            'DisplayName',this_name);

    end


    % ------------------------------------------------------------
    % Somme des phases
    % ------------------------------------------------------------

    plot( ...
        wavenumber_theoretical, ...
        total_phase_fit_norm, ...
        'k--', ...
        'LineWidth',2.0, ...
        'DisplayName','Sum of fitted phases');


    % ------------------------------------------------------------
    % Ligne zéro
    % ------------------------------------------------------------

    yline( ...
        0, ...
        'k:', ...
        'LineWidth',0.8, ...
        'HandleVisibility','off');


    xlabel( ...
        'Raman shift (cm^{-1})', ...
        'FontSize',12);


    ylabel( ...
        'Normalized intensity', ...
        'FontSize',12);


    title( ...
        sprintf( ...
            '%s — normalized fitted phase components', ...
            roi_name), ...
        'Interpreter','none', ...
        'FontWeight','normal');


    legend( ...
        'Location','best', ...
        'Box','off');


    % ------------------------------------------------------------
    % TOUT LE DOMAINE
    % ------------------------------------------------------------

    xlim([ ...
        min(wavenumber), ...
        max(wavenumber)]);


    grid on;
    box on;


    set(gca, ...
        'FontSize',11, ...
        'LineWidth',1, ...
        'TickDir','out');


    hold off;

end


%% ========================================================================
% 28. RESULTAT
% ========================================================================

result = struct();


% -------------------------------------------------------------------------
% Identification
% -------------------------------------------------------------------------

result.name = roi_name;

result.roi = roi;

result.phase_map = phase_map;

result.n_pixels = n_pixels_roi;


% -------------------------------------------------------------------------
% Données expérimentales
% -------------------------------------------------------------------------

result.wavenumber = wavenumber;

result.sum_spectrum = sum_spectrum;

result.mean_spectrum = mean_spectrum;

result.std_spectrum = std_spectrum;


% -------------------------------------------------------------------------
% Fit
% -------------------------------------------------------------------------

result.A_fit = A_fit;

result.nu_fit = nu_fit;

result.FWHM_fit = FWHM_fit;

result.background_fit = background_fit;

result.background_fit_sum = background_fit_sum;


result.R2 = R2;

result.resnorm = resnorm;

result.exitflag = exitflag;


% -------------------------------------------------------------------------
% Grille théorique
% -------------------------------------------------------------------------

result.wavenumber_theoretical = ...
    wavenumber_theoretical;


% -------------------------------------------------------------------------
% Fits
% -------------------------------------------------------------------------

result.fit_total = ...
    fit_total;


result.components = ...
    components;


result.total_phase_fit = ...
    total_phase_fit;


% -------------------------------------------------------------------------
% Background
% -------------------------------------------------------------------------

result.background_spectrum = ...
    background_reference;


% -------------------------------------------------------------------------
% NORMALISATION
% -------------------------------------------------------------------------

result.norm_factor = ...
    norm_factor;


result.mean_spectrum_norm = ...
    mean_spectrum_norm;


result.std_spectrum_norm = ...
    std_spectrum_norm;


result.fit_total_norm = ...
    fit_total_norm;


result.components_norm = ...
    components_norm;


result.total_phase_fit_norm = ...
    total_phase_fit_norm;


result.background_norm = ...
    background_reference_norm;


result.background_fit_norm = ...
    background_fit_norm;


% -------------------------------------------------------------------------
% ACC / ARA
% -------------------------------------------------------------------------

result.max_ACC = ...
    max_ACC;


result.max_ARA = ...
    max_ARA;


result.ratio_ACC_ARA = ...
    ratio_ACC_ARA;


% -------------------------------------------------------------------------
% Bruit
% -------------------------------------------------------------------------

result.noise_analysis = ...
    noise_analysis;


% -------------------------------------------------------------------------
% Paramètres instrumentaux
% -------------------------------------------------------------------------

result.fwhm_instr = ...
    fwhm_instr;


result.sigma_instr = ...
    sigma_instr;


% -------------------------------------------------------------------------
% Paramètres d'optimisation
% -------------------------------------------------------------------------

result.x_fit = ...
    x_fit;


result.residual = ...
    residual;


result.jacobian = ...
    jacobian;


result.A_CI = ...
    A_CI;


result.A_significant = ...
    A_significant;


%% ========================================================================
% 29. AFFICHAGE CONSOLE
% ========================================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('                 SINGLE ROI FIT\n');
fprintf('============================================================\n');

fprintf('ROI name          : %s\n',roi_name);

fprintf('ROI coordinates   : [%d %d %d %d]\n', ...
    roi(1),roi(2),roi(3),roi(4));

fprintf('Number of pixels  : %d\n', ...
    n_pixels_roi);

fprintf('\n');

fprintf('R2                : %.6f\n',R2);

fprintf('Resnorm           : %.6g\n',resnorm);

fprintf('Background fit    : %.6g\n',background_fit);

fprintf('Background norm.  : %.6g\n',background_fit_norm);

fprintf('Normalization     : %.6g\n',norm_factor);

fprintf('\n');

fprintf('Phase components:\n');


for a = 1:n_active

    k = active_idx(a);

    fprintf( ...
        '  %-15s : max = %.6f\n', ...
        phase_model(k).name, ...
        max(components_norm(:,a),[],'omitnan'));

end


fprintf('\n');

if isfinite(max_ACC)

    fprintf('Max ACC           : %.6f\n',max_ACC);

end


if isfinite(max_ARA)

    fprintf('Max ARA           : %.6f\n',max_ARA);

end


if isfinite(ratio_ACC_ARA)

    fprintf( ...
        'ACC / ARA         : %.6f\n', ...
        ratio_ACC_ARA);

end


if isfield(noise_analysis,'SNR_phases')

    fprintf('\nSNR phases:\n');

    for a = 1:n_active

        k = active_idx(a);

        fprintf( ...
            '  %-15s : %.3f\n', ...
            phase_model(k).name, ...
            noise_analysis.SNR_phases(a));

    end

end


fprintf('============================================================\n');


end


%% ========================================================================
% FONCTION : BUILD PARAMETER MAP
% ========================================================================

function [param_map,idx_background,x0_template,lb,ub] = ...
    buildParamMap( ...
        phase_model, ...
        active_idx, ...
        nu_is_variable, ...
        FWHM_is_variable, ...
        nu_LB, ...
        nu_UB, ...
        FWHM_LB, ...
        FWHM_UB)


n_active = ...
    numel(active_idx);


param_map = struct( ...
    'k',{}, ...
    'idx_A',{}, ...
    'idx_nu',{}, ...
    'idx_FWHM',{}, ...
    'nu_fixed',{}, ...
    'FWHM_fixed',{}, ...
    'ratio',{});


idx = 0;

x0_template = [];

lb = [];

ub = [];


for a = 1:n_active

    k = active_idx(a);


    nu0 = ...
        phase_model(k).nu(:).';


    FWHM0 = ...
        phase_model(k).FWHM(:).';


    % ------------------------------------------------------------
    % Amplitude
    % ------------------------------------------------------------

    idx = idx + 1;


    param_map(a).k = k;

    param_map(a).idx_A = idx;


    x0_template(idx,1) = 0;

    lb(idx,1) = 0;

    ub(idx,1) = Inf;


    % ------------------------------------------------------------
    % Position
    % ------------------------------------------------------------

    if nu_is_variable(k)

        n = numel(nu0);


        param_map(a).idx_nu = ...
            idx + (1:n);


        x0_template( ...
            param_map(a).idx_nu,1) = ...
            nu0(:);


        lb( ...
            param_map(a).idx_nu,1) = ...
            nu_LB(k);


        ub( ...
            param_map(a).idx_nu,1) = ...
            nu_UB(k);


        idx = ...
            idx + n;

    else

        param_map(a).idx_nu = [];

    end


    param_map(a).nu_fixed = ...
        nu0;


    % ------------------------------------------------------------
    % FWHM
    % ------------------------------------------------------------

    if FWHM_is_variable(k)

        n = numel(FWHM0);


        param_map(a).idx_FWHM = ...
            idx + (1:n);


        x0_template( ...
            param_map(a).idx_FWHM,1) = ...
            FWHM0(:);


        lb( ...
            param_map(a).idx_FWHM,1) = ...
            FWHM_LB(k);


        ub( ...
            param_map(a).idx_FWHM,1) = ...
            FWHM_UB(k);


        idx = ...
            idx + n;

    else

        param_map(a).idx_FWHM = [];

    end


    param_map(a).FWHM_fixed = ...
        FWHM0;


    % ------------------------------------------------------------
    % Ratios
    % ------------------------------------------------------------

    param_map(a).ratio = ...
        phase_model(k).ratio;

end


% -------------------------------------------------------------------------
% Background libre
% -------------------------------------------------------------------------

idx = idx + 1;


idx_background = idx;


x0_template(idx_background,1) = 0;

lb(idx_background,1) = -Inf;

ub(idx_background,1) = Inf;


end


%% ========================================================================
% FONCTION : MODELE DIRECT
% ========================================================================

function I_model = pixelForwardModel( ...
    x, ...
    wavenumber, ...
    param_map, ...
    idx_background, ...
    sigma_instr, ...
    lineshape_type)


I_model = ...
    x(idx_background) .* ...
    ones(size(wavenumber));


for a = 1:numel(param_map)

    pm = param_map(a);


    % ------------------------------------------------------------
    % Amplitude
    % ------------------------------------------------------------

    A = ...
        x(pm.idx_A);


    if A == 0

        continue;

    end


    % ------------------------------------------------------------
    % Position
    % ------------------------------------------------------------

    if ~isempty(pm.idx_nu)

        nu = ...
            reshape( ...
                x(pm.idx_nu), ...
                1, []);

    else

        nu = ...
            pm.nu_fixed;

    end


    % ------------------------------------------------------------
    % FWHM
    % ------------------------------------------------------------

    if ~isempty(pm.idx_FWHM)

        FWHM = ...
            reshape( ...
                x(pm.idx_FWHM), ...
                1, []);

    else

        FWHM = ...
            pm.FWHM_fixed;

    end


    % ------------------------------------------------------------
    % Ratios
    % ------------------------------------------------------------

    ratio = ...
        pm.ratio(:).';


    if isempty(ratio)

        ratio = ...
            ones(size(nu));

    end


    ratio = ...
        ratio / sum(ratio);


    % ------------------------------------------------------------
    % Phase
    % ------------------------------------------------------------

    G = ...
        zeros(size(wavenumber));


    for p = 1:numel(nu)

        sigma_phase = ...
            fwhm2sigma(FWHM(p));


        sigma_eff = ...
            sqrt( ...
                sigma_phase.^2 + ...
                sigma_instr.^2);


        G = ...
            G + ...
            ratio(p) .* ...
            lineShapeArea( ...
                wavenumber, ...
                nu(p), ...
                sigma_eff, ...
                lineshape_type);

    end


    % ------------------------------------------------------------
    % Ajout phase
    % ------------------------------------------------------------

    I_model = ...
        I_model + ...
        A .* G;

end


end


%% ========================================================================
% FONCTION : LINE SHAPE NORMALISEE EN AIRE
% ========================================================================

function G = lineShapeArea( ...
    x, ...
    mu, ...
    sigma, ...
    lineshape_type)


if nargin < 4 || isempty(lineshape_type)

    lineshape_type = ...
        'gaussian';

end


switch lower(lineshape_type)

    case 'gaussian'

        G = ...
            exp( ...
                -0.5 .* ...
                ((x-mu)./sigma).^2) ./ ...
            (sigma .* sqrt(2*pi));


    otherwise

        error( ...
            'lineshape_type "%s" non supporté.', ...
            lineshape_type);

end


end


%% ========================================================================
% FONCTION : FWHM -> SIGMA
% ========================================================================

function sigma = fwhm2sigma(FWHM)

sigma = ...
    FWHM ./ ...
    (2*sqrt(2*log(2)));

end

