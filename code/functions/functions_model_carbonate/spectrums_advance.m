function ref_roi = spectrums_advance( ...
          I_corr,wavenumber, phase_model, phase_map, ...
          roi1, roi2,fwhm_instr,active_idx, phase_colors, colors_roi,...
          sub_dir_save,exportgraphics_segm_roi,...
          n_theoretical_points, results_dir, params)


%% ================================================================
% COMPARE_SPECTRUMS_ADVANCE
%
% Fit du SPECTRE SOMME de chaque ROI.
%
% IMPORTANT :
%   Le fit n'est PAS réalisé pixel par pixel.
%   Pour chaque ROI, tous les pixels sont sommés spectralement puis
%   un seul fit lsqcurvefit est réalisé sur ce spectre somme.
%
% Le modèle de fit est le même que celui utilisé dans fit_pixel_phases :
%
%   - amplitude A >= 0
%   - nu éventuellement variable
%   - FWHM éventuellement variable
%   - fond continu
%   - convolution avec la réponse instrumentale
%   - même phase_model
%   - mêmes bornes :
%         params.nu_LB
%         params.nu_UB
%         params.FWHM_LB
%         params.FWHM_UB
%
% SORTIE :
%   ref_roi(1) : ROI 1
%   ref_roi(2) : ROI 2
%
% Chaque entrée contient notamment :
%   .sum_spectrum
%   .mean_spectrum
%   .std_spectrum
%   .A_fit
%   .nu_fit
%   .FWHM_fit
%   .background_fit
%   .R2
%   .resnorm
%   .wavenumber_theoretical
%   .theoretical_spectrum_fit
%   .peak_height_fit
%   .norm_factor


%% ================================================================
% 1. Valeurs par défaut

if nargin < 17 || isempty(n_theoretical_points)
    n_theoretical_points = 500;
end

if nargin < 18
    results_dir = '';
end


%% ================================================================
% 2. Mise en forme

if ndims(I_corr) == 4
    I_corr = squeeze(I_corr);
end

% Tri spectral
[wavenumber, sort_idx] = sort(wavenumber(:));
I_corr = I_corr(:,:,sort_idx);

[n_y, n_x, n_wn] = size(I_corr);

wavenumber_theo = linspace( ...
    min(wavenumber), ...
    max(wavenumber), ...
    n_theoretical_points);


%% ------------------------------------------------------------
% Gestion du nombre de ROI
%
% roi1 obligatoire
% roi2 optionnel : [] signifie qu'un seul ROI est utilisé

assert(numel(roi1) == 4, ...
    'roi1 doit etre [row_start row_end col_start col_end].');

checkROI(roi1, n_y, n_x, 'roi1');

has_roi2 = ~isempty(roi2);

if has_roi2
    assert(numel(roi2) == 4, ...
        'roi2 doit etre [row_start row_end col_start col_end].');
    checkROI(roi2, n_y, n_x, 'roi2');
end

n_roi = 1 + has_roi2;

%% ------------------------------------------------------------
% Vérification des phases

assert(numel(active_idx) >= n_roi, ...
    'active_idx doit contenir au moins autant de phases que de ROI.');

active_idx = active_idx(1:n_roi);

assert(size(colors_roi,1) >= n_roi, ...
    'colors_roi doit contenir au moins une couleur par ROI.');

colors_roi = colors_roi(1:n_roi,:);


%% ================================================================
% 3. Paramètres du modèle
%
% Même paramétrisation que fit_pixel_phases

nu_is_variable   = params.nu_is_variable;
FWHM_is_variable = params.FWHM_is_variable;

lineshape_type = 'gaussian';

if isfield(params,'lineshape_type') && ...
        ~isempty(params.lineshape_type)
    lineshape_type = params.lineshape_type;
end


% Vérification des dimensions des bornes
n_phases = numel(phase_model);

assert(numel(params.nu_LB) == n_phases && ...
       numel(params.nu_UB) == n_phases && ...
       numel(params.FWHM_LB) == n_phases && ...
       numel(params.FWHM_UB) == n_phases, ...
       ['params.nu_LB, params.nu_UB, params.FWHM_LB et ', ...
        'params.FWHM_UB doivent avoir un élément par phase.']);


%% ================================================================
% 4. Construction du modèle
%
% EXACTEMENT la même structure de paramètres que fit_pixel_phases

[param_map, idx_background, x0_template, lb, ub] = buildParamMap( ...
    phase_model, ...
    active_idx, ...
    nu_is_variable, ...
    FWHM_is_variable, ...
    params.nu_LB, ...
    params.nu_UB, ...
    params.FWHM_LB, ...
    params.FWHM_UB);


% Réponse instrumentale
sigma_inst = fwhm2sigma(fwhm_instr);


% Fonction modèle
model_fun = @(x,xdata) pixelForwardModel( ...
    x, ...
    xdata, ...
    param_map, ...
    idx_background, ...
    sigma_inst, ...
    lineshape_type);


% Options du fit
opts = optimoptions( ...
    'lsqcurvefit', ...
    'Display', 'off');


%% ================================================================
% 5. FIT DES DEUX ROI
%
% IMPORTANT :
%   On somme d'abord tous les pixels du ROI.
%
%   Le fit est ensuite réalisé UNE SEULE FOIS sur cette somme.


if has_roi2
    roi_list = {roi1, roi2};
else
    roi_list = {roi1};
end

for j = 1:n_roi

    roi = roi_list{j};

    row_start = roi(1);
    row_end   = roi(2);
    col_start = roi(3);
    col_end   = roi(4);

    rows = row_start:row_end;
    cols = col_start:col_end;


    %% ------------------------------------------------------------
    % Extraction des pixels du ROI

    I_roi = I_corr(rows,cols,:);

    n_pixels_roi = numel(rows) * numel(cols);


    %% ------------------------------------------------------------
    % Spectre SOMME
    %
    % Chaque pixel contribue directement à la somme.

    I_roi_2D = reshape( ...
        I_roi, ...
        n_pixels_roi, ...
        n_wn);

    sum_spectrum = sum(I_roi_2D,1,'omitnan');
    sum_spectrum = sum_spectrum(:);


    %% ------------------------------------------------------------
    % Spectre moyen
    %
    % Conservé uniquement pour affichage / comparaison.
    % Le FIT est effectué sur sum_spectrum.

    mean_spectrum = mean(I_roi_2D,1,'omitnan');
    mean_spectrum = mean_spectrum(:);


    %% ------------------------------------------------------------
    % Écart-type entre pixels

    std_spectrum = std(I_roi_2D,0,1,'omitnan');
    std_spectrum = std_spectrum(:);


    %% ------------------------------------------------------------
    % Initialisation des amplitudes
    %
    % On utilise le modèle linéaire avec les positions/FWHM
    % initiales du phase_model pour obtenir une estimation
    % raisonnable des A.
    %
    % Les amplitudes seront ensuite optimisées par lsqcurvefit.

    x0 = x0_template;

    % Modèle initial avec A = 1 pour chaque phase active
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


    % Estimation initiale simple des amplitudes par projection
    %
    % On reconstruit chaque composante avec A=1 puis on utilise
    % une résolution NNLS pour obtenir les amplitudes positives.

    G = zeros(n_wn,numel(param_map));

    for a = 1:numel(param_map)

        x_tmp = x0_A_test;

        x_tmp(param_map(a).idx_A) = 1;

        % Toutes les autres amplitudes à zéro
        for b = 1:numel(param_map)

            if b ~= a
                x_tmp(param_map(b).idx_A) = 0;
            end

        end

        x_tmp(idx_background) = 0;

        G(:,a) = model_fun(x_tmp,wavenumber);
    end


    % Fond retiré pour l'initialisation
    y_init = sum_spectrum - min(sum_spectrum);
    y_init = max(y_init,0);


    % NNLS pour initialiser A
    A0 = lsqnonneg(G,y_init);


    for a = 1:numel(param_map)

        x0(param_map(a).idx_A) = max(A0(a),0);

    end

    x0(idx_background) = min(sum_spectrum);


    %% ------------------------------------------------------------
    % Fit lsqcurvefit
    %
    % C'EST ICI que le fit est réalisé sur la SOMME du ROI

wavenumber = wavenumber(:);
sum_spectrum = sum_spectrum(:);

    [x_fit, resnorm, residual, exitflag, ~, ~, jacobian] = ...
        lsqcurvefit( ...
            model_fun, ...
            x0, ...
            wavenumber, ...
            sum_spectrum, ...
            lb, ...
            ub, ...
            opts);


    %% ------------------------------------------------------------
    % R²

    SS_tot = sum( ...
        (sum_spectrum - mean(sum_spectrum)).^2);

    R2 = 1 - resnorm / max(SS_tot,eps);


    %% ------------------------------------------------------------
    % Extraction des paramètres

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
                x_fit(param_map(a).idx_nu),1,[]);

        else

            nu_fit{k} = param_map(a).nu_fixed;

        end


        % FWHM
        if ~isempty(param_map(a).idx_FWHM)

            FWHM_fit{k} = reshape( ...
                x_fit(param_map(a).idx_FWHM),1,[]);

        else

            FWHM_fit{k} = param_map(a).FWHM_fixed;

        end

    end


    background_fit = x_fit(idx_background);


    %% ------------------------------------------------------------
    % Reconstruction du fit sur la grille expérimentale

    fit_experimental_grid = model_fun( ...
        x_fit, ...
        wavenumber);


    %% ------------------------------------------------------------
    % Reconstruction sur grille fine

    theoretical_spectrum_fit = model_fun( ...
        x_fit, ...
        wavenumber_theo);

    % mean_spectrum = sum_spectrum / n_pixels;
    theoretical_spectrum_fit = theoretical_spectrum_fit / n_pixels_roi;


    %% ------------------------------------------------------------
    % Facteur de normalisation
    %
    % Ici il s'agit du maximum du FIT de la somme.

    peak_height_fit = max(theoretical_spectrum_fit);


    %% ------------------------------------------------------------
    % Nom de la phase

    phase_idx = active_idx(j);

    if isfield(phase_model(phase_idx),'name')
        phase_name = phase_model(phase_idx).name;
    else
        phase_name = sprintf('Phase %d',phase_idx);
    end


    %% ------------------------------------------------------------
    % Stockage

    ref_roi(j).name = phase_name;

    ref_roi(j).phase_idx = phase_idx;

    ref_roi(j).roi = roi;

    ref_roi(j).fwhm_instr = fwhm_instr;

    ref_roi(j).n_pixels = n_pixels_roi;

    % Spectre utilisé pour le FIT
    ref_roi(j).sum_spectrum = sum_spectrum;

    % Spectre moyen, pour affichage éventuel
    ref_roi(j).mean_spectrum = mean_spectrum;

    ref_roi(j).std_spectrum = std_spectrum;

    % Paramètres ajustés
    ref_roi(j).A_fit = A_fit;

    ref_roi(j).nu_fit = nu_fit;

    ref_roi(j).FWHM_fit = FWHM_fit;

    ref_roi(j).background_fit = background_fit;

    % Qualité du fit
    ref_roi(j).R2 = R2;

    ref_roi(j).resnorm = resnorm;

    ref_roi(j).exitflag = exitflag;

    % Grilles
    ref_roi(j).wavenumber = wavenumber;

    ref_roi(j).wavenumber_theoretical = ...
        wavenumber_theo;

    % Fits
    ref_roi(j).fit_experimental_grid = ...
        fit_experimental_grid;

    ref_roi(j).theoretical_spectrum_fit = ...
        theoretical_spectrum_fit;

    % Normalisation
    ref_roi(j).peak_height_fit = ...
        peak_height_fit;

    ref_roi(j).norm_factor = ...
        peak_height_fit;

end


%% ================================================================
% 6. Normalisation commune
%
% Le maximum théorique le plus élevé sert de référence.

norm_factor = max([ref_roi.peak_height_fit]);

for j = 1:n_roi
    ref_roi(j).norm_factor = norm_factor;
end


%% ================================================================
% 7. Affichage des deux ROI
%
% Le spectre expérimental affiché est le spectre MOYEN.
%
% Le FIT affiché correspond cependant au FIT réalisé sur la SOMME.
%
% Si tu veux comparer quantitativement la forme expérimentale
% directement au fit, il est préférable d'afficher aussi la somme
% normalisée. Ici je conserve ton affichage original.

figure( ...
    'Color','white', ...
    'Position',[100 100 1000 700]);

hold on;


for j = 1:n_roi

    %% ------------------------------------------------------------
    % Bande ± 1 sigma
    %
    % Pour rester cohérent avec le spectre moyen affiché.

    upper = ...
        (ref_roi(j).mean_spectrum + ...
         ref_roi(j).std_spectrum) / norm_factor;

    lower = ...
        (ref_roi(j).mean_spectrum - ...
         ref_roi(j).std_spectrum) / norm_factor;

    upper = upper(:).';
    lower = lower(:).';


    x_fill = [wavenumber(:); flipud(wavenumber(:))];
    
    y_fill = [upper(:); flipud(lower(:))];
    
    fill( ...
        x_fill, ...
        y_fill, ...
        colors_roi(j,:), ...
        'FaceAlpha', 0.15, ...
        'EdgeColor', 'none', ...
        'HandleVisibility', 'off');


    %% ------------------------------------------------------------
    % Spectre expérimental moyen

    plot( ...
        wavenumber, ...
        ref_roi(j).mean_spectrum / norm_factor, ...
        'o', ...
        'Color',colors_roi(j,:), ...
        'MarkerFaceColor',colors_roi(j,:), ...
        'MarkerSize',4, ...
        'LineWidth',2, ...
        'DisplayName',sprintf( ...
            '%s : moyenne ROI +/- std', ...
            ref_roi(j).name));

    


    %% ------------------------------------------------------------
    % Fit théorique
    %
    % Le fit provient de la SOMME des pixels.

    plot( ...
        ref_roi(j).wavenumber_theoretical, ...
        ref_roi(j).theoretical_spectrum_fit / norm_factor, ...
        '--', ...
        'Color',colors_roi(j,:), ...
        'LineWidth',1.5, ...
        'DisplayName',sprintf( ...
            '%s : fit somme (R^2=%.3f)', ...
            ref_roi(j).name, ...
            ref_roi(j).R2));

end


xlabel( ...
    'Wavenumber (cm^{-1})', ...
    'FontSize',12);

ylabel( ...
    'Intensite normalisee', ...
    'FontSize',12);

title( ...
    'Comparaison ROI CC vs ACC', ...
    'FontSize',13);

legend( ...
    'Location','best');

grid on;
box on;

set(gca, ...
    'FontSize',11);


%% ================================================================
% 8. Affichage : ROI sur la carte de segmentation

plotSegmentation_ROI( ...
    phase_map, ...
    phase_model, ...
    active_idx, ...
    phase_colors, ...
    colors_roi, ...
    ref_roi, ...
    sub_dir_save, ...
    exportgraphics_segm_roi);

%% ================================================================
% 9. Display stat

fprintf('\nCompare_spectrums_advance STATS\n');

    for i = 1:numel(ref_roi)

        rs = ref_roi(i);

        fprintf('\n------------------------------------------------------------\n');
        fprintf('Phase %d : %s\n', rs.phase_idx, rs.name);
        fprintf('------------------------------------------------------------\n');


        %% Amplitudes de toutes les phases

    
    for k = 1:numel(active_idx)
    
        j = active_idx(k);
    
        fprintf('  Phase %s : A_fit = %.5g\n', ...
            phase_model(j).name, ...
            ref_roi(i).A_fit(j))
    end

    %% Positions des raies
    
    if ~isempty(rs.nu_fit)
    
        for j = 1:numel(rs.nu_fit)
    
            if ~isempty(rs.nu_fit{j})
    
                nu_j = rs.nu_fit{j};
    
                for p = 1:numel(nu_j)
    
                    fprintf('  Phase %s : Raie %d : nu = %.4f cm^-1\n', ...
                        phase_model(j).name, p, nu_j(p));
    
                end
    
            end
    
        end
    
    end


        %% FWHM
    if ~isempty(rs.FWHM_fit)
    
        for j = 1:numel(rs.FWHM_fit)
    
            if ~isempty(rs.FWHM_fit{j})
    
                FWHM_j = rs.FWHM_fit{j};
    
                for p = 1:numel(FWHM_j)
    
                    fprintf('  Phase %s : FWHM %d : FWHM = %.4f cm^-1\n', ...
                        phase_model(j).name, p, FWHM_j(p));
    
                end
    
            end
    
        end
    
    end

    end

%% ================================================================
% 10. Sauvegarde

if ~isempty(results_dir)

    save(results_dir,'ref_roi');

    fprintf( ...
        'ref_roi sauvegarde dans %s\n', ...
        results_dir);

end


end


