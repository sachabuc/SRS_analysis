%% Lecture d'un spectre Raman - fichier .l6s
% Fichier : vat_alons_ter_x100.l6s
% Format LabSpec 6 (HORIBA) - fichier texte avec en-têtes
 
clc; clear; close all;
 
%% --- Paramètres ---
filename = 'C:\Users\sacha.bucourt\Documents\Data lab\spectres raman spontanée\200226\vat_alons_ter_x100.l6s';
 
%% --- Lecture du fichier ---
fid = fopen(filename, 'r');
if fid == -1
    error('Impossible d''ouvrir le fichier : %s', filename);
end
 
% Lire toutes les lignes pour détecter l'en-tête
header_lines = 0;
data_start    = false;
 
while ~feof(fid)
    line = fgetl(fid);
    if ischar(line)
        % Le fichier .l6s de LabSpec contient un bloc d'en-tête
        % Les données commencent quand la ligne contient deux nombres
        tokens = strsplit(strtrim(line));
        if numel(tokens) >= 2
            val1 = str2double(tokens{1});
            val2 = str2double(tokens{2});
            if ~isnan(val1) && ~isnan(val2)
                data_start = true;
                break;
            end
        end
        header_lines = header_lines + 1;
    end
end
fclose(fid);
 
fprintf('Nombre de lignes d''en-tête détectées : %d\n', header_lines);
 
%% --- Import des données numériques ---
try
    % Méthode 1 : readmatrix (MATLAB R2019a+)
    opts = detectImportOptions(filename, 'FileType', 'text');
    opts.DataLines          = [header_lines + 1, Inf];
    opts.Delimiter          = {'\t', ' '};
    opts.ConsecutiveDelimitersRule = 'join';
    opts.LeadingDelimitersRule     = 'ignore';
    M = readmatrix(filename, opts);
catch
    % Méthode 2 : dlmread (ancienne syntaxe)
    M = dlmread(filename, '\t', header_lines, 0);
end
 
% Colonnes : colonne 1 = déplacement Raman (cm-1), colonne 2 = intensité
wavenumber = M(:, 1);
intensity  = M(:, 2);
 
fprintf('Spectre chargé : %d points  |  %.1f – %.1f cm⁻¹\n', ...
    numel(wavenumber), min(wavenumber), max(wavenumber));
 
%% --- Affichage ---
figure('Name', 'Spectre Raman', 'NumberTitle', 'off', 'Color', 'w');
plot(wavenumber, intensity, 'b-', 'LineWidth', 1.2);
xlabel('Déplacement Raman (cm^{-1})', 'FontSize', 13);
ylabel('Intensité (u.a.)',            'FontSize', 13);
title(strrep(filename, '_', '\_'),    'FontSize', 14, 'FontWeight', 'bold');
grid on;
xlim([min(wavenumber) max(wavenumber)]);
set(gca, 'FontSize', 11, 'Box', 'on');
 
%% --- Pic principal ---
[I_max, idx_max] = max(intensity);
wn_max = wavenumber(idx_max);
fprintf('Pic principal : %.1f cm⁻¹  (intensité = %.0f)\n', wn_max, I_max);
hold on;
plot(wn_max, I_max, 'rv', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
text(wn_max + 10, I_max, sprintf(' %.0f cm^{-1}', wn_max), ...
    'Color', 'r', 'FontSize', 11);
 
%% --- Export optionnel des données en .txt ---
out_txt = strrep(filename, '.l6s', '_spectre.txt');
writematrix([wavenumber, intensity], out_txt, 'Delimiter', '\t');
fprintf('Données exportées dans : %s\n', out_txt);