function [param_map, idx_background, x0_template, lb, ub] = buildParamMap( ...
    phase_model, active_idx, nu_is_variable, FWHM_is_variable, ...
    nu_LB, nu_UB, FWHM_LB, FWHM_UB)
% Construit, une seule fois, la correspondance entre les phases actives
% et les indices du vecteur de parametres x utilise par lsqcurvefit,
% ainsi que les bornes associees. Chaque phase occupe : 1 amplitude,
% puis ses nu si nu_is_variable(k), puis ses FWHM si FWHM_is_variable(k).
% Un terme de fond global est ajoute a la fin.

    n_active = numel(active_idx);
    param_map = struct('k',{},'idx_A',{},'idx_nu',{},'idx_FWHM',{}, ...
                        'nu_fixed',{},'FWHM_fixed',{},'ratio',{});

    idx = 0;
    x0_template = [];
    lb = [];
    ub = [];

    for a = 1:n_active
        k = active_idx(a);
        nu0   = phase_model(k).nu;
        FWHM0 = phase_model(k).FWHM;

        % --- Amplitude : toujours libre, toujours >= 0 -----------------
        idx = idx + 1;
        param_map(a).k     = k;
        param_map(a).idx_A = idx;
        x0_template(idx,1) = 0;
        lb(idx,1) = 0;
        ub(idx,1) = Inf;

        % --- Position (nu) : meme borne [nu_LB(k) nu_UB(k)] pour toutes
        %     les raies de la phase --------------------------------------
        if nu_is_variable(k)
            n = numel(nu0);
            param_map(a).idx_nu = idx + (1:n);
            x0_template(param_map(a).idx_nu,1) = nu0(:);
            lb(param_map(a).idx_nu,1) = nu_LB(k) * ones(n,1);
            ub(param_map(a).idx_nu,1) = nu_UB(k) * ones(n,1);
            idx = idx + n;
        else
            param_map(a).idx_nu = [];
        end
        param_map(a).nu_fixed = nu0;

        % --- Largeur (FWHM) : meme borne [FWHM_LB(k) FWHM_UB(k)] pour
        %     toutes les raies de la phase ----------------------------
        if FWHM_is_variable(k)
            n = numel(FWHM0);
            param_map(a).idx_FWHM = idx + (1:n);
            x0_template(param_map(a).idx_FWHM,1) = FWHM0(:);
            lb(param_map(a).idx_FWHM,1) = FWHM_LB(k) * ones(n,1);
            ub(param_map(a).idx_FWHM,1) = FWHM_UB(k) * ones(n,1);
            idx = idx + n;
        else
            param_map(a).idx_FWHM = [];
        end
        param_map(a).FWHM_fixed = FWHM0;

        param_map(a).ratio = phase_model(k).ratio;
    end

    % --- Fond continu global : toujours libre, non borne -----------------
    idx = idx + 1;
    idx_background = idx;
    x0_template(idx_background,1) = 0;
    lb(idx_background,1) = -Inf;
    ub(idx_background,1) = Inf;

end