function superpose_spectre_Calcite(wavenumber_sorted, sp_sorted, tau_fwhm, wavenumber_sorted2, sp_sorted2)
%% superpose_spectre_Calcite
%  ENTRÉES :
%    wavenumber_sorted  : vecteur des nombres d'onde expérimentaux (cm-1), triés
%    sp_sorted          : vecteur d'intensité correspondant
%    tau_fwhm           : largeur à mi-hauteur de la réponse instrumentale (cm-1)
%    wavenumber_sorted2 : (optionnel) second spectre expérimental - nombres d'onde
%    sp_sorted2         : (optionnel) second spectre expérimental - intensités

if nargin < 3 || isempty(tau_fwhm)
    tau_fwhm = 0;
end
has_second = nargin >= 5 && ~isempty(wavenumber_sorted2) && ~isempty(sp_sorted2);

%% --- Grille commune haute résolution ---
wn_min = 1060;
wn_max = 1110;
dw     = 0.05;
wavenumber = wn_min : dw : wn_max;

%% --- Modélisation par somme de Lorentziennes ---
lorentzienne = @(A, x0, gamma, x) A ./ (1 + ((x - x0) / (gamma/2)).^2);

pic1     = lorentzienne(1, 1086.0, 2, wavenumber);
baseline = 0 * ones(size(wavenumber));

signal = baseline + pic1;
signal = signal / max(signal);

%% --- Convolution avec la réponse instrumentale ---
if tau_fwhm > 0
    sigma_wn = tau_fwhm / (2 * sqrt(2 * log(2)));

    half_win = 4 * sigma_wn;
    wn_kernel = -half_win : dw : half_win;
    kernel    = exp(-wn_kernel.^2 / (2 * sigma_wn^2));
    kernel    = kernel / sum(kernel);

    n_pad       = length(wn_kernel);
    signal_pad  = [signal(1)*ones(1,n_pad), signal, signal(end)*ones(1,n_pad)];
    conv_pad    = conv(signal_pad, kernel, 'same');
    signal_conv = conv_pad(n_pad+1 : n_pad+length(signal));
    signal_conv = signal_conv / max(signal_conv);
else
    signal_conv = signal;
end

%% --- Normalisation spectre expérimental 1 ---
mask_exp    = wavenumber_sorted >= wn_min & wavenumber_sorted <= wn_max;
wn_exp      = wavenumber_sorted(mask_exp);
sp_exp      = sp_sorted(mask_exp);
sp_exp_norm = (sp_exp - min(sp_exp)) / (max(sp_exp) - min(sp_exp));

%% --- Normalisation spectre expérimental 2 (si fourni) ---
if has_second
    mask_exp2    = wavenumber_sorted2 >= wn_min & wavenumber_sorted2 <= wn_max;
    wn_exp2      = wavenumber_sorted2(mask_exp2);
    sp_exp2      = sp_sorted2(mask_exp2);
    sp_exp2_norm = (sp_exp2 - min(sp_exp2)) / (max(sp_exp2) - min(sp_exp2));
end

%% --- Affichage ---
figure('Color', 'white', 'Position', [100, 100, 900, 580]);

if tau_fwhm > 0
    plot(wavenumber, signal, 'k', 'LineWidth', 1.0);
    hold on;
end

plot(wavenumber, signal_conv, 'b-', 'LineWidth', 2.2);
hold on;

plot(wn_exp, sp_exp_norm, 'r-',  'LineWidth', 1.5);
plot(wn_exp, sp_exp_norm, 'ko',  'MarkerSize', 6, ...
     'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k');

if has_second
    plot(wn_exp2, sp_exp2_norm, 'm-',  'LineWidth', 1.5);
    plot(wn_exp2, sp_exp2_norm, 'ko',  'MarkerSize', 6, ...
         'MarkerFaceColor', 'm', 'MarkerEdgeColor', 'k');
end

%% --- Annotations des pics théoriques ---
pic_pos = [1086];
for k = 1:numel(pic_pos)
    y_pic = interp1(wavenumber, signal, pic_pos(k));
    text(pic_pos(k), y_pic + 0.04, sprintf('%d cm^{-1}', pic_pos(k)), ...
         'Color', 'b', 'FontSize', 10, 'HorizontalAlignment', 'center');
end

%% --- Mise en forme ---
xlabel('Wavenumber (cm^{-1})',        'FontSize', 13);
ylabel('Raman Intensity (normalized)', 'FontSize', 13);

if tau_fwhm > 0
    title(sprintf('Spectre SRS – Calcite  |  instrumental response FWHM = %.1f cm^{-1}', tau_fwhm), ...
          'FontSize', 13);
else
    title('Spectre Raman – Calcite', 'FontSize', 14);
end

xlim([wn_min, wn_max]);
ylim([0, 1.20]);
grid on; box on;
set(gca, 'FontSize', 11);

%% --- Légende adaptative ---
if tau_fwhm > 0
    leg = {'Theoretical calcite', ...
           sprintf('Theoretical calcite \\otimes instrumental response'), ...
           'Experimental spectrum 1'};
    if has_second
        leg{end+1} = 'Experimental spectrum 2';
    end
else
    leg = {'Calcite', 'Experimental spectrum 1'};
    if has_second
        leg{end+1} = 'Experimental spectrum 2';
    end
end
legend(leg, 'Location', 'northwest', 'FontSize', 11);

end




