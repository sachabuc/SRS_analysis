
function superpose_spectre(wavenumber_sorted,sp_sorted)

%% --- Données caractéristiques de la vatérite ---
wavenumber = 1050 : 0.1 : 1100;

%% --- Modélisation par somme de Lorentziennes ---
lorentzienne = @(A, x0, gamma, x) A ./ (1 + ((x - x0) / (gamma/2)).^2);

pic1     = lorentzienne(0.40, 1075.0, 4.5, wavenumber);
pic2     = lorentzienne(0.20, 1081.0, 3.5, wavenumber);
pic3     = lorentzienne(1.00, 1091.0, 3.2, wavenumber);
baseline = 0.10 * ones(size(wavenumber));

signal = baseline + pic1 + pic2 + pic3;
signal = signal / max(signal);

%% --- Normalisation de la courbe expérimentale ---
% Recadrage sur la plage 1050-1100 cm-1
mask_exp = wavenumber_sorted >= 1050 & wavenumber_sorted <= 1100;
wn_exp   = wavenumber_sorted(mask_exp);
sp_exp   = sp_sorted(mask_exp);

% Normalisation à 1
sp_exp_norm = (sp_exp - min(sp_exp)) / (max(sp_exp) - min(sp_exp));

%% --- Affichage ---
figure('Color', 'white', 'Position', [100, 100, 800, 550]);

% Courbe théorique
plot(wavenumber, signal, 'b-', 'LineWidth', 2);
hold on;

% Courbe expérimentale
plot(wn_exp, sp_exp_norm, 'r-', 'LineWidth', 1.5);

% Annotations des pics (théoriques)
text(1075, interp1(wavenumber, signal, 1075) + 0.03, '1075 cm^{-1}', ...
    'Color', 'b', 'FontSize', 10, 'HorizontalAlignment', 'center');
text(1081, interp1(wavenumber, signal, 1081) + 0.03, '1081 cm^{-1}', ...
    'Color', 'b', 'FontSize', 10, 'HorizontalAlignment', 'center');
text(1091, interp1(wavenumber, signal, 1091) + 0.03, '1091 cm^{-1}', ...
    'Color', 'b', 'FontSize', 10, 'HorizontalAlignment', 'center');

% Mise en forme
xlabel('Wavenumber (cm^{-1})', 'FontSize', 13);
ylabel('Raman Intensity (a.u.)',  'FontSize', 13);
title('Spectre Raman - Vatérite', 'FontSize', 14);
xlim([1050, 1100]);
ylim([0, 1.15]);
grid on; box on;
set(gca, 'FontSize', 11);

legend({'Vaterite (référence)', 'Expérimental'}, ...
       'Location', 'northwest', 'FontSize', 12);

end