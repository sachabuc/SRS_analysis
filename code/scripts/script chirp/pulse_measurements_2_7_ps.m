%% DATA acquired 

%with chirp

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

x = delay_chirp(:);
y = intensity_chirp(:);

x=x*1e-3; % convert to ps

norm = max(y); 
y = y / norm; % Normalize the intensity_chirp data

%without chirp

shift = 10000;

delay = [3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000, ...
                  11000, 11500, 12000, 12500, 13000, 13500, 14000, ...
                  14500, 15000, 15500, 16000, 16500, 17000, 18000, ...
                  19000, 20000, 21000, 22000, 23000];

delay = delay + shift 

intensity = [660, 720, 975, 1350, 1600, 1480, 1200, 1140, 2500, ...
             5100, 8750, 12500, 14850, 16450, 17100, 17000, 16250, ...
             14600, 12000, 8500, 5800, 3000, 2400, 1500, 1000, 780, 660];



x_noChirp = delay(:) * 1e-3; % convert to ps
y_noChirp = intensity(:) / max(intensity); % Normalize the intensity data without chirp

norm_noChirp = max(y_noChirp); 
y_noChirp = y_noChirp / norm_noChirp; % Normalize the intensity_chirp data

%% --- Initial estimates ---

%w chirp
a0 = max(y);
[~, idx] = max(y);
b0 = x(idx);
c0 = (max(x)-min(x))/10;
d0 = 2;   % shape parameter

%w/o chirp 
a0_noChirp = max(y_noChirp);
[~, idx_noChirp] = max(y_noChirp);
b0_noChirp = x_noChirp(idx_noChirp);
c0_noChirp = (max(x_noChirp) - min(x_noChirp)) / 10;
d0_noChirp = 2;   % shape parameter for no chirp

%% --- Define Super-Lorentzian Model ---
superLorEq = 'a * (1 + ((x-b)/c)^2)^(-d)';
superLorModel = fittype(superLorEq, 'independent','x', ...
    'coefficients',{'a','b','c','d'});

%% --- Fit ---

%w chirp
fitResult = fit(x, y, superLorModel, 'Start', [a0 b0 c0 d0]);

a = fitResult.a;
b = fitResult.b;
c = fitResult.c;
d = fitResult.d;

%w/o chirp

% Fit without chirp
fitResult_noChirp = fit(x_noChirp, y_noChirp, superLorModel, 'Start', [a0_noChirp b0_noChirp c0_noChirp d0_noChirp]);
% Extract parameters from the fit result without chirp
a_noChirp = fitResult_noChirp.a;
b_noChirp = fitResult_noChirp.b;
c_noChirp = fitResult_noChirp.c;
d_noChirp = fitResult_noChirp.d;

%% ===========================================================
%   Compute FWHM and FW5 analytically
%   FW(p) = 2 c sqrt(p^(-1/d) - 1)

%w whirp

% FWHM → p = 0.5
p_half = 0.5;
FWHM = 2 * c * sqrt(p_half^(-1/d) - 1);

% FW at 15% → p = 0.15
p5 = 0.15;
FW5 = 2 * c * sqrt(p5^(-1/d) - 1);

%w/o chirp 
% FWHM → p = 0.5
p_half = 0.5;
FWHM_noChirp = 2 * c_noChirp * sqrt(p_half^(-1/d_noChirp) - 1);

% FW at 15% → p = 0.15
p5 = 0.15;
FW5_noChirp = 2 * c_noChirp * sqrt(p5^(-1/d_noChirp) - 1);

%% --- Generate smooth curve for plotting ---

%w chirp
xx = linspace(min(x), max(x), 3000);
yy = fitResult(xx);

%w/o chir


% Generate smooth curve for plotting without chirp
xx_noChirp = linspace(min(x_noChirp), max(x_noChirp), 3000);
yy_noChirp = fitResult_noChirp(xx_noChirp);

%% --- Plot ---
figure; hold on;

% Raw data
plot(x, y, 'gx', 'MarkerFaceColor','k', 'DisplayName','Chirp Data'); %chirp 
plot(x_noChirp, y_noChirp, 'b*', 'MarkerFaceColor','k', 'DisplayName','Not chirp Data'); %no chirp

% Fit curve
plot(xx, yy, 'g-', 'LineWidth', 2, 'DisplayName','Chirp Lorentzian Fit'); %chirp 
plot(xx_noChirp, yy_noChirp, 'b-', 'LineWidth', 2, 'DisplayName','Not chirp Lorentzian Fit'); %no chirp 

% Plot FWHM line
y_half = a * p_half;
plot([b - FWHM/2, b + FWHM/2], [y_half, y_half], 'g-.', 'LineWidth', 1.4, ...
    'DisplayName', sprintf('FWHM (chirp) = %.4f', FWHM));

% Plot FWHM line without chirp
y_half_noChirp = a_noChirp * p_half;
plot([b_noChirp - FWHM_noChirp/2, b_noChirp + FWHM_noChirp/2], [y_half_noChirp, y_half_noChirp], 'b-.', 'LineWidth', 1.4, ...
    'DisplayName', sprintf('FWHM (noChirp) = %.4f', FWHM_noChirp));


% % Plot FW5 line
% y_5 = a * p5;
% plot([b - FW5/2, b + FW5/2], [y_5, y_5], 'g-.', 'LineWidth', 1.4, ...
%     'DisplayName', sprintf('FW5 (chirp) = %.4f', FW5));
% 
% % Plot FW5 line without chirp
% y_5_noChirp = a_noChirp * p5;
% plot([b_noChirp - FW5_noChirp/2, b_noChirp + FW5_noChirp/2], [y_5_noChirp, y_5_noChirp], 'g--', 'LineWidth', 1.4, ...
%     'DisplayName', sprintf('FW5 (no chirp) = %.4f', FW5_noChirp));


xlabel('delay (ps)');
ylabel('intensity');
title('Lorentzian Fit of intensity function of delay with and without chirp');
legend('Location','best');


grid on;


%% --- Print results in console ---
fprintf('\n===== SUPER-LORENTZIAN FIT RESULTS without chirp =====\n');
fprintf('Amplitude a (noChirp):       %.6f\n', a_noChirp);
fprintf('Center b (noChirp):          %.6f\n', b_noChirp);
fprintf('Width c (noChirp):           %.6f\n', c_noChirp);
fprintf('Shape d (noChirp):           %.6f\n', d_noChirp);
fprintf('----------------------------------------\n');
fprintf('FWHM (noChirp):                %.6f\n', FWHM_noChirp);
fprintf('FW (noChirp) at 15%%:            %.6f\n', FW5_noChirp);
fprintf('=========================================\n\n');

fprintf('\n===== SUPER-LORENTZIAN FIT RESULTS with chirp =====\n');
fprintf('Amplitude (a):       %.6f\n', a);
fprintf('Center (b):          %.6f\n', b);
fprintf('Width (c):           %.6f\n', c);
fprintf('Shape (d):           %.6f\n', d);
fprintf('----------------------------------------\n');
fprintf('FWHM:                %.6f\n', FWHM);
fprintf('FW at 15%%:            %.6f\n', FW5);
fprintf('=========================================\n\n');