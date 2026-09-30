function plot_compare_ref_roi(ref_roi, ref_roi_compare, noise_global)
%PLOT_COMPARE_REF_ROI
%
% Compare deux acquisitions à partir de deux structures ref_roi.
%
% Fonctionne avec :
%   - 1 phase dans chaque acquisition
%   - 2 phases dans chaque acquisition
%
% Convention avec 2 phases :
%   ref_roi(1)         = phase 1, acquisition 7 ps
%   ref_roi(2)         = phase 2, acquisition 7 ps
%
%   ref_roi_compare(1) = phase 1, acquisition 2 ps
%   ref_roi_compare(2) = phase 2, acquisition 2 ps
%
% Avec 1 seule phase :
%   ref_roi(1)         = phase unique, acquisition 7 ps
%   ref_roi_compare(1) = phase unique, acquisition 2 ps
%
% Les spectres sont normalisés par le maximum de la phase 1
% lorsque deux phases sont présentes.
%
% Avec une seule phase, chaque acquisition est normalisée par
% son propre maximum pour l'affichage des spectres.
%
% Le panneau (b) devient alors le rapport :
%
%       signal 2 ps / signal 7 ps
%
% pour la phase unique.
%
% INPUTS
%   ref_roi
%   ref_roi_compare
%   noise_global : seuil SNR affiché sur le panneau (c)
%
% Les structures doivent contenir au minimum :
%   .mean_spectrum
%   .wavenumber
%
% et éventuellement :
%   .std_spectrum
%   .SNR
%   .phase_name
%   .name


%% ================================================================
% PARAMETRES
%% ================================================================

n_phase_ref     = numel(ref_roi);
n_phase_compare = numel(ref_roi_compare);

assert(n_phase_ref == n_phase_compare, ...
    ['ref_roi et ref_roi_compare doivent contenir le ', ...
     'meme nombre de phases.']);

assert(n_phase_ref == 1 || n_phase_ref == 2, ...
    'Cette fonction est prevue pour 1 ou 2 phases.');

n_phases = n_phase_ref;

% Indices
idx_phase1 = 1;

if n_phases == 2
    idx_phase2 = 2;
else
    idx_phase2 = [];
end

% Couleurs
color_phase1 = [0.0000 0.4470 0.7410];
color_phase2 = [0.8500 0.3250 0.0980];

% Style des acquisitions
lineStyle_ref     = '--';   % 7 ps
lineStyle_compare = '-';    % 2 ps

% Largeur des courbes
lineWidth = 2.0;

% Taille des marqueurs
markerSize_phase1 = 6;
markerSize_phase2 = 6;

% Affichage des marqueurs
show_markers = true;

% Affichage des valeurs
show_ratio_values = true;
show_SNR_values = true;

% Limites spectrales optionnelles
use_xlim = false;
xlim_values = [1060 1110];


%% ================================================================
% VERIFICATION
%% ================================================================

if nargin < 3 || isempty(noise_global)
    noise_global = NaN;
end


%% ================================================================
% NOMS DES PHASES
%% ================================================================

% ------------------------------------------------
% Phase 1

if isfield(ref_roi(idx_phase1),'name') && ...
        ~isempty(ref_roi(idx_phase1).name)

    phase_name_1 = char(string(ref_roi(idx_phase1).name));

elseif isfield(ref_roi(idx_phase1),'phase_name') && ...
        ~isempty(ref_roi(idx_phase1).phase_name)

    phase_name_1 = char(string(ref_roi(idx_phase1).phase_name));

else

    phase_name_1 = 'Phase 1';

end


% ------------------------------------------------
% Phase 2 uniquement si elle existe

if n_phases == 2

    if isfield(ref_roi(idx_phase2),'name') && ...
            ~isempty(ref_roi(idx_phase2).name)

        phase_name_2 = char(string(ref_roi(idx_phase2).name));

    elseif isfield(ref_roi(idx_phase2),'phase_name') && ...
            ~isempty(ref_roi(idx_phase2).phase_name)

        phase_name_2 = char(string(ref_roi(idx_phase2).phase_name));

    else

        phase_name_2 = 'Phase 2';

    end

end


%% ================================================================
% EXTRACTION DES SPECTRES
%% ================================================================

phase1_ref = ref_roi(idx_phase1).mean_spectrum(:);
phase1_comp = ref_roi_compare(idx_phase1).mean_spectrum(:);

if n_phases == 2

    phase2_ref = ref_roi(idx_phase2).mean_spectrum(:);
    phase2_comp = ref_roi_compare(idx_phase2).mean_spectrum(:);

end


%% ================================================================
% WAVENUMBER
%% ================================================================

wn_ref = ref_roi(idx_phase1).wavenumber(:);
wn_comp = ref_roi_compare(idx_phase1).wavenumber(:);


%% ================================================================
% VERIFICATIONS
%% ================================================================

assert(numel(wn_ref) == numel(phase1_ref), ...
    'wavenumber et phase 1 de ref_roi incompatibles.');

assert(numel(wn_comp) == numel(phase1_comp), ...
    'wavenumber et phase 1 de ref_roi_compare incompatibles.');

if n_phases == 2

    assert(numel(wn_ref) == numel(phase2_ref), ...
        'wavenumber et phase 2 de ref_roi incompatibles.');

    assert(numel(wn_comp) == numel(phase2_comp), ...
        'wavenumber et phase 2 de ref_roi_compare incompatibles.');

end


%% ================================================================
% SOUSTRACTION DU MINIMUM
%% ================================================================

phase1_ref_0 = phase1_ref - min(phase1_ref);
phase1_comp_0 = phase1_comp - min(phase1_comp);

if n_phases == 2

    phase2_ref_0 = phase2_ref - min(phase2_ref);
    phase2_comp_0 = phase2_comp - min(phase2_comp);

end


%% ================================================================
% NORMALISATION
%% ================================================================

% Maximum de la phase 1 dans chaque acquisition

phase1_max_ref = max(phase1_ref_0);
phase1_max_comp = max(phase1_comp_0);

if phase1_max_ref <= 0
    error('Maximum de %s à 7 ps <= 0.',phase_name_1);
end

if phase1_max_comp <= 0
    error('Maximum de %s à 2 ps <= 0.',phase_name_1);
end


if n_phases == 2

    % ------------------------------------------------------------
    % CAS 2 PHASES
    %
    % Chaque acquisition est normalisée par son propre maximum
    % de la phase 1.

    phase1_ref_norm = phase1_ref_0 / phase1_max_ref;
    phase2_ref_norm = phase2_ref_0 / phase1_max_ref;

    phase1_comp_norm = phase1_comp_0 / phase1_max_comp;
    phase2_comp_norm = phase2_comp_0 / phase1_max_comp;

else

    % ------------------------------------------------------------
    % CAS 1 PHASE
    %
    % Pour comparer uniquement la forme spectrale, chaque
    % acquisition est normalisée par son propre maximum.

    phase1_ref_norm = phase1_ref_0 / phase1_max_ref;
    phase1_comp_norm = phase1_comp_0 / phase1_max_comp;

end


%% ================================================================
% RAPPORT D'INTENSITE
%% ================================================================

if n_phases == 2

  
    % ------------------------------------------------------------
    % CAS 2 PHASES :
    % rapport phase 2 / phase 1



    ratio_ref = ref_roi_compare(2).peak_height_phase_fit ./ ...
        ref_roi_compare(1).peak_height_phase_fit;

    ratio_comp = ref_roi(2).peak_height_phase_fit ./ ...
        ref_roi(1).peak_height_phase_fit;

    % A_phase1_ref = max(phase1_ref_0);
    % A_phase2_ref = max(phase2_ref_0);
    % 
    % A_phase1_comp = max(phase1_comp_0);
    % A_phase2_comp = max(phase2_comp_0);
    % 
    % ratio_ref = A_phase2_ref / A_phase1_ref;
    % ratio_comp = A_phase2_comp / A_phase1_comp;

    ratio_values = [ratio_ref ratio_comp];

else

    % ------------------------------------------------------------
    % CAS 1 PHASE :
    % rapport de signal 2 ps / 7 ps

    A_phase1_ref = max(phase1_ref_0);
    A_phase1_comp = max(phase1_comp_0);

    ratio_ref = 1;
    ratio_comp = A_phase1_comp / A_phase1_ref;

    ratio_values = [ratio_ref ratio_comp];

end


%% ================================================================
% SNR
%% ================================================================

SNR_phase1_ref = getSNR(ref_roi(idx_phase1));
SNR_phase1_comp = getSNR(ref_roi_compare(idx_phase1));

if n_phases == 2

    SNR_phase2_ref = getSNR(ref_roi(idx_phase2));
    SNR_phase2_comp = getSNR(ref_roi_compare(idx_phase2));

    SNR_values = [ ...
        SNR_phase2_ref   SNR_phase2_comp;
        SNR_phase1_ref   SNR_phase1_comp];

else

    SNR_values = [ ...
        SNR_phase1_ref   SNR_phase1_comp];

end


%% ================================================================
% FIGURE A — SPECTRES
%% ================================================================

figure( ...
    'Color','white', ...
    'Position',[100 100 1100 850]);

hold on;


%% ------------------------------------------------
% 7 ps — phase 2
%% ------------------------------------------------

if n_phases == 2

    if show_markers

        plot( ...
            wn_ref, ...
            phase2_ref_norm, ...
            'Color',color_phase2, ...
            'LineStyle',lineStyle_ref, ...
            'LineWidth',lineWidth, ...
            'Marker','*', ...
            'MarkerSize',markerSize_phase2, ...
            'DisplayName',sprintf('%s — 7 ps',phase_name_2));

    else

        plot( ...
            wn_ref, ...
            phase2_ref_norm, ...
            'Color',color_phase2, ...
            'LineStyle',lineStyle_ref, ...
            'LineWidth',lineWidth, ...
            'DisplayName',sprintf('%s — 7 ps',phase_name_2));

    end

end


%% ------------------------------------------------
% 7 ps — phase 1
%% ------------------------------------------------

plot( ...
    wn_ref, ...
    phase1_ref_norm, ...
    'Color',color_phase1, ...
    'LineStyle',lineStyle_ref, ...
    'LineWidth',lineWidth, ...
    'Marker','x', ...
    'MarkerSize',markerSize_phase1, ...
    'DisplayName',sprintf('%s — 7 ps',phase_name_1));


%% ------------------------------------------------
% 2 ps — phase 2
%% ------------------------------------------------

if n_phases == 2

    if show_markers

        plot( ...
            wn_comp, ...
            phase2_comp_norm, ...
            'Color',color_phase2, ...
            'LineStyle',lineStyle_compare, ...
            'LineWidth',lineWidth, ...
            'Marker','*', ...
            'MarkerSize',markerSize_phase2, ...
            'DisplayName',sprintf('%s — 2 ps',phase_name_2));

    else

        plot( ...
            wn_comp, ...
            phase2_comp_norm, ...
            'Color',color_phase2, ...
            'LineStyle',lineStyle_compare, ...
            'LineWidth',lineWidth, ...
            'DisplayName',sprintf('%s — 2 ps',phase_name_2));

    end

end


%% ------------------------------------------------
% 2 ps — phase 1
%% ------------------------------------------------

plot( ...
    wn_comp, ...
    phase1_comp_norm, ...
    'Color',color_phase1, ...
    'LineStyle',lineStyle_compare, ...
    'LineWidth',lineWidth, ...
    'Marker','x', ...
    'MarkerSize',markerSize_phase1, ...
    'DisplayName',sprintf('%s — 2 ps',phase_name_1));


%% ------------------------------------------------
% Ligne phase 1 = 1
%% ------------------------------------------------

yline( ...
    1, ...
    ':', ...
    'Color',[0.4 0.4 0.4], ...
    'LineWidth',1.2, ...
    'HandleVisibility','off');


grid on;

xlabel('Raman shift (cm^{-1})');
ylabel('Normalized intensity');


if n_phases == 2

    title(sprintf('(a) %s and %s spectra', ...
        phase_name_2,phase_name_1));

else

    title(sprintf('(a) %s spectra', ...
        phase_name_1));

end


legend( ...
    'Location','northeast', ...
    'Box','off');


set(gca, ...
    'FontName','Arial', ...
    'FontSize',12, ...
    'LineWidth',1, ...
    'TickDir','out');


if use_xlim
    xlim(xlim_values);
end


%% ================================================================
% FIGURE B — RATIO + SNR
%% ================================================================

figure( ...
    'Color','white', ...
    'Position',[100 100 1100 850]);

tiledlayout(2,1, ...
    'TileSpacing','compact', ...
    'Padding','compact');


%% ================================================================
% PANEL B — RATIO
%% ================================================================

nexttile;

hold on;
box on;

x_ratio = [1 2];

b = bar( ...
    x_ratio, ...
    ratio_values, ...
    0.55, ...
    'FaceColor','flat');


if n_phases == 2

    % Même couleur car il s'agit du rapport phase 2 / phase 1
    b.CData(1,:) = color_phase2;
    b.CData(2,:) = color_phase2;

    ylabel(sprintf('%s / %s', ...
        phase_name_2,phase_name_1));

    title(sprintf('(b) Relative %s-to-%s signal', ...
        phase_name_2,phase_name_1));

else

    % Une seule phase :
    % rapport du signal 2 ps / 7 ps

    b.CData(1,:) = color_phase1;
    b.CData(2,:) = color_phase1;

    ylabel(sprintf('%s (2 ps / 7 ps)', ...
        phase_name_1));

    title(sprintf('(b) %s signal ratio: 2 ps / 7 ps', ...
        phase_name_1));

end


yline( ...
    1, ...
    ':', ...
    'Color',[0.4 0.4 0.4], ...
    'LineWidth',1.2, ...
    'HandleVisibility','off');


set(gca, ...
    'XTick',x_ratio, ...
    'XTickLabel',{'7 ps','2 ps'}, ...
    'FontName','Arial', ...
    'FontSize',12, ...
    'LineWidth',1, ...
    'TickDir','out');


if show_ratio_values

    for i = 1:2

        text( ...
            x_ratio(i), ...
            ratio_values(i), ...
            sprintf(' %.2f',ratio_values(i)), ...
            'VerticalAlignment','bottom', ...
            'HorizontalAlignment','center', ...
            'FontSize',11);

    end

end


%% ================================================================
% PANEL C — SNR
%% ================================================================

nexttile;

hold on;
box on;

x = [1 2];

bar_width = 0.32;


if n_phases == 2

    %% ------------------------------------------------
    % Phase 2
    %% ------------------------------------------------

    bar( ...
        x - bar_width/2, ...
        SNR_values(1,:), ...
        bar_width, ...
        'FaceColor',color_phase2, ...
        'EdgeColor','none', ...
        'DisplayName',phase_name_2);


    %% ------------------------------------------------
    % Phase 1
    %% ------------------------------------------------

    bar( ...
        x + bar_width/2, ...
        SNR_values(2,:), ...
        bar_width, ...
        'FaceColor',color_phase1, ...
        'EdgeColor','none', ...
        'DisplayName',phase_name_1);

else

    %% ------------------------------------------------
    % Phase unique
    %% ------------------------------------------------

    bar( ...
        x, ...
        SNR_values(1,:), ...
        0.55, ...
        'FaceColor',color_phase1, ...
        'EdgeColor','none', ...
        'DisplayName',phase_name_1);

end


%% ------------------------------------------------
% Seuil SNR
%% ------------------------------------------------

if isfinite(noise_global)

    yline( ...
        noise_global, ...
        '--', ...
        'Color',[0.4 0.4 0.4], ...
        'LineWidth',1.2, ...
        'DisplayName',sprintf('SNR = %.2f',noise_global));

end


set(gca, ...
    'XTick',x, ...
    'XTickLabel',{'7 ps','2 ps'}, ...
    'FontName','Arial', ...
    'FontSize',12, ...
    'LineWidth',1, ...
    'TickDir','out');


xlabel('Acquisition');
ylabel('SNR');

title('(c) Signal-to-noise ratio');

legend( ...
    'Location','northwest', ...
    'Box','off');


%% ------------------------------------------------
% Valeurs SNR
%% ------------------------------------------------

if show_SNR_values

    if n_phases == 2

        % ------------------------------------------------
        % Phase 2

        for i = 1:2

            text( ...
                x(i)-bar_width/2, ...
                SNR_values(1,i), ...
                sprintf(' %.1f',SNR_values(1,i)), ...
                'VerticalAlignment','bottom', ...
                'HorizontalAlignment','center', ...
                'FontSize',10);

        end


        % ------------------------------------------------
        % Phase 1

        for i = 1:2

            text( ...
                x(i)+bar_width/2, ...
                SNR_values(2,i), ...
                sprintf(' %.1f',SNR_values(2,i)), ...
                'VerticalAlignment','bottom', ...
                'HorizontalAlignment','center', ...
                'FontSize',10);

        end

    else

        % ------------------------------------------------
        % Phase unique

        for i = 1:2

            text( ...
                x(i), ...
                SNR_values(1,i), ...
                sprintf(' %.1f',SNR_values(1,i)), ...
                'VerticalAlignment','bottom', ...
                'HorizontalAlignment','center', ...
                'FontSize',10);

        end

    end

end


%% ================================================================
% STYLE GLOBAL
%% ================================================================

ax = findall(gcf,'Type','axes');

set(ax, ...
    'FontName','Arial', ...
    'FontSize',12, ...
    'LineWidth',1, ...
    'TickDir','out');


%% ================================================================
% CONSOLE
%% ================================================================

fprintf('\n');
fprintf('====================================================\n');

if n_phases == 2

    fprintf('       COMPARISON %s / %s — 7 ps vs 2 ps\n', ...
        phase_name_2,phase_name_1);

else

    fprintf('       COMPARISON %s — 7 ps vs 2 ps\n', ...
        phase_name_1);

end

fprintf('====================================================\n');


if n_phases == 2

    fprintf('\n%s / %s:\n', ...
        phase_name_2,phase_name_1);

    fprintf('  7 ps : %.4f\n',ratio_ref);
    fprintf('  2 ps : %.4f\n',ratio_comp);

    fprintf('\nEvolution du rapport : %.2f %%\n', ...
        100*(ratio_comp/ratio_ref - 1));

else

    fprintf('\n%s — rapport 2 ps / 7 ps:\n', ...
        phase_name_1);

    fprintf('  7 ps : %.4f\n',ratio_ref);
    fprintf('  2 ps : %.4f\n',ratio_comp);

    fprintf('\nEvolution du signal : %.2f %%\n', ...
        100*(ratio_comp - 1));

end


%% ------------------------------------------------
% SNR
%% ------------------------------------------------

fprintf('\nSNR %s:\n',phase_name_1);

fprintf('  7 ps : %.2f\n',SNR_phase1_ref);
fprintf('  2 ps : %.2f\n',SNR_phase1_comp);


if n_phases == 2

    fprintf('\nSNR %s:\n',phase_name_2);

    fprintf('  7 ps : %.2f\n',SNR_phase2_ref);
    fprintf('  2 ps : %.2f\n',SNR_phase2_comp);

end

fprintf('\n====================================================\n');


end


%% =================================================================
% FONCTION LOCALE — EXTRACTION / CALCUL DU SNR
%% =================================================================

function SNR = getSNR(entry)

% --------------------------------------------------------------
% CAS 1 : SNR déjà présent
% --------------------------------------------------------------

if isfield(entry,'SNR') && ~isempty(entry.SNR)

    SNR = entry.SNR;

    return;

end


% --------------------------------------------------------------
% CAS 2 : calcul depuis mean_spectrum/std_spectrum
% --------------------------------------------------------------

if isfield(entry,'mean_spectrum') && ...
        isfield(entry,'std_spectrum')

    spectrum = entry.mean_spectrum(:);
    noise = entry.std_spectrum(:);

    signal = max(spectrum - min(spectrum));

    noise_value = mean(noise,'omitnan');

    if noise_value > 0

        SNR = signal / noise_value;

    else

        SNR = NaN;

    end

    return;

end


% --------------------------------------------------------------
% CAS 3 : aucune information
% --------------------------------------------------------------

warning( ...
    'Impossible de calculer le SNR pour %s.', ...
    getEntryName(entry));

SNR = NaN;

end


%% =================================================================
% NOM DE L'ENTREE
%% =================================================================

function name = getEntryName(entry)

if isfield(entry,'phase_name') && ...
        ~isempty(entry.phase_name)

    name = char(string(entry.phase_name));

elseif isfield(entry,'name') && ...
        ~isempty(entry.name)

    name = char(string(entry.name));

else

    name = 'phase inconnue';

end

end