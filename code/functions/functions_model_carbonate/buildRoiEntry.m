function entry = buildRoiEntry( ...
    I_corr, wavenumber, wavenumber_theo, phase_model, ...
    roi, k, roi_idx, fwhm_instr, delta_nu, fwhm_bounds, ...
    colors_roi,nu_variable, FWHM_variable)

    % BUILDROIENTRY
    %
    % Ajuste le spectre moyen d'une ROI avec un modèle gaussien convolué
    % par la réponse instrumentale.
    %
    % nu_is_variable   : [roi1_flag roi2_flag]
    %                     true  -> nu libre dans le fit
    %                     false -> nu fixé à phase_model(k).nu(1)
    %
    % FWHM_is_variable : [roi1_flag roi2_flag]
    %                     true  -> FWHM libre dans le fit
    %                     false -> FWHM fixé à phase_model(k).FWHM(1)
    %
    % Exemple :
    %
    % nu_is_variable   = [false true];
    % FWHM_is_variable = [false true];
    %
    % => ROI 1 : nu et FWHM fixes
    %    ROI 2 : nu et FWHM libres


    %% --- Extraction du spectre moyen de la ROI ---

    sub_cube = I_corr( ...
        roi(1):roi(2), ...
        roi(3):roi(4), :);

    [ry, rx, rw] = size(sub_cube);

    flat = reshape( ...
        permute(sub_cube, [3 1 2]), ...
        rw, ry*rx).';

    mean_spec = mean(flat, 1);
    std_spec  = std(flat, 0, 1);


    %% --- Vérification de la phase ---

    assert(numel(phase_model(k).nu) == 1, ...
        ['compare_roi_to_theoretical_model suppose une phase a une seule raie ' ...
         '(phase_model(%d) en a %d) -- non gere ici.'], ...
         k, numel(phase_model(k).nu));


    %% --- Paramètres initiaux ---

    nu0   = phase_model(k).nu(1);
    FWHM0 = phase_model(k).FWHM(1);

    sigma_inst = fwhm2sigma(fwhm_instr);


    %% --- Déterminer quels paramètres sont variables ---

%     nu_variable   = nu_is_variable(roi_idx);
%     FWHM_variable = FWHM_is_variable(roi_idx);


    %% --- Construction du modèle ---

    % x(1) = amplitude
    % x(2) = nu
    % x(3) = FWHM
    % x(4) = background

    model_fun = @(x, xdata) ...
        x(1) * gaussianArea( ...
            xdata, ...
            x(2), ...
            sqrt(fwhm2sigma(x(3))^2 + sigma_inst^2)) ...
        + x(4);


    %% --- Paramètres initiaux et bornes ---

    x0 = [max(mean_spec), nu0, FWHM0, 0];

    % Par défaut : tous libres
    lb = [0, nu0-delta_nu, fwhm_bounds(1)*FWHM0, -Inf];
    ub = [Inf, nu0+delta_nu, fwhm_bounds(2)*FWHM0, Inf];


    %% --- Fixer nu si demandé ---

    if ~nu_variable

        x0(2) = nu0;
        lb(2) = nu0;
        ub(2) = nu0;

    end


    %% --- Fixer FWHM si demandé ---

    if ~FWHM_variable

        x0(3) = FWHM0;
        lb(3) = FWHM0;
        ub(3) = FWHM0;

    end


    %% --- Fit ---

    opts = optimoptions( ...
        'lsqcurvefit', ...
        'Display', 'off');

    [x_fit, resnorm] = lsqcurvefit( ...
        model_fun, ...
        x0, ...
        wavenumber, ...
        mean_spec, ...
        lb, ...
        ub, ...
        opts);


    %% --- Paramètres ajustés ---

    A_fit          = x_fit(1);
    nu_fit         = x_fit(2);
    FWHM_fit       = x_fit(3);
    background_fit = x_fit(4);


    %% --- R2 ---

    SS_tot = sum((mean_spec - mean(mean_spec)).^2);

    R2 = 1 - resnorm / max(SS_tot, eps);


    %% --- Spectre théorique ajusté ---

    sigma_eff_fit = sqrt( ...
        fwhm2sigma(FWHM_fit)^2 + sigma_inst^2);

    theo_spec_fit = ...
        A_fit * gaussianArea( ...
            wavenumber_theo, ...
            nu_fit, ...
            sigma_eff_fit) ...
        + background_fit;


    %% --- Résultats ---

    entry.name                 = phase_model(k).name;
    entry.phase_idx            = k;
    entry.roi                  = roi;
    entry.roi_idx              = roi_idx;
    entry.colors_roi           = colors_roi;

    entry.fwhm_instr           = fwhm_instr;
    entry.wavenumber           = wavenumber;

    entry.mean_spectrum        = mean_spec;
    entry.std_spectrum         = std_spec;

    entry.A_fit                = A_fit;
    entry.nu_fit               = nu_fit;
    entry.FWHM_fit             = FWHM_fit;
    entry.background_fit       = background_fit;

    entry.nu_is_variable       = nu_variable;
    entry.FWHM_is_variable     = FWHM_variable;

    entry.R2                   = R2;
    entry.resnorm              = resnorm;

    entry.wavenumber_theoretical   = wavenumber_theo;
    entry.theoretical_spectrum_fit = theo_spec_fit;

    entry.peak_height_fit      = max(theo_spec_fit);

    entry.norm_factor = max([entry.peak_height_fit]);

end