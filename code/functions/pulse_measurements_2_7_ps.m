%% ============================================================
% FIT GAUSSIAN / LORENTZIAN / BOTH
% Chirp vs No Chirp
% Normalized intensity + centered delay
% Publication-quality plot
%% ============================================================

clearvars -except delay_chirp intensity_chirp delay intensity
close all;
clc;

%% ===================== DATA =================================
% WITH CHIRP
delay_chirp = [0, 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, ...
        10000, 11000, 12000, 13000, 14000, 15000, 16000, 17000, 18000, 19000, ...
        20000, 20500, 21000, 21500, 22000, 22500, 23000, 23500, 24000, 24500, ...
        25000, 25500, 26000, 26500, 27000, 27500, 28000, 28500, 29000, 29500, ...
        30000, 30500, 31000, 31500, 32000, 32500, 33000, 33500, 34000, 34500, ...
        35000, 36000, 37000, 38000, 39000, 40000, 41000, 42000, 43000, 44000, ...
        45000, 46000, 47000, 48000, 49000, 50000];

intensity_chirp = [280; 280; 280; 290; 292; 300; 310; 322; 340; 360; ...
        387; 425; 475; 540; 625; 730; 860; 1030; 1230; 1450; ...
        1730; 1860; 2000; 2160; 2300; 2420; 2540; 2650; 2760; 2840; ...
        2940; 3020; 3060; 3040; 3020; 3030; 2980; 2900; 2840; 2840; ...
        2640; 2520; 2430; 2280; 2120; 1980; 1850; 1670; 1550; 1420; ...
        1300; 1080; 920; 750; 625; 535; 475; 430; 390; 360; ...
        340; 320; 310; 305; 295; 295];

% WITHOUT CHIRP
delay = [3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000, ...
                  11000, 11500, 12000, 12500, 13000, 13500, 14000, ...
                  14500, 15000, 15500, 16000, 16500, 17000, 18000, ...
                  19000, 20000, 21000, 22000, 23000];

intensity = [660, 720, 975, 1350, 1600, 1480, 1200, 1140, 2500, ...
             5100, 8750, 12500, 14850, 16450, 17100, 17000, 16250, ...
             14600, 12000, 8500, 5800, 3000, 2400, 1500, 1000, 780, 660];

%% ===================== USER SETTINGS ========================
fit_type = 'gaussian';
plot_data = true;
plot_FWHM = false;
save_figure = false;
figure_name = 'chirp_comparison_fit';

%% ===================== DATA PROCESSING ======================
% WITH CHIRP
x_chirp = delay_chirp(:) * 1e-3; % en ps
y_chirp = intensity_chirp(:);
y_chirp = y_chirp - min(y_chirp);

% WITHOUT CHIRP
shift = 10000;
x_noChirp = (delay(:) + shift) * 1e-3; % en ps
y_noChirp = intensity(:);
y_noChirp = y_noChirp - min(y_noChirp);

%% ===================== FITS ==================================
fit_chirp = perform_fit(x_chirp, y_chirp, fit_type);
fit_noChirp = perform_fit(x_noChirp, y_noChirp, fit_type);

%% ===================== FIT NORMALIZATION ======================
if strcmpi(fit_type, 'gaussian')
    norm_chirp = fit_chirp.gaussian.a;
    norm_noChirp = fit_noChirp.gaussian.a;
elseif strcmpi(fit_type, 'lorentzian')
    norm_chirp = fit_chirp.lorentzian.a;
    norm_noChirp = fit_noChirp.lorentzian.a;
elseif strcmpi(fit_type, 'both')
    norm_chirp = max(fit_chirp.gaussian.a, fit_chirp.lorentzian.a);
    norm_noChirp = max(fit_noChirp.gaussian.a, fit_noChirp.lorentzian.a);
end

y_chirp = y_chirp / norm_chirp;
y_noChirp = y_noChirp / norm_noChirp;

%% ===================== CENTERING =============================
if strcmpi(fit_type, 'lorentzian')
    b_chirp = fit_no_nan(fit_chirp.lorentzian.b);
    b_noChirp = fit_no_nan(fit_noChirp.lorentzian.b);
else
    b_chirp = fit_no_nan(fit_chirp.gaussian.b);
    b_noChirp = fit_no_nan(fit_noChirp.gaussian.b);
end

x_chirp_centered = x_chirp - b_chirp;
x_noChirp_centered = x_noChirp - b_noChirp;

%% ===================== SMOOTH CURVES =========================
x_min = min([x_chirp_centered; x_noChirp_centered]);
x_max = max([x_chirp_centered; x_noChirp_centered]);
xx_centered = linspace(x_min, x_max, 3000);

%% ===================== FIGURE ================================
fig = figure('Color', 'w', 'Units', 'centimeters', 'Position', [5 5 17 11]);
hold on;

set(gca, 'FontName', 'Arial', 'FontSize', 10, 'LineWidth', 1.0, 'TickDir', 'out', 'Box', 'off');

% Colors
color_chirp = [0.85 0.33 0.10]; % Rouge
color_noChirp = [0 0.45 0.74]; % Bleu

%% ---------------- RAW DATA -----------------------------------
if plot_data
    % Tracer les données expérimentales centrées
    plot(x_chirp_centered, y_chirp, 'x', 'Color', color_chirp, 'MarkerSize', 8, 'LineWidth', 0.8, 'DisplayName', 'Chirp data');
    plot(x_noChirp_centered, y_noChirp, 'x', 'Color', color_noChirp, 'MarkerSize', 8, 'LineWidth', 0.8, 'DisplayName', 'No chirp data');
end

%% ---------------- FIT CURVES --------------------------------
if isfield(fit_chirp, 'gaussian') && ~isempty(fit_chirp.gaussian)
    % Évaluer le fit sur xx_centered + b_chirp pour recentrer
    yy_chirp_gauss = feval(fit_chirp.gaussian.result, xx_centered + b_chirp);
    yy_chirp_gauss = yy_chirp_gauss / norm_chirp;
    h_fit_chirp = plot(xx_centered, yy_chirp_gauss, '-', 'Color', color_chirp, 'LineWidth', 2.0, 'DisplayName', 'Chirp fit');
end

if isfield(fit_noChirp, 'gaussian') && ~isempty(fit_noChirp.gaussian)
    % Évaluer le fit sur xx_centered + b_noChirp pour recentrer
    yy_noChirp_gauss = feval(fit_noChirp.gaussian.result, xx_centered + b_noChirp);
    yy_noChirp_gauss = yy_noChirp_gauss / norm_noChirp;
    h_fit_noChirp = plot(xx_centered, yy_noChirp_gauss, '-', 'Color', color_noChirp, 'LineWidth', 2.0, 'DisplayName', 'No chirp fit');
end

%% ===================== AXES AND LABELS =======================
xlabel('Relative delay (ps)', 'FontSize', 16, 'FontName', 'Arial');
ylabel('SFG intensity (arb. units)', 'FontSize', 16, 'FontName', 'Arial');

xline(0, 'k:', 'LineWidth', 0.8, 'HandleVisibility', 'off');
ylim([0 1.08]);

grid on;
ax = gca;
ax.GridAlpha = 0.12;
ax.GridLineStyle = '-';
ax.Layer = 'bottom';

%% ===================== LEGEND WITH FWHM =======================

col_chirp   = [0.85 0.33 0.10];
col_noChirp = [0 0.45 0.74];

legend_entries = {
    sprintf('Chirp      : %.2f',    fit_chirp.gaussian.FWHM)
    sprintf('No chirp : %.2f', fit_noChirp.gaussian.FWHM)
};

lgd = legend([h_fit_chirp, h_fit_noChirp], legend_entries, ...
    'Location', 'northeast', ...
    'Box', 'off', ...
    'FontSize', 12, ...
    'Interpreter', 'tex');

lgd.Title.String      = 'FWHM (ps)';
lgd.Title.Interpreter = 'tex';
lgd.Title.FontWeight  = 'bold';

set(gca, 'FontName', 'Arial', 'FontSize', 10, 'LineWidth', 1.0, ...
         'TickDir', 'out', 'Box', 'off');
title('');

%% ===================== SAVE FIGURE ===========================
if save_figure
    exportgraphics(fig, [figure_name '.pdf'], 'ContentType', 'vector');
    exportgraphics(fig, [figure_name '.png'], 'Resolution', 600);
end

%% ============================================================
% LOCAL FUNCTIONS
%% ============================================================
function output = perform_fit(x, y, fit_type)
    output = struct();
    [a0, idx] = max(y);
    b0 = x(idx);
    c0 = (max(x) - min(x)) / 10;

    if strcmpi(fit_type, 'gaussian') || strcmpi(fit_type, 'both')
        gauss_model = fittype('a*exp(-0.5*((x-b)/c)^2)', 'independent', 'x', 'coefficients', {'a', 'b', 'c'});
        options = fitoptions(gauss_model);
        options.StartPoint = [a0 b0 c0];
        options.Lower = [0 min(x) 0];
        options.Upper = [Inf max(x) Inf];
        [fit_result, gof] = fit(x, y, gauss_model, options);

        output.gaussian.result = fit_result;
        output.gaussian.R2 = gof.rsquare;
        output.gaussian.RMSE = gof.rmse;
        output.gaussian.a = fit_result.a;
        output.gaussian.b = fit_result.b;
        output.gaussian.c = fit_result.c;
        output.gaussian.FWHM = 2 * sqrt(2 * log(2)) * abs(fit_result.c);
    end

    if strcmpi(fit_type, 'lorentzian') || strcmpi(fit_type, 'both')
        lorentz_model = fittype('a/(1+((x-b)/c)^2)', 'independent', 'x', 'coefficients', {'a', 'b', 'c'});
        options = fitoptions(lorentz_model);
        options.StartPoint = [a0 b0 c0];
        options.Lower = [0 min(x) 0];
        options.Upper = [Inf max(x) Inf];
        [fit_result, gof] = fit(x, y, lorentz_model, options);

        output.lorentzian.result = fit_result;
        output.lorentzian.R2 = gof.rsquare;
        output.lorentzian.RMSE = gof.rmse;
        output.lorentzian.a = fit_result.a;
        output.lorentzian.b = fit_result.b;
        output.lorentzian.c = fit_result.c;
        output.lorentzian.FWHM = 2 * abs(fit_result.c);
    end
end

function value = fit_no_nan(value)
    if isempty(value) || isnan(value)
        value = 0;
    end
end