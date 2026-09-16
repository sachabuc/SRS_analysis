function ci = computeConfidenceIntervals(x_fit, residual, jacobian, alpha)
% Intervalle de confiance (1-alpha) sur chaque parametre de x_fit, par
% linearisation locale du modele autour de la solution (approche
% standard en moindres carres non-lineaires). Utilise nlparci
% (Statistics and Machine Learning Toolbox) si disponible, sinon un
% repli manuel equivalent avec un quantile normal fixe (1.96 pour
% alpha=0.05) plutot que le quantile de Student exact -- un peu moins
% precis si le nombre de degres de liberte est tres petit, mais ne
% necessite aucun toolbox.
    try
        ci = nlparci(x_fit, residual, 'jacobian', full(jacobian), 'alpha', alpha);
    catch
        n = numel(residual);
        p = numel(x_fit);
        dof = max(n-p, 1);
        mse = sum(residual.^2)/dof;
        J = full(jacobian);
        C = pinv(J.'*J) * mse;
        se = sqrt(diag(C));
        z = 1.96;
        ci = [x_fit(:) - z*se, x_fit(:) + z*se];
    end
end