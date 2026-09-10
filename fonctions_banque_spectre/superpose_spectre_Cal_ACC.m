function superpose_spectre_Cal_ACC(wavenumber_sorted, sp_sorted, tau_fwhm)
%% superpose_spectre_Vaterite
%  Compare le spectre théorique de la vatérite (somme de Lorentziennes)
%  avec le spectre expérimental, en tenant compte de la réponse instrumentale.
%
%  ENTRÉES :
%    wavenumber_sorted : vecteur des nombres d'onde expérimentaux (cm-1), triés
%    sp_sorted         : vecteur d'intensité correspondant
%    tau_fwhm          : largeur à mi-hauteur de la réponse instrumentale (cm-1)
%                        → si omis, tau_fwhm = 0 (pas de convolution)
%
%  EXEMPLE D'APPEL :
%    superpose_spectre_Vaterite(wn_exp, sp_exp, 3.0)
 
if nargin < 3 || isempty(tau_fwhm)
    tau_fwhm = 0;   % pas de convolution par défaut
end
 
%% --- Grille commune haute résolution ---
wn_min = 1020;
wn_max = 1130;
dw     = 0.05;                              % pas fin pour la convolution
wavenumber = wn_min : dw : wn_max;          % grille théorique
 
%% --- Modélisation par somme de Lorentziennes ---
lorentzienne = @(A, x0, gamma, x) A ./ (1 + ((x - x0) / (gamma/2)).^2);
 
pic1     = lorentzienne(0.8, 1079, 15, wavenumber);
pic2     = lorentzienne(1.00, 1089.0, 2, wavenumber);
baseline = 0 * ones(size(wavenumber));
 
signal = baseline + pic1 + pic2 ;
signal = signal / max(signal);              % normalisation 0-1
 
%% --- Convolution avec la réponse instrumentale (gaussienne FWHM = tau_fwhm) ---
if tau_fwhm > 0
    sigma_wn = tau_fwhm / (2 * sqrt(2 * log(2)));   % FWHM → sigma
 
    % Noyau gaussien centré, même pas que wavenumber
    half_win = 4 * sigma_wn;                         % fenêtre ±4σ
    wn_kernel = -half_win : dw : half_win;
    kernel    = exp(-wn_kernel.^2 / (2 * sigma_wn^2));
    kernel    = kernel / sum(kernel);                 % normalisation aire = 1

 
    % Convolution (mode 'same' → même longueur)
    n_pad       = length(wn_kernel);
    signal_pad  = [signal(1)*ones(1,n_pad), signal, signal(end)*ones(1,n_pad)];
    conv_pad    = conv(signal_pad, kernel, 'same');
    signal_conv = conv_pad(n_pad+1 : n_pad+length(signal));  % recadrage
    signal_conv = signal_conv / max(signal_conv);     % normalisation 0-1


else
    signal_conv = signal;
end
 
%% --- Normalisation de la courbe expérimentale ---
mask_exp    = wavenumber_sorted >= wn_min & wavenumber_sorted <= wn_max;
wn_exp      = wavenumber_sorted(mask_exp);
sp_exp      = sp_sorted(mask_exp);
sp_exp_norm = (sp_exp - min(sp_exp)) / (max(sp_exp) - min(sp_exp));
 
%% --- Affichage ---
figure('Color', 'white', 'Position', [100, 100, 900, 580]);
 
% Courbe théorique brute (en pointillés légers)
if tau_fwhm > 0
    plot(wavenumber, signal, 'b--', 'LineWidth', 1.0, 'Color', [0.4 0.6 1.0]);
    hold on;
end
 
% Courbe théorique convoluée (trait plein bleu)
plot(wavenumber, signal_conv, 'b-', 'LineWidth', 2.2);
hold on;
 
% Courbe expérimentale — ligne + points
plot(wn_exp, sp_exp_norm, 'r-',  'LineWidth', 1.5);
plot(wn_exp, sp_exp_norm, 'ko',  'MarkerSize', 6, ...
     'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k');
 
%% --- Annotations des pics théoriques ---
pic_pos = [1079, 1089];
for k = 1:numel(pic_pos)
    y_pic = interp1(wavenumber, signal, pic_pos(k));
    text(pic_pos(k), y_pic + 0.04, sprintf('%d cm^{-1}', pic_pos(k)), ...
         'Color', 'b', 'FontSize', 10, 'HorizontalAlignment', 'center');
end
 
%% --- Mise en forme ---
xlabel('Wavenumber (cm^{-1})',   'FontSize', 13);
ylabel('Raman Intensity (a.u.)', 'FontSize', 13);
 
if tau_fwhm > 0
    title(sprintf('Spectre SRS – Cal + ACC  |  instrumental response FWHM = %.1f cm^{-1}', tau_fwhm), ...
          'FontSize', 13);
else
    title('Spectre Raman – Cal + ACC', 'FontSize', 14);
end
 
xlim([wn_min, wn_max]);
ylim([0, 1.20]);
grid on; box on;
set(gca, 'FontSize', 11);
 
% Légende adaptative
if tau_fwhm > 0
    legend({'theoritical Cal + ACC', ...
            sprintf('theoriticals \\otimes instrumental response'), ...
            'Experimental measurements'}, ...
           'Location', 'northwest', 'FontSize', 11);
else
    legend({'theoritical Cal + ACC', 'Expérimental'}, ...
           'Location', 'northwest', 'FontSize', 12);
end
 
end




