function I_model = pixelForwardModel(x, wavenumber, param_map, idx_background, sigma_inst, lineshape_type)
% Modele direct : somme des phases actives (chaque raie convoluee
% analytiquement par la reponse instrumentale, cf. sigma_inst) + fond
% continu. Utilise nu/FWHM depuis x si libres, sinon depuis les valeurs
% fixees stockees dans param_map.

    I_model = x(idx_background) * ones(size(wavenumber));

    for a = 1:numel(param_map)
        pm = param_map(a);

        A = x(pm.idx_A);

        if ~isempty(pm.idx_nu)
            nu = reshape(x(pm.idx_nu), 1, []);
        else
            nu = pm.nu_fixed;
        end

        if ~isempty(pm.idx_FWHM)
            FWHM = reshape(x(pm.idx_FWHM), 1, []);
        else
            FWHM = pm.FWHM_fixed;
        end

        ratio = pm.ratio;
        ratio = ratio/sum(ratio);

        G = zeros(size(wavenumber));
        for p = 1:numel(nu)
            sigma_phase = fwhm2sigma(FWHM(p));
            sigma_eff_p = sqrt(sigma_phase^2 + sigma_inst^2);
            G = G + ratio(p) * lineShapeArea(wavenumber, nu(p), sigma_eff_p, lineshape_type);
        end

        I_model = I_model + A*G;
    end
end