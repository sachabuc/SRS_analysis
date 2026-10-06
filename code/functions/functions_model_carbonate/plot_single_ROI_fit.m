



function result = plot_single_ROI_fit( ...
    I_corr, wavenumber, phase_model, roi, ...
    fwhm_instr, active_idx, phase_colors, params)
% ================================================================
% PLOT_SINGLE_ROI_FIT
%
% Analyse et affiche le FIT d'un seul ROI.
%
% Le spectre utilisé pour le fit est la SOMME de tous les pixels
% du ROI.
%
% Deux figures sont produites :
%
%   1. Spectre brut somme + FIT TOTAL
%
%   2. Spectre brut somme + COMPOSANTES individuelles du FIT
%
% Les composantes sont calculées sur la même échelle que le spectre
% somme : aucune division par le nombre de pixels.
%
%
% INPUTS
% ------------------------------------------------
% I_corr       : cube [ny x nx x n_wn]
% wavenumber   : vecteur spectral
% phase_model  : structure contenant les modèles des phases
% roi          : [row_start row_end col_start col_end]
% fwhm_instr   : FWHM de la réponse instrumentale
% active_idx   : indices des phases incluses dans le fit
% phase_colors : [n_phases x 3], couleurs des phases
% params       : paramètres du modèle :
%                .nu_is_variable
%                .FWHM_is_variable
%                .nu_LB
%                .nu_UB
%                .FWHM_LB
%                .FWHM_UB
%                éventuellement .lineshape_type
%
%
% OUTPUT
% ------------------------------------------------
% result.sum_spectrum
% result.fit_total
% result.background
% result.components
% result.A_fit
% result.nu_fit
% result.FWHM_fit
% result.R2
% result.resnorm
% result.exitflag
% result.wavenumber
% result.wavenumber_theoretical
% result.n_pixels
% result.roi
%
% ================================================================


%% ================================================================
% 1. Vérifications / mise en forme
% ================================================================

if ndims(I_corr) == 4
    I_corr = squeeze(I_corr);
end

assert(ndims(I_corr) == 3, ...
    'I_corr doit être un cube [ny x nx x n_wn].');

assert(numel(roi) == 4, ...
    'roi doit être [row_start row_end col_start col_end].');

assert(numel(active_idx) >= 1, ...
    'active_idx doit contenir au moins une phase.');

active_idx = active_idx(:).';

[n_y,n_x,n_wn] = size(I_corr);


%% ================================================================
% 2. Tri spectral
% ================================================================

[wavenumber,sort_idx] = sort(wavenumber(:));

I_corr = I_corr(:,:,sort_idx);


%% ================================================================
% 3. Vérification du ROI
% ================================================================

row_start = roi(1);
row_end   = roi(2);
col_start = roi(3);
col_end   = roi(4);

assert(row_start >= 1 && row_end <= n_y && ...
       col_start >= 1 && col_end <= n_x, ...
       'Le ROI sort des dimensions de I_corr.');

assert(row_start <= row_end && col_start <= col_end, ...
       'ROI invalide.');


rows = row_start:row_end;
cols = col_start:col_end;

n_pixels_roi = numel(rows) * numel(cols);


%% ================================================================
% 4. Extraction du ROI
% ================================================================

I_roi = I_corr(rows,cols,:);

I_roi_2D = reshape( ...
    I_roi, ...
    n_pixels_roi, ...
    n_wn);


%% ================================================================
% 5. SPECTRE SOMME
% ================================================================

% Spectre réellement utilisé pour le FIT
sum_spectrum = sum(I_roi_2D,1,'omitnan');
sum_spectrum = sum_spectrum(:);


% Pour information uniquement
mean_spectrum = mean(I_roi_2D,1,'omitnan');
mean_spectrum = mean_spectrum(:);

std_spectrum = std(I_roi_2D,0,1,'omitnan');
std_spectrum = std_spectrum(:);


%% ================================================================
% 6. Paramètres du modèle
% ================================================================

nu_is_variable   = params.nu_is_variable;
FWHM_is_variable = params.FWHM_is_variable;

lineshape_type = 'gaussian';

if isfield(params,'lineshape_type') && ...
        ~isempty(params.lineshape_type)

    lineshape_type = params.lineshape_type;

end


n_phases = numel(phase_model);


assert(numel(params.nu_LB) == n_phases && ...
       numel(params.nu_UB) == n_phases && ...
       numel(params.FWHM_LB) == n_phases && ...
       numel(params.FWHM_UB) == n_phases, ...
       ['Les vecteurs de bornes doivent avoir ', ...
        'un élément par phase.']);


%% ================================================================
% 7. Construction du modèle
% ================================================================

[param_map,idx_background,x0_template,lb,ub] = buildParamMap( ...
    phase_model, ...
    active_idx, ...
    nu_is_variable, ...
    FWHM_is_variable, ...
    params.nu_LB, ...
    params.nu_UB, ...
    params.FWHM_LB, ...
    params.FWHM_UB);


%% ================================================================
% 8. Réponse instrumentale
% ================================================================

sigma_inst = fwhm2sigma(fwhm_instr);


%% ================================================================
% 9. Fonction modèle
% ================================================================

model_fun = @(x,xdata) pixelForwardModel( ...
    x, ...
    xdata, ...
    param_map, ...
    idx_background, ...
    sigma_inst, ...
    lineshape_type);


%% ================================================================
% 10. Initialisation
% ================================================================

opts = optimoptions( ...
    'lsqcurvefit', ...
    'Display','off');


x0 = x0_template;


% ------------------------------------------------
% Modèle test avec A = 1
% ------------------------------------------------

x0_A_test = x0_template;


for a = 1:numel(param_map)

    x0_A_test(param_map(a).idx_A) = 1;

    if ~isempty(param_map(a).idx_nu)

        x0_A_test(param_map(a).idx_nu) = ...
            phase_model(param_map(a).k).nu;

    end

    if ~isempty(param_map(a).idx_FWHM)

        x0_A_test(param_map(a).idx_FWHM) = ...
            phase_model(param_map(a).k).FWHM;

    end

end


% Fond initial
x0_A_test(idx_background) = min(sum_spectrum);


%% ================================================================
% 11. Construction des fonctions de base pour NNLS
% ================================================================

G = zeros(n_wn,numel(param_map));


for a = 1:numel(param_map)

    x_tmp = x0_A_test;


    % Amplitude de la phase courante = 1
    x_tmp(param_map(a).idx_A) = 1;


    % Toutes les autres amplitudes = 0
    for b = 1:numel(param_map)

        if b ~= a

            x_tmp(param_map(b).idx_A) = 0;

        end

    end


    % Pas de fond pour NNLS
    x_tmp(idx_background) = 0;


    G(:,a) = model_fun(x_tmp,wavenumber);

end


%% ================================================================
% 12. Initialisation NNLS
% ================================================================

y_init = sum_spectrum - min(sum_spectrum);

y_init = max(y_init,0);


A0 = lsqnonneg(G,y_init);


for a = 1:numel(param_map)

    x0(param_map(a).idx_A) = max(A0(a),0);

end


% Fond initial
x0(idx_background) = min(sum_spectrum);


%% ================================================================
% 13. FIT DU SPECTRE SOMME
% ================================================================

[x_fit,resnorm,residual,exitflag,~,~,jacobian] = ...
    lsqcurvefit( ...
        model_fun, ...
        x0, ...
        wavenumber, ...
        sum_spectrum, ...
        lb, ...
        ub, ...
        opts);


%% ================================================================
% 14. Qualité du fit
% ================================================================

SS_tot = sum( ...
    (sum_spectrum - mean(sum_spectrum)).^2);

R2 = 1 - resnorm / max(SS_tot,eps);


%% ================================================================
% 15. Extraction des paramètres ajustés
% ================================================================

A_fit    = zeros(n_phases,1);
nu_fit   = cell(n_phases,1);
FWHM_fit = cell(n_phases,1);


for a = 1:numel(param_map)

    k = param_map(a).k;


    % Amplitude
    A_fit(k) = x_fit(param_map(a).idx_A);


    % Position
    if ~isempty(param_map(a).idx_nu)

        nu_fit{k} = reshape( ...
            x_fit(param_map(a).idx_nu), ...
            1,[]);

    else

        nu_fit{k} = param_map(a).nu_fixed;

    end


    % FWHM
    if ~isempty(param_map(a).idx_FWHM)

        FWHM_fit{k} = reshape( ...
            x_fit(param_map(a).idx_FWHM), ...
            1,[]);

    else

        FWHM_fit{k} = param_map(a).FWHM_fixed;

    end

end


background_fit = x_fit(idx_background);


%% ================================================================
% 16. FIT TOTAL — grille expérimentale
% ================================================================

fit_total = model_fun( ...
    x_fit, ...
    wavenumber);


%% ================================================================
% 17. Grille spectrale fine pour les plots
% ================================================================

n_theoretical_points = 1000;

wavenumber_theoretical = linspace( ...
    min(wavenumber), ...
    max(wavenumber), ...
    n_theoretical_points).';


fit_total_theoretical = model_fun( ...
    x_fit, ...
    wavenumber_theoretical);


%% ================================================================
% 18. Reconstruction des composantes individuelles
% ================================================================
%
% IMPORTANT :
%
% Chaque composante est reconstruite en utilisant EXACTEMENT
% le même modèle que le fit.
%
% On conserve uniquement une phase à la fois et on met le fond
% à zéro.
%
% Cela évite de réécrire manuellement la convolution et le
% profil spectral.

n_active = numel(param_map);

components = zeros( ...
    numel(wavenumber_theoretical), ...
    n_active);


component_phase_idx = zeros(n_active,1);


for a = 1:n_active

    % Index de la phase
    k = param_map(a).k;

    component_phase_idx(a) = k;


    % Vecteur de paramètres nul
    x_component = x_fit;


    % Toutes les amplitudes à zéro
    for b = 1:n_active

        x_component(param_map(b).idx_A) = 0;

    end


    % Fond retiré
    x_component(idx_background) = 0;


    % Une seule phase active
    x_component(param_map(a).idx_A) = ...
        x_fit(param_map(a).idx_A);


    % Reconstruction
    components(:,a) = model_fun( ...
        x_component, ...
        wavenumber_theoretical);

end


%% ================================================================
% 19. Composante du fond
% ================================================================

background_component = ...
    background_fit * ones(size(wavenumber_theoretical));


%% ================================================================
% 20. Vérification de la reconstruction
% ================================================================

fit_reconstructed = ...
    background_component + sum(components,2);


reconstruction_error = ...
    max(abs(fit_reconstructed - fit_total_theoretical));


%% ================================================================
% 21. FIGURE 1
%     Spectre brut somme + FIT TOTAL
% ================================================================

figure( ...
    'Color','white', ...
    'Position',[100 100 1000 600]);

hold on;
box on;


% Spectre brut
plot( ...
    wavenumber, ...
    sum_spectrum, ...
    'o', ...
    'Color',[0.15 0.15 0.15], ...
    'MarkerFaceColor',[0.15 0.15 0.15], ...
    'MarkerSize',4, ...
    'DisplayName','ROI sum');


% Fit total
plot( ...
    wavenumber_theoretical, ...
    fit_total_theoretical, ...
    '-', ...
    'Color',[0.85 0.10 0.60], ...
    'LineWidth',2.2, ...
    'DisplayName',sprintf('Total fit (R^2 = %.4f)',R2));


xlabel('Wavenumber (cm^{-1})');
ylabel('Intensity (ROI sum)');

title('Single ROI — summed spectrum and total fit');


legend( ...
    'Location','best', ...
    'Box','off');


grid on;


set(gca, ...
    'FontName','Arial', ...
    'FontSize',12, ...
    'LineWidth',1, ...
    'TickDir','out');


%% ================================================================
% 22. FIGURE 2
%     Spectre brut somme + COMPOSANTES NORMALISEES
% ================================================================

% ------------------------------------------------
% Normalisation commune
% ------------------------------------------------
%
% On normalise toutes les composantes par le maximum
% du FIT TOTAL.
%
% Ainsi :
%
%   max(fit_total_normalized) = 1
%
% Les amplitudes relatives des différentes phases
% sont conservées.
%

norm_factor_components = max(fit_total_theoretical);

if norm_factor_components <= 0 || ~isfinite(norm_factor_components)
    norm_factor_components = 1;
end


sum_spectrum_norm = ...
    sum_spectrum / norm_factor_components;

components_norm = ...
    components / norm_factor_components;

background_norm = ...
    background_component / norm_factor_components;

fit_total_norm = ...
    fit_total_theoretical / norm_factor_components;


%% ================================================================
% Recherche ACC et ARA
% ================================================================

idx_ACC = [];
idx_ARA = [];

for a = 1:n_active

    k = component_phase_idx(a);

    if isfield(phase_model(k),'name')

        phase_name_tmp = lower(phase_model(k).name);

    else

        phase_name_tmp = sprintf('phase %d',k);

    end


    % Recherche robuste du nom
    if contains(phase_name_tmp,'acc')

        idx_ACC = a;

    elseif contains(phase_name_tmp,'aragonite') || ...
           strcmp(phase_name_tmp,'ara')

        idx_ARA = a;

    end

end


%% ================================================================
% Rapport max(ACC) / max(ARA)
% ================================================================

ratio_ACC_ARA = NaN;

max_ACC = NaN;
max_ARA = NaN;

if ~isempty(idx_ACC)

    max_ACC = max(components(:,idx_ACC))

end

if ~isempty(idx_ARA)

    max_ARA = max(components(:,idx_ARA))

end

if isfinite(max_ACC) && ...
   isfinite(max_ARA) && ...
   max_ARA > 0

    ratio_ACC_ARA = max_ACC / max_ARA

end


%% ================================================================
% Figure
% ================================================================

figure( ...
    'Color','white', ...
    'Position',[150 100 1100 700]);

hold on;
box on;


%% ------------------------------------------------
% Spectre expérimental brut normalisé
% ------------------------------------------------

plot( ...
    wavenumber, ...
    sum_spectrum_norm, ...
    'o', ...
    'Color',[0.15 0.15 0.15], ...
    'MarkerFaceColor',[0.15 0.15 0.15], ...
    'MarkerSize',4, ...
    'DisplayName','ROI sum');


%% ------------------------------------------------
% Composantes
% ------------------------------------------------

legend_handles = gobjects(n_active+2,1);
legend_labels  = cell(n_active+2,1);

legend_counter = 0;


for a = 1:n_active

    k = component_phase_idx(a);


    % ------------------------------------------------
    % Couleur
    % ------------------------------------------------

    if size(phase_colors,1) >= k

        current_color = phase_colors(k,:);

    else

        tmp_colors = lines(n_active);
        current_color = tmp_colors(a,:);

    end


    % ------------------------------------------------
    % Nom
    % ------------------------------------------------

    if isfield(phase_model(k),'name')

        phase_name = phase_model(k).name;

    else

        phase_name = sprintf('Phase %d',k);

    end


    % ------------------------------------------------
    % Plot
    % ------------------------------------------------

    h = plot( ...
        wavenumber_theoretical, ...
        components_norm(:,a), ...
        '-', ...
        'Color',current_color, ...
        'LineWidth',2, ...
        'DisplayName',phase_name);


    legend_counter = legend_counter + 1;

    legend_handles(legend_counter) = h;

    legend_labels{legend_counter} = phase_name;


end


%% ------------------------------------------------
% Fond
% ------------------------------------------------

h_bg = plot( ...
    wavenumber_theoretical, ...
    background_norm, ...
    ':', ...
    'Color',[0.35 0.35 0.35], ...
    'LineWidth',1.5, ...
    'DisplayName','Background');


legend_counter = legend_counter + 1;

legend_handles(legend_counter) = h_bg;

legend_labels{legend_counter} = 'Background';


%% ------------------------------------------------
% Fit total normalisé
% ------------------------------------------------

h_total = plot( ...
    wavenumber_theoretical, ...
    fit_total_norm, ...
    '--', ...
    'Color',[0 0 0], ...
    'LineWidth',1.8, ...
    'DisplayName','Total fit');


legend_counter = legend_counter + 1;

legend_handles(legend_counter) = h_total;

legend_labels{legend_counter} = 'Total fit';


%% ================================================================
% Axes
% ================================================================

xlabel( ...
    'Wavenumber (cm^{-1})', ...
    'FontSize',12);

ylabel( ...
    'Normalized intensity', ...
    'FontSize',12);


title( ...
    'Single ROI — fitted phase components', ...
    'FontSize',13);


grid on;


set(gca, ...
    'FontName','Arial', ...
    'FontSize',12, ...
    'LineWidth',1, ...
    'TickDir','out');


legend( ...
    legend_handles(1:legend_counter), ...
    legend_labels(1:legend_counter), ...
    'Location','best', ...
    'Box','off');


%% ================================================================
% Texte avec résultats du fit
% ================================================================

fit_text = sprintf( ...
    ['R^2 = %.4f\n' ...
     'Resnorm = %.4g\n' ...
     'Background = %.4g'], ...
    R2, ...
    resnorm, ...
    background_fit);


% ------------------------------------------------
% Paramètres de chaque phase
% ------------------------------------------------

for a = 1:n_active

    k = component_phase_idx(a);


    if isfield(phase_model(k),'name')

        phase_name = phase_model(k).name;

    else

        phase_name = sprintf('Phase %d',k);

    end


    fit_text = sprintf( ...
        '%s\n%s : A = %.4g', ...
        fit_text, ...
        phase_name, ...
        A_fit(k));


    if ~isempty(nu_fit{k})

        fit_text = sprintf( ...
            '%s, \\nu = %.3f', ...
            fit_text, ...
            nu_fit{k}(1));

    end


    if ~isempty(FWHM_fit{k})

        fit_text = sprintf( ...
            '%s, FWHM = %.3f', ...
            fit_text, ...
            FWHM_fit{k}(1));

    end

end


%% ------------------------------------------------
% Rapport ACC / ARA
% ------------------------------------------------

if isfinite(ratio_ACC_ARA)

    fit_text = sprintf( ...
        '%s\n\nmax(ACC) / max(ARA) = %.4f', ...
        fit_text, ...
        ratio_ACC_ARA);

else

    fit_text = sprintf( ...
        '%s\n\nmax(ACC) / max(ARA) = N/A', ...
        fit_text);

end


%% ------------------------------------------------
% Affichage du texte
% ------------------------------------------------

annotation( ...
    'textbox', ...
    [0.15 0.45 0.35 0.30], ...
    'String',fit_text, ...
    'FitBoxToText','on', ...
    'BackgroundColor','white', ...
    'EdgeColor',[0.7 0.7 0.7], ...
    'FontName','Arial', ...
    'FontSize',10, ...
    'Interpreter','tex');


%% ================================================================
% Affichage console
% ================================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' SINGLE ROI — FIT RESULTS\n');
fprintf('============================================================\n');

fprintf('R2         = %.6f\n',R2);

fprintf('Resnorm    = %.6g\n',resnorm);

fprintf('Background = %.6g\n',background_fit);


for a = 1:n_active

    k = component_phase_idx(a);


    if isfield(phase_model(k),'name')

        phase_name = phase_model(k).name;

    else

        phase_name = sprintf('Phase %d',k);

    end


    fprintf('\n%s\n',phase_name);

    fprintf('  A    = %.8g\n',A_fit(k));


    if ~isempty(nu_fit{k})

        fprintf('  nu   = %.6f cm^-1\n',nu_fit{k}(1));

    end


    if ~isempty(FWHM_fit{k})

        fprintf('  FWHM = %.6f cm^-1\n',FWHM_fit{k}(1));

    end

end


fprintf('\n------------------------------------------------------------\n');

if isfinite(ratio_ACC_ARA)

    fprintf( ...
        'max(ACC) / max(ARA) = %.6f\n', ...
        ratio_ACC_ARA);

else

    fprintf('max(ACC) / max(ARA) = N/A\n');

end

fprintf('============================================================\n');


%% ================================================================
% 23. Affichage des paramètres
% ================================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' SINGLE ROI FIT\n');
fprintf('============================================================\n');

fprintf('ROI = [%d %d %d %d]\n',roi);

fprintf('Nombre de pixels = %d\n',n_pixels_roi);

fprintf('R2       = %.6f\n',R2);

fprintf('Resnorm  = %.6g\n',resnorm);

fprintf('Exitflag = %d\n',exitflag);

fprintf('Background = %.6g\n',background_fit);

fprintf('\n');


for a = 1:n_active

    k = component_phase_idx(a);


    if isfield(phase_model(k),'name')

        phase_name = phase_model(k).name;

    else

        phase_name = sprintf('Phase %d',k);

    end


    fprintf('------------------------------------------------------------\n');

    fprintf('%s\n',phase_name);

    fprintf('A = %.8g\n',A_fit(k));


    if ~isempty(nu_fit{k})

        fprintf('nu = ');

        fprintf('%.4f ',nu_fit{k});

        fprintf('cm^-1\n');

    end


    if ~isempty(FWHM_fit{k})

        fprintf('FWHM = ');

        fprintf('%.4f ',FWHM_fit{k});

        fprintf('cm^-1\n');

    end

end


fprintf('------------------------------------------------------------\n');

fprintf('Maximum reconstruction error = %.6g\n', ...
    reconstruction_error);

fprintf('============================================================\n');


%% ================================================================
% 24. Sortie
% ================================================================

result = struct();

result.name = 'ARA+ACC';

result.roi = roi;

result.n_pixels = n_pixels_roi;


% Spectres
result.wavenumber = wavenumber;

result.sum_spectrum = sum_spectrum;

result.mean_spectrum = mean_spectrum;

result.std_spectrum = std_spectrum;


% Fit
result.fit_total = fit_total;

result.wavenumber_theoretical = ...
    wavenumber_theoretical;

result.fit_total_theoretical = ...
    fit_total_theoretical;


% Composantes
result.components = components;

result.component_phase_idx = ...
    component_phase_idx;

result.background_component = ...
    background_component;


% Paramètres
result.A_fit = A_fit;

result.nu_fit = nu_fit;

result.FWHM_fit = FWHM_fit;

result.background_fit = ...
    background_fit;


% Qualité
result.R2 = R2;

result.resnorm = resnorm;

result.exitflag = exitflag;

result.residual = residual;

result.jacobian = jacobian;


end