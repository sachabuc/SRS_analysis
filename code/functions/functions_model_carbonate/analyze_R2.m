function stats = analyze_R2(pixel_fit, phase_model, display_figures)
% Analyse statistique simple de R2 et des paramètres les plus pertinents.
%
% INPUT
%   pixel_fit       : structure [Ny x Nx]
%   phase_model     : structure des phases
%   display_figures : true / false
%
% OUTPUT
%   stats :
%       .R2          statistiques de R2
%       .A_total     statistiques amplitude totale
%       .corr_A      corrélation R2-A_total
%       .phase(k)    statistiques FWHM et corrélation avec R2

if nargin < 3
    display_figures = true;
end

%% ========================================================================
% Récupération des pixels
% ========================================================================

pf = pixel_fit(:);
Npix = numel(pf);

%% ========================================================================
% 1. STATISTIQUES DE BASE DE R2
% ========================================================================

R2 = [pf.R2]';

valid = isfinite(R2);
R2 = R2(valid);

stats.R2.N = numel(R2);
stats.R2.mean = mean(R2);
stats.R2.median = median(R2);
stats.R2.std = std(R2);
stats.R2.var = var(R2);
stats.R2.min = min(R2);
stats.R2.max = max(R2);
stats.R2.Q1 = prctile(R2,25);
stats.R2.Q3 = prctile(R2,75);

%% ========================================================================
% 2. AMPLITUDE TOTALE
% ========================================================================

A_total = nan(Npix,1);

for p = 1:Npix

    if ~isempty(pixel_fit(p).A)

        A = pixel_fit(p).A;

        A = A(isfinite(A));

        if ~isempty(A)
            A_total(p) = sum(A);
        end

    end

end

valid_A = isfinite(A_total) & isfinite([pf.R2]');

R2_A = [pf.R2]';
R2_A = R2_A(valid_A);
A_total_valid = A_total(valid_A);

stats.A_total.N = numel(A_total_valid);
stats.A_total.mean = mean(A_total_valid);
stats.A_total.median = median(A_total_valid);
stats.A_total.std = std(A_total_valid);
stats.A_total.var = var(A_total_valid);

% Corrélations R2 / amplitude totale
stats.corr_R2_A_total.Pearson = ...
    corr(R2_A,A_total_valid,'Type','Pearson');

stats.corr_R2_A_total.Spearman = ...
    corr(R2_A,A_total_valid,'Type','Spearman');

%% ========================================================================
% 3. FWHM ET CORRELATION AVEC R2
% ========================================================================

n_phases = numel(phase_model);

stats.phase = struct([]);

for k = 1:n_phases

    FWHM = nan(Npix,1);

    for p = 1:Npix

        if ~isempty(pixel_fit(p).FWHM) && ...
                numel(pixel_fit(p).FWHM) >= k

            f = pixel_fit(p).FWHM{k};

            if ~isempty(f)

                % Si plusieurs raies :
                % on prend la moyenne
                FWHM(p) = mean(f(:));

            end

        end

    end

    R2_all = [pf.R2]';

    valid_FWHM = isfinite(FWHM) & isfinite(R2_all);

    F = FWHM(valid_FWHM);
    R = R2_all(valid_FWHM);

    stats.phase(k).name = phase_model(k).name;

    % Statistiques FWHM
    stats.phase(k).FWHM.N = numel(F);

    if ~isempty(F)

        stats.phase(k).FWHM.mean = mean(F);
        stats.phase(k).FWHM.median = median(F);
        stats.phase(k).FWHM.std = std(F);
        stats.phase(k).FWHM.var = var(F);

        % Corrélation R2 / FWHM
        stats.phase(k).corr_R2_FWHM.Pearson = ...
            corr(R,F,'Type','Pearson');

        stats.phase(k).corr_R2_FWHM.Spearman = ...
            corr(R,F,'Type','Spearman');

    else

        stats.phase(k).FWHM.mean = NaN;
        stats.phase(k).FWHM.median = NaN;
        stats.phase(k).FWHM.std = NaN;
        stats.phase(k).FWHM.var = NaN;

        stats.phase(k).corr_R2_FWHM.Pearson = NaN;
        stats.phase(k).corr_R2_FWHM.Spearman = NaN;

    end

end

%% ========================================================================
% 4. FIGURES
% ========================================================================

if display_figures

    % Distribution R2
    figure;
    histogram(R2,50);
    xlabel('R^2');
    ylabel('Nombre de pixels');
    title('Distribution de R^2');
    grid on;

    % R2 vs amplitude totale
    figure;
    scatter(A_total_valid,R2_A,10,'filled');
    xlabel('Amplitude totale');
    ylabel('R^2');
    title('R^2 vs amplitude totale');
    grid on;

    % R2 vs FWHM
    for k = 1:n_phases

        FWHM = nan(Npix,1);

        for p = 1:Npix
            if ~isempty(pixel_fit(p).FWHM) && ...
                    numel(pixel_fit(p).FWHM) >= k

                f = pixel_fit(p).FWHM{k};

                if ~isempty(f)
                    FWHM(p) = mean(f(:));
                end
            end
        end

        R2_all = [pf.R2]';

        valid = isfinite(FWHM) & isfinite(R2_all);

        if any(valid)

            figure;
            scatter(FWHM(valid),R2_all(valid),10,'filled');
            xlabel(['FWHM - ' char(phase_model(k).name)]);
            ylabel('R^2');
            title(['R^2 vs FWHM - ' char(phase_model(k).name)]);
            grid on;

        end
    end

end

end