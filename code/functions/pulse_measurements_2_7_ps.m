%% ============================================================
%  FIT GAUSSIAN / LORENTZIAN / BOTH
%  Chirp vs No Chirp
%  Normalized intensity + centered delay
%  Publication-quality plot
%% ============================================================

clearvars -except delay_chirp intensity_chirp delay intensity
close all; clc;

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
% Options:
% 'gaussian'   : Gaussian fit only
% 'lorentzian' : Lorentzian fit only
% 'both'       : Gaussian + Lorentzian fits

plot_data = true;
plot_FWHM = true;
save_figure = false;

figure_name = 'chirp_comparison_fit';

%% ===================== DATA PROCESSING ======================

% -------- With chirp --------

x_chirp = delay_chirp(:) * 1e-3; % ps
y_chirp = intensity_chirp(:);
y_chirp = y_chirp - min(y_chirp);


% -------- Without chirp --------

shift = 10000;

x_noChirp = (delay(:) + shift) * 1e-3; % ps
y_noChirp = intensity(:);
y_noChirp = y_noChirp - min(y_noChirp);



%% ===================== FITS ==================================

% Fit both datasets
fit_chirp = perform_fit(x_chirp, y_chirp, fit_type);
fit_noChirp = perform_fit(x_noChirp, y_noChirp, fit_type);




%% ===================== FIT NORMALIZATION ======================

% Select the amplitude of the fitted model
if strcmpi(fit_type,'gaussian')
    norm_chirp   = fit_chirp.gaussian.a;
    norm_noChirp = fit_noChirp.gaussian.a;

elseif strcmpi(fit_type,'lorentzian')
    norm_chirp   = fit_chirp.lorentzian.a;
    norm_noChirp = fit_noChirp.lorentzian.a;

elseif strcmpi(fit_type,'both')
    % Use the maximum fitted amplitude among the two models
    norm_chirp = max( ...
        fit_chirp.gaussian.a, ...
        fit_chirp.lorentzian.a);

    norm_noChirp = max( ...
        fit_noChirp.gaussian.a, ...
        fit_noChirp.lorentzian.a);
end

% Normalize experimental data according to the corresponding fit
y_chirp   = y_chirp   / norm_chirp;
y_noChirp = y_noChirp / norm_noChirp;

%% ===================== CENTERING =============================

% Center each spectrum using its fitted center.
%
% For BOTH fits, the Gaussian center is used as reference.
% If only Lorentzian is selected, the Lorentzian center is used.

if strcmpi(fit_type, 'lorentzian')
    b_chirp = fit_no_nan(fit_chirp.lorentzian.b);
    b_noChirp = fit_no_nan(fit_noChirp.lorentzian.b);
else
    b_chirp = fit_no_nan(fit_chirp.gaussian.b);
    b_noChirp = fit_no_nan(fit_noChirp.gaussian.b);
end

% Centered x axes
x_chirp_centered = x_chirp - b_chirp;
x_noChirp_centered = x_noChirp - b_noChirp;

%% ===================== SMOOTH CURVES =========================

% Use a common centered axis for both datasets
x_min = min([x_chirp_centered; x_noChirp_centered]);
x_max = max([x_chirp_centered; x_noChirp_centered]);

xx_centered = linspace(x_min, x_max, 3000);

%% ===================== FIGURE ================================

fig = figure('Color','w', ...
    'Units','centimeters', ...
    'Position',[5 5 17 11]);

hold on;

% Publication-friendly formatting
set(gca, ...
    'FontName','Arial', ...
    'FontSize',10, ...
    'LineWidth',1.0, ...
    'TickDir','out', ...
    'Box','off');

% Colors
color_chirp = [0.00 0.45 0.74];
color_noChirp = [0.85 0.33 0.10];

%% ---------------- RAW DATA -----------------------------------

if plot_data

    plot(x_chirp_centered, y_chirp, 'x', ...
        'Color',color_chirp, ...
        'MarkerSize',8, ...
        'LineWidth',0.8, ...
        'DisplayName','Chirp data');

    plot(x_noChirp_centered, y_noChirp, 'x', ...
        'Color',color_noChirp, ...
        'MarkerSize',8, ...
        'LineWidth',0.8, ...
        'DisplayName','No chirp data');

end

%% ---------------- FIT CURVES --------------------------------

% Chirp
if isfield(fit_chirp,'gaussian') && ~isempty(fit_chirp.gaussian)

    yy_chirp_gauss = feval( ...
        fit_chirp.gaussian.result, xx_centered + b_chirp);

    yy_chirp_gauss = yy_chirp_gauss / norm_chirp;

    plot(xx_centered, yy_chirp_gauss, '-', ...
        'Color',color_chirp, ...
        'LineWidth',2.0, ...
        'DisplayName','Chirp — Gaussian');

end


if isfield(fit_chirp,'lorentzian') && ~isempty(fit_chirp.lorentzian)

    yy_chirp_lorentz = feval( ...
        fit_chirp.lorentzian.result, xx_centered + b_chirp);

    yy_chirp_lorentz = yy_chirp_lorentz / norm_chirp;

    plot(xx_centered, yy_chirp_lorentz, '--', ...
        'Color',color_chirp, ...
        'LineWidth',2.0, ...
        'DisplayName','Chirp — Lorentzian');

end


% No chirp
if isfield(fit_noChirp,'gaussian') && ~isempty(fit_noChirp.gaussian)

    yy_noChirp_gauss = feval( ...
        fit_noChirp.gaussian.result, xx_centered + b_noChirp);

    yy_noChirp_gauss = yy_noChirp_gauss / norm_noChirp;

    plot(xx_centered, yy_noChirp_gauss, '-', ...
        'Color',color_noChirp, ...
        'LineWidth',2.0, ...
        'DisplayName','No chirp — Gaussian');

end


if isfield(fit_noChirp,'lorentzian') && ~isempty(fit_noChirp.lorentzian)

    yy_noChirp_lorentz = feval( ...
        fit_noChirp.lorentzian.result, xx_centered + b_noChirp);

    yy_noChirp_lorentz = yy_noChirp_lorentz / norm_noChirp;

    plot(xx_centered, yy_noChirp_lorentz, '--', ...
        'Color',color_noChirp, ...
        'LineWidth',2.0, ...
        'DisplayName','No chirp — Lorentzian');

end

%% ===================== FWHM MARKERS ==========================

% FWHM values are calculated from the fitted model.
% Lines are shown in the centered coordinate system.

if plot_FWHM

    y_limits = ylim;
    y_fwhm = 0.52;

    % Select the model(s) to display
    model_names = {};

    if strcmpi(fit_type,'gaussian') || strcmpi(fit_type,'both')
        model_names{end+1} = 'gaussian';
    end

    if strcmpi(fit_type,'lorentzian') || strcmpi(fit_type,'both')
        model_names{end+1} = 'lorentzian';
    end

    for k = 1:numel(model_names)

        model = model_names{k};

        % Chirp
        if isfield(fit_chirp,model) && ...
                ~isempty(fit_chirp.(model))

            FWHM = fit_chirp.(model).FWHM;

            plot([-FWHM/2 FWHM/2], ...
                [y_fwhm y_fwhm], ':', ...
                'Color',color_chirp, ...
                'LineWidth',1.0, ...
                'HandleVisibility','off');

        end

        % No chirp
        if isfield(fit_noChirp,model) && ...
                ~isempty(fit_noChirp.(model))

            FWHM = fit_noChirp.(model).FWHM;

            plot([-FWHM/2 FWHM/2], ...
                [y_fwhm-0.04 y_fwhm-0.04], ':', ...
                'Color',color_noChirp, ...
                'LineWidth',1.0, ...
                'HandleVisibility','off');

        end

    end

end

%% ===================== AXES AND LABELS =======================

xlabel('Relative delay (ps)', ...
    'FontSize',12, ...
    'FontName','Arial');

ylabel('Normalized intensity (a.u.)', ...
    'FontSize',12, ...
    'FontName','Arial');

xline(0,'k:', ...
    'LineWidth',0.8, ...
    'HandleVisibility','off');

ylim([0 1.08]);

grid on;
ax = gca;
ax.GridAlpha = 0.12;
ax.GridLineStyle = '-';
ax.Layer = 'bottom';

legend('Location','northeast', ...
    'Box','off', ...
    'FontSize',9, ...
    'Interpreter','none');

set(gca, ...
    'FontName','Arial', ...
    'FontSize',10, ...
    'LineWidth',1.0, ...
    'TickDir','out', ...
    'Box','off');

% No title for publication figure
title('');

%% ===================== FIT INFORMATION ======================

% Prepare annotation text
info_text = {};

info_text{end+1} = sprintf('Centering: fitted maximum');

if isfield(fit_chirp,'gaussian') && ...
        ~isempty(fit_chirp.gaussian)

    info_text{end+1} = sprintf( ...
        'Chirp G: FWHM = %.3f ps, R^2 = %.4f', ...
        fit_chirp.gaussian.FWHM, ...
        fit_chirp.gaussian.R2);

end

if isfield(fit_noChirp,'gaussian') && ...
        ~isempty(fit_noChirp.gaussian)

    info_text{end+1} = sprintf( ...
        'No chirp G: FWHM = %.3f ps, R^2 = %.4f', ...
        fit_noChirp.gaussian.FWHM, ...
        fit_noChirp.gaussian.R2);

end

if isfield(fit_chirp,'lorentzian') && ...
        ~isempty(fit_chirp.lorentzian)

    info_text{end+1} = sprintf( ...
        'Chirp L: FWHM = %.3f ps, R^2 = %.4f', ...
        fit_chirp.lorentzian.FWHM, ...
        fit_chirp.lorentzian.R2);

end

if isfield(fit_noChirp,'lorentzian') && ...
        ~isempty(fit_noChirp.lorentzian)

    info_text{end+1} = sprintf( ...
        'No chirp L: FWHM = %.3f ps, R^2 = %.4f', ...
        fit_noChirp.lorentzian.FWHM, ...
        fit_noChirp.lorentzian.R2);

end

% Annotation
annotation('textbox',[0.17 0.63 0.30 0.22], ...
    'String',info_text, ...
    'FitBoxToText','on', ...
    'BackgroundColor','white', ...
    'EdgeColor',[0.75 0.75 0.75], ...
    'FontName','Arial', ...
    'FontSize',8, ...
    'Interpreter','tex');

%% 
pulse_analysis( ...
    x_chirp_centered, ...
    y_chirp, ...
    x_noChirp_centered, ...
    y_noChirp, ...
    xx_centered, ...
    [yy_chirp_gauss(:), yy_noChirp_gauss(:)]);

%% ===================== SAVE FIGURE ===========================

if save_figure

    exportgraphics(fig, ...
        [figure_name '.pdf'], ...
        'ContentType','vector');

    exportgraphics(fig, ...
        [figure_name '.png'], ...
        'Resolution',600);

end

%% ===================== CONSOLE RESULTS =======================

print_fit_results('CHIRP',fit_chirp);
print_fit_results('NO CHIRP',fit_noChirp);

%% ============================================================
% LOCAL FUNCTIONS
%% ============================================================

function output = perform_fit(x,y,fit_type)

    output = struct();

    % Initial estimates
    [a0,idx] = max(y);
    b0 = x(idx);

    c0 = (max(x)-min(x))/10;

    %% ---------------- GAUSSIAN -------------------------------

    if strcmpi(fit_type,'gaussian') || strcmpi(fit_type,'both')

        % Gaussian:
        % y = a * exp(-0.5*((x-b)/c)^2)

        gauss_model = fittype( ...
            'a*exp(-0.5*((x-b)/c)^2)', ...
            'independent','x', ...
            'coefficients',{'a','b','c'});

        options = fitoptions(gauss_model);
        options.StartPoint = [a0 b0 c0];
        options.Lower = [0 min(x) 0];
        options.Upper = [Inf max(x) Inf];

        [fit_result,gof] = fit( ...
            x,y,gauss_model,options);

        output.gaussian.result = fit_result;
        output.gaussian.R2 = gof.rsquare;
        output.gaussian.RMSE = gof.rmse;

        output.gaussian.a = fit_result.a;
        output.gaussian.b = fit_result.b;
        output.gaussian.c = fit_result.c;

        % Gaussian FWHM
        output.gaussian.FWHM = ...
            2*sqrt(2*log(2))*abs(fit_result.c);

    end

    %% ---------------- LORENTZIAN -----------------------------

    if strcmpi(fit_type,'lorentzian') || strcmpi(fit_type,'both')

        % Lorentzian:
        % y = a / (1+((x-b)/c)^2)

        lorentz_model = fittype( ...
            'a/(1+((x-b)/c)^2)', ...
            'independent','x', ...
            'coefficients',{'a','b','c'});

        options = fitoptions(lorentz_model);
        options.StartPoint = [a0 b0 c0];
        options.Lower = [0 min(x) 0];
        options.Upper = [Inf max(x) Inf];

        [fit_result,gof] = fit( ...
            x,y,lorentz_model,options);

        output.lorentzian.result = fit_result;
        output.lorentzian.R2 = gof.rsquare;
        output.lorentzian.RMSE = gof.rmse;

        output.lorentzian.a = fit_result.a;
        output.lorentzian.b = fit_result.b;
        output.lorentzian.c = fit_result.c;

        % Lorentzian FWHM
        output.lorentzian.FWHM = ...
            2*abs(fit_result.c);

    end

end

%% ============================================================

function value = fit_no_nan(value)

    if isempty(value) || isnan(value)
        value = 0;
    end

end

%% ============================================================

function print_fit_results(name,fit_output)

    fprintf('\n=========================================\n');
    fprintf('%s FIT RESULTS\n',name);
    fprintf('=========================================\n');

    if isfield(fit_output,'gaussian') && ...
            ~isempty(fit_output.gaussian)

        f = fit_output.gaussian;

        fprintf('\n--- GAUSSIAN ---\n');
        fprintf('Amplitude a: %.6f\n',f.a);
        fprintf('Center b:    %.6f ps\n',f.b);
        fprintf('Width c:     %.6f ps\n',f.c);
        fprintf('FWHM:        %.6f ps\n',f.FWHM);
        fprintf('R2:          %.6f\n',f.R2);
        fprintf('RMSE:        %.6f\n',f.RMSE);

    end

    if isfield(fit_output,'lorentzian') && ...
            ~isempty(fit_output.lorentzian)

        f = fit_output.lorentzian;

        fprintf('\n--- LORENTZIAN ---\n');
        fprintf('Amplitude a: %.6f\n',f.a);
        fprintf('Center b:    %.6f ps\n',f.b);
        fprintf('Width c:     %.6f ps\n',f.c);
        fprintf('FWHM:        %.6f ps\n',f.FWHM);
        fprintf('R2:          %.6f\n',f.R2);
        fprintf('RMSE:        %.6f\n',f.RMSE);

    end

end

function pulse_analysis(X1, Y1, X2, Y2, X3, YMatrix1)
%CREATEFIGURE(X1, Y1, X2, Y2, X3, YMatrix1)
%  X1:  vector of plot x data
%  Y1:  vector of plot y data
%  X2:  vector of plot x data
%  Y2:  vector of plot y data
%  X3:  vector of plot x data
%  YMATRIX1:  matrix of plot y data

%  Auto-generated by MATLAB on 24-Sep-2026 08:42:48

% Create figure
figure1 = figure('Color',[1 1 1]);

% Create axes
axes1 = axes('Parent',figure1);
hold(axes1,'on');

% Create plot
plot(X1,Y1,'DisplayName','Chirp data','MarkerSize',8,'Marker','x',...
    'LineWidth',0.8,...
    'LineStyle','none',...
    'Color',[0 0.45 0.74]);

% Create plot
plot(X2,Y2,'DisplayName','No chirp data','MarkerSize',8,'Marker','x',...
    'LineWidth',0.8,...
    'LineStyle','none',...
    'Color',[0.85 0.33 0.1]);

% Create multiple line objects using matrix input to plot
plot1 = plot(X3,YMatrix1,'LineWidth',2);
set(plot1(1),'DisplayName','Chirp — Gaussian','Color',[0 0.45 0.74]);
set(plot1(2),'DisplayName','No chirp — Gaussian','Color',[0.85 0.33 0.1]);

% Create ylabel
ylabel('Normalized intensity (a.u.)','FontName','Arial');

% Create xlabel
xlabel('Relative delay (ps)','FontName','Arial');

% Uncomment the following line to preserve the Y-limits of the axes
% ylim(axes1,[0 1.08]);
grid(axes1,'on');
hold(axes1,'off');
% Set the remaining axes properties
set(axes1,'FontName','Arial','FontSize',15,'GridAlpha',0.12,'LineWidth',1,...
    'TickDir','out');
% Create legend
legend1 = legend(axes1,'show');
set(legend1,...
    'Position',[0.139530700100552 0.686877239148295 0.216063348416289 0.125905797101449],...
    'Interpreter','none',...
    'FontSize',11);

% Create textbox
annotation(figure1,'textbox',...
    [0.136063348416293 0.826449275362321 0.345959417420814 0.0942028985507246],...
    'String',{'Chirp : FWHM = 14.1 ps, R^2 = 0.99','No chirp : FWHM = 4.3 ps, R^2 = 0.99'},...
    'FontSize',11,...
    'FontName','Arial',...
    'EdgeColor',[0.75 0.75 0.75],...
    'BackgroundColor',[1 1 1]);
end