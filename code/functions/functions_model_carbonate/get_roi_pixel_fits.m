
function roi_fits = get_roi_pixel_fits( ...
    pixel_fit, phase_model, wavenumber, tau_fwhm, ...
    roi1, roi2, roi_phase_idx, I_corr, display_figures)

%GET_ROI_PIXEL_FITS
% Reconstructs the fitted spectrum of every pixel contained in roi1
% and roi2, using the parameters already stored in pixel_fit.
%
% INPUTS
%   pixel_fit       : [n_y x n_x] structure returned by fit_pixel_phases
%
%   phase_model     : structure defining the phases
%
%   wavenumber      : spectral axis [cm^-1]
%
%   tau_fwhm        : instrumental FWHM used during the fit
%
%   roi1            : [row_start row_end col_start col_end]
%
%   roi2            : [row_start row_end col_start col_end]
%                     [] if no second ROI is used
%
%   roi_phase_idx   : phase index associated with each ROI
%                     [idx_roi1 idx_roi2]
%
%                     If roi2 is empty, only roi_phase_idx(1)
%                     is required.
%
%   I_corr          : experimental hyperspectral cube
%                     [n_y x n_x x n_wn]
%
%   display_figures : true/false
%
%
% OUTPUT
%   roi_fits(1) : results for ROI1
%
%   roi_fits(2) : results for ROI2, if roi2 is not empty
%
%   For each ROI:
%       .roi
%       .phase_idx
%       .phase_name
%       .row
%       .col
%       .pixel_fit
%       .wavenumber
%       .experimental_spectra
%       .total_fit
%       .phase_fit
%
%       .mean_experimental
%       .mean_fit
%
%       .A
%       .nu
%       .FWHM
%       .background
%       .R2
%       .resnorm
%
%
% IMPORTANT
%   No fitting is performed here.
%   The function only reconstructs the model from pixel_fit.


%% ================================================================
% 0. Valeurs par défaut
%% ================================================================

if nargin < 10 || isempty(display_figures)
    display_figures = true;
end

if nargin < 7 || isempty(roi_phase_idx)
    error('roi_phase_idx doit être fourni.');
end

if nargin < 8 || isempty(I_corr)
    error('I_corr doit être fourni pour comparer les fits aux données expérimentales.');
end

% ROI2 absente
has_roi2 = ~isempty(roi2);

if has_roi2 && numel(roi_phase_idx) < 2
    error(['roi_phase_idx doit contenir deux indices lorsque roi2 ' ...
           'est fournie : [idx_roi1 idx_roi2].']);
end


%% ================================================================
% 1. Mise en forme
%% ================================================================

wavenumber = wavenumber(:);
n_wn = numel(wavenumber);

if ndims(I_corr) == 4
    I_corr = squeeze(I_corr);
end

[n_y,n_x,n_wn_corr] = size(I_corr);

if n_wn_corr ~= n_wn
    error(['Le nombre de points spectraux de I_corr (%d) ne correspond ' ...
           'pas à wavenumber (%d).'], n_wn_corr,n_wn);
end

if ~isequal(size(pixel_fit),[n_y n_x])
    error('pixel_fit et I_corr doivent avoir les mêmes dimensions spatiales.');
end

check_roi(roi1,n_y,n_x,'roi1');

if has_roi2
    check_roi(roi2,n_y,n_x,'roi2');
end

sigma_inst = fwhm2sigma(tau_fwhm);

n_phases = numel(phase_model);

if roi_phase_idx(1) < 1 || roi_phase_idx(1) > n_phases
    error('roi_phase_idx(1) est hors limites.');
end

if has_roi2 && ...
        (roi_phase_idx(2) < 1 || roi_phase_idx(2) > n_phases)
    error('roi_phase_idx(2) est hors limites.');
end


%% ================================================================
% 2. Préparation des ROI
%% ================================================================

roi_list = {roi1};
phase_idx_list = roi_phase_idx(1);

if has_roi2
    roi_list{2} = roi2;
    phase_idx_list(2) = roi_phase_idx(2);
end

n_roi = numel(roi_list);

roi_names = {'ROI 1','ROI 2'};

roi_fits = struct([]);


%% ================================================================
% 3. Reconstruction des fits pixel par pixel
%% ================================================================

for r = 1:n_roi

    roi = roi_list{r};
    phase_idx = phase_idx_list(r);

    row_start = roi(1);
    row_end   = roi(2);
    col_start = roi(3);
    col_end   = roi(4);

    rows = row_start:row_end;
    cols = col_start:col_end;

    [CC,RR] = meshgrid(cols,rows);

    rows_all = RR(:);
    cols_all = CC(:);

    n_pixels = numel(rows_all);

    %% ------------------------------------------------------------
    % Stockage
    %% ------------------------------------------------------------

    % Grille spectrale fine pour reconstruire le modèle
    oversampling = 10;
    
    wavenumber_fine = linspace( ...
        min(wavenumber), ...
        max(wavenumber), ...
        n_wn * oversampling).';
    
    n_wn_fine = numel(wavenumber_fine);
    
    % Données expérimentales : restent sur la grille originale
    experimental_spectra = zeros(n_wn,n_pixels);
    
    % Fits : calculés sur la grille fine
    total_fit = zeros(n_wn_fine,n_pixels);
    
    phase_fit = cell(1,n_phases);
    
    for k = 1:n_phases
        phase_fit{k} = zeros(n_wn_fine,n_pixels);
    end

    pixel_fit_roi = repmat( ...
        pixel_fit(rows_all(1),cols_all(1)), ...
        n_pixels,1);

    %% ------------------------------------------------------------
    % Paramètres par pixel
    %% ------------------------------------------------------------

    A_all          = nan(n_pixels,n_phases);
    background_all = nan(n_pixels,1);
    R2_all         = nan(n_pixels,1);
    resnorm_all    = nan(n_pixels,1);

    nu_all   = cell(n_pixels,n_phases);
    FWHM_all = cell(n_pixels,n_phases);

    %% ------------------------------------------------------------
    % Boucle pixels
    %% ------------------------------------------------------------

    for p = 1:n_pixels

        iy = rows_all(p);
        ix = cols_all(p);

        pf = pixel_fit(iy,ix);

        pixel_fit_roi(p) = pf;

        % ---------------------------------------------------------
        % Données expérimentales
        % ---------------------------------------------------------

        I_pixel = squeeze(I_corr(iy,ix,:));
        I_pixel = I_pixel(:);

        experimental_spectra(:,p) = I_pixel;

        % ---------------------------------------------------------
        % Fond
        % ---------------------------------------------------------

        model_fine = pf.background * ones(n_wn_fine,1);

        background_all(p) = pf.background;
        R2_all(p)         = pf.R2;
        resnorm_all(p)    = pf.resnorm;

        % ---------------------------------------------------------
        % Paramètres des phases
        % ---------------------------------------------------------

        A_all(p,:) = pf.A(:).';

        for k = 1:n_phases

            if ~phase_model(k).use
                continue;
            end

            A = pf.A(k);

            if isempty(A) || ~isfinite(A) || A == 0
                continue;
            end

            nu = pf.nu{k};
            FWHM = pf.FWHM{k};

            nu_all{p,k}   = nu;
            FWHM_all{p,k} = FWHM;

            if isempty(nu) || isempty(FWHM)
                continue;
            end

            nu   = nu(:).';
            FWHM = FWHM(:).';

            % Ratio des différentes raies de la phase
            if isfield(phase_model(k),'ratio') && ...
                    ~isempty(phase_model(k).ratio)

                ratio = phase_model(k).ratio(:).';

                ratio = ratio / sum(ratio);

            else

                ratio = ones(size(nu));
                ratio = ratio / sum(ratio);

            end

            if numel(ratio) ~= numel(nu)
                error(['Le nombre de ratios ne correspond pas au nombre ' ...
                       'de raies pour la phase %s.'], ...
                       phase_model(k).name);
            end

            % -----------------------------------------------------
            % Reconstruction de la phase
            % -----------------------------------------------------

            phase_curve = zeros(n_wn_fine,1);

            for j = 1:numel(nu)

                sigma_phase = fwhm2sigma(FWHM(j));

                sigma_eff = sqrt( ...
                    sigma_phase^2 + sigma_inst^2);

                G = gaussian_area( ...
                    wavenumber_fine,nu(j),sigma_eff);

                phase_curve = ...
                    phase_curve + ratio(j)*G;

            end

            phase_curve = A * phase_curve;

            phase_fit{k}(:,p) = phase_curve;

            model_fine = model_fine  + phase_curve;

            total_fit(:,p) = model_fine;

        end

        total_fit_fine(:,p) = model_fine;

    end


    %% ============================================================
    % 4. Paramètres de la phase de la ROI
    %% ============================================================

    A_phase = A_all(:,phase_idx);

    nu_phase   = cell(n_pixels,1);
    FWHM_phase = cell(n_pixels,1);

    for p = 1:n_pixels
        nu_phase{p}   = nu_all{p,phase_idx};
        FWHM_phase{p} = FWHM_all{p,phase_idx};
    end


    %% ============================================================
    % 5. Moyennes expérimentale et fit
    %% ============================================================

    mean_experimental = mean(experimental_spectra,2,'omitnan');

    mean_fit = mean(total_fit,2,'omitnan');


    %% ============================================================
    % 6. Stockage
    %% ============================================================

    roi_fits(r).name = roi_names{r};

    roi_fits(r).roi = roi;

    roi_fits(r).phase_idx = phase_idx;

    roi_fits(r).phase_name = phase_model(phase_idx).name;

    roi_fits(r).row = rows_all;

    roi_fits(r).col = cols_all;

    roi_fits(r).n_pixels = n_pixels;

    roi_fits(r).pixel_fit = pixel_fit_roi;

    roi_fits(r).wavenumber = wavenumber;

    roi_fits(r).wavenumber_fine = wavenumber_fine;

    roi_fits(r).experimental_spectra = experimental_spectra;

    roi_fits(r).total_fit = total_fit_fine;

    roi_fits(r).phase_fit = phase_fit;

    roi_fits(r).mean_experimental = mean(experimental_spectra,2,'omitnan');

    roi_fits(r).mean_fit_fine = mean(total_fit_fine,2,'omitnan');

    roi_fits(r).mean_fit = mean_fit;

    roi_fits(r).A = A_phase;

    roi_fits(r).nu = nu_phase;

    roi_fits(r).FWHM = FWHM_phase;

    roi_fits(r).background = background_all;

    roi_fits(r).R2 = R2_all;

    roi_fits(r).resnorm = resnorm_all;

end


%% ================================================================
% 7. Figure : tous les fits pixel par pixel
%% ================================================================

if display_figures

    for r = 1:n_roi

        figure('Color','w', ...
            'Name',['Pixel fits - ' roi_names{r}], ...
            'Position',[100 100 1100 750]);

        hold on;

        n_pixels = roi_fits(r).n_pixels;

        for p = 1:n_pixels

            plot(wavenumber, ...
                roi_fits(r).experimental_spectra(:,p), ...
                'Color',[0.75 0.75 0.75], ...
                'LineWidth',0.5);

            plot(wavenumber_fine, ...
                roi_fits(r).total_fit(:,p), ...
                'LineWidth',0.8);

        end

        xlabel('Wavenumber (cm^{-1})');
        ylabel('Intensity (a.u.)');

        title(sprintf('%s — %s — %d pixels', ...
            roi_names{r}, ...
            roi_fits(r).phase_name, ...
            n_pixels));

        set(gca, ...
            'FontName','Arial', ...
            'FontSize',13, ...
            'LineWidth',1, ...
            'TickDir','out');

        grid on;
        box off;

        hold off;

    end

end


%% ================================================================
% 8. Figure comparative ROI1 / ROI2
%% ================================================================

if display_figures && has_roi2

    figure('Color','w', ...
        'Name','Comparison ROI1 ROI2', ...
        'Position',[100 100 1250 850]);


    %% ------------------------------------------------------------
    % Panel 1 : spectres expérimentaux + somme des fits
    %% ------------------------------------------------------------

    subplot(2,2,1);

    hold on;

    % ROI1
    plot( wavenumber, ...
        roi_fits(1).mean_experimental, ...
        'o', ...
        'MarkerSize',4, ...
        'LineWidth',0.8, ...
        'DisplayName', ...
        sprintf('ROI 1 — %s data', ...
        roi_fits(1).phase_name));

    plot( roi_fits(1).wavenumber_fine, ...
        roi_fits(1).mean_fit, ...
        'LineWidth',2, ...
        'DisplayName', ...
        sprintf('ROI 1 — fit'));

    % ROI2
    plot( ...
        wavenumber, ...
        roi_fits(2).mean_experimental, ...
        'o', ...
        'MarkerSize',4, ...
        'LineWidth',0.8, ...
        'DisplayName', ...
        sprintf('ROI 2 — %s data', ...
        roi_fits(2).phase_name));

    plot( ...
        roi_fits(2).wavenumber_fine, ...
        roi_fits(2).mean_fit, ...
        'LineWidth',2, ...
        'DisplayName', ...
        sprintf('ROI 2 — fit'));

    xlabel('Wavenumber (cm^{-1})');
    ylabel('Intensity (a.u.)');

    title('Experimental spectra and reconstructed fits');

    legend('Location','best');

    grid on;
    box off;


    %% ------------------------------------------------------------
    % Panel 2 : A
    %% ------------------------------------------------------------

    subplot(2,2,2);

    A1 = roi_fits(1).A;
    A2 = roi_fits(2).A;

    labels = cellstr([ ...
    string(roi_fits(1).phase_name), ...
    string(roi_fits(2).phase_name)]);

boxplot([A1; A2], ...
    [ones(size(A1)); 2*ones(size(A2))], ...
    'Labels', labels);

    ylabel('Fitted amplitude A');

    title('Amplitude');

    grid on;
    box off;


    %% ------------------------------------------------------------
    % Panel 3 : nu
    %% ------------------------------------------------------------

    subplot(2,2,3);

    nu1 = nan(size(roi_fits(1).nu));
    nu2 = nan(size(roi_fits(2).nu));

    for p = 1:numel(roi_fits(1).nu)

        if ~isempty(roi_fits(1).nu{p})
            nu1(p) = roi_fits(1).nu{p}(1);
        end

    end

    for p = 1:numel(roi_fits(2).nu)

        if ~isempty(roi_fits(2).nu{p})
            nu2(p) = roi_fits(2).nu{p}(1);
        end

    end

labels = cellstr([ ...
    string(roi_fits(1).phase_name), ...
    string(roi_fits(2).phase_name)]);

boxplot([nu1(:); nu2(:)], ...
    [ones(numel(nu1),1); 2*ones(numel(nu2),1)], ...
    'Labels', labels);

    ylabel('\nu (cm^{-1})');

    title('Fitted peak position');

    grid on;
    box off;


    %% ------------------------------------------------------------
    % Panel 4 : FWHM
    %% ------------------------------------------------------------

    subplot(2,2,4);

    FWHM1 = nan(size(roi_fits(1).FWHM));
    FWHM2 = nan(size(roi_fits(2).FWHM));

    for p = 1:numel(roi_fits(1).FWHM)

        if ~isempty(roi_fits(1).FWHM{p})
            FWHM1(p) = roi_fits(1).FWHM{p}(1);
        end

    end

    for p = 1:numel(roi_fits(2).FWHM)

        if ~isempty(roi_fits(2).FWHM{p})
            FWHM2(p) = roi_fits(2).FWHM{p}(1);
        end

    end

labels = cellstr([ ...
    string(roi_fits(1).phase_name), ...
    string(roi_fits(2).phase_name)]);

boxplot([FWHM1(:); FWHM2(:)], ...
    [ones(numel(FWHM1),1); 2*ones(numel(FWHM2),1)], ...
    'Labels', labels);

    ylabel('FWHM (cm^{-1})');

    title('Fitted FWHM');

    grid on;
    box off;


    %% ------------------------------------------------------------
    % Style général
    %% ------------------------------------------------------------

    ax = findall(gcf,'Type','axes');

    set(ax, ...
        'FontName','Arial', ...
        'FontSize',12, ...
        'LineWidth',1, ...
        'TickDir','out');

end

end


%% =================================================================
% FONCTIONS LOCALES
%% =================================================================

function sigma = fwhm2sigma_local(FWHM)

sigma = FWHM ./ (2*sqrt(2*log(2)));

end


function G = gaussian_area(x,mu,sigma)

% Gaussian normalisée à aire = 1

G = exp(-(x-mu).^2 ./ (2*sigma^2)) ./ ...
    (sigma*sqrt(2*pi));

end


function check_roi(roi,n_y,n_x,name)

if numel(roi) ~= 4
    error('%s doit être [row_start row_end col_start col_end].',name);
end

if roi(1) < 1 || roi(2) > n_y || ...
   roi(3) < 1 || roi(4) > n_x || ...
   roi(1) > roi(2) || roi(3) > roi(4)

    error('%s est hors des dimensions de pixel_fit.',name);

end

end