function [A, A_error, valid_pixel, model_fit, residual, ...
          R2, noise_sigma, SNR, fit_info] = ...
    fit_carbonate_phases_bis( ...
    wavenumber, ...
    spectrum, ...
    tau_fwhm, ...
    use_ACC, ...
    use_CCHH, ...
    use_MHC, ...
    use_VAT, ...
    use_ARA, ...
    use_CAL, ...
    threshold_sigma, ...
    display_figures, ...
    R2_min, ...
    residual_sigma_max)

%% ================================================================
% FIT DES PHASES CARBONATEES
%
% Le spectre est modélisé comme une somme de phases :
%
%       S(nu) = sum_phi A_phi G_phi(nu) + offset
%
% Chaque phase est convoluée avec la réponse instrumentale.
%
% NOUVEAUX CRITERES :
%
% 1) SNR >= threshold_sigma
%
% 2) R2 >= R2_min
%
% 3) RMS(residu) / sigma_noise <= residual_sigma_max
%
% Le troisième critère permet notamment de rejeter les pixels
% présentant un vrai signal mais ne correspondant pas au modèle.
%
%% ================================================================


%% ================================================================
% Valeurs par défaut
%% ================================================================

if nargin < 14 || isempty(R2_min)
    R2_min = 0.90;
end

if nargin < 15 || isempty(residual_sigma_max)
    residual_sigma_max = 3;
end


%% ================================================================
% Mise en forme
%% ================================================================

wavenumber = wavenumber(:);
spectrum   = spectrum(:);

if length(wavenumber) ~= length(spectrum)

    error('wavenumber et spectrum doivent avoir la même longueur.');

end


%% ================================================================
% Tri du spectre
%% ================================================================

[wavenumber,ind_sort] = sort(wavenumber);

spectrum = spectrum(ind_sort);


%% ================================================================
% Définition des phases
%% ================================================================

phase(1).name  = "ACC";
phase(1).nu    = 1075;
phase(1).FWHM  = 20;
phase(1).ratio = 1;
phase(1).use   = use_ACC;

phase(2).name  = "CCHH";
phase(2).nu    = 1102;
phase(2).FWHM  = 4;
phase(2).ratio = 1;
phase(2).use   = use_CCHH;

phase(3).name  = "MHC";
phase(3).nu    = 1075;
phase(3).FWHM  = 2;
phase(3).ratio = 1;
phase(3).use   = use_MHC;

phase(4).name  = "Vaterite";
phase(4).nu    = [1075 1081 1090];
phase(4).FWHM  = [4 4 4];
phase(4).ratio = [0.4 0.3 1];
phase(4).use   = use_VAT;

phase(5).name  = "Aragonite";
phase(5).nu    = 1084;
phase(5).FWHM  = 2;
phase(5).ratio = 1;
phase(5).use   = use_ARA;

phase(6).name  = "Calcite";
phase(6).nu    = 1085.5;
phase(6).FWHM  = 2;
phase(6).ratio = 1;
phase(6).use   = use_CAL;


%% ================================================================
% Sélection des nombres d'onde
%% ================================================================

mask_wn = isfinite(wavenumber) & isfinite(spectrum);

wavenumber = wavenumber(mask_wn);
spectrum   = spectrum(mask_wn);

N = length(wavenumber);


if N < 5

    A = zeros(6,1);
    A_error = zeros(6,1);

    valid_pixel = false;

    model_fit = zeros(size(spectrum));
    residual = spectrum;

    R2 = 0;
    noise_sigma = NaN;
    SNR = 0;

    fit_info.reason = "Not enough spectral points";

    return

end


%% ================================================================
% Grille de calcul
%% ================================================================

wn_min = min(wavenumber);
wn_max = max(wavenumber);

dw = 0.05;

wn_model = (wn_min:dw:wn_max)';


%% ================================================================
% Construction de chaque phase
%% ================================================================

Nphase = 6;

phase_model = zeros(length(wn_model),Nphase);


for k = 1:Nphase

    if ~phase(k).use
        continue
    end


    G = zeros(size(wn_model));


    for p = 1:length(phase(k).nu)

        sigma = phase(k).FWHM(p)/2.355;


        Gp = phase(k).ratio(p) ./ ...
             (sqrt(2*pi)*sigma) .* ...
             exp(-(wn_model-phase(k).nu(p)).^2 ...
             /(2*sigma^2));


        G = G + Gp;

    end


    %% ------------------------------------------------------------
    % Convolution instrumentale
    %% ------------------------------------------------------------

    if tau_fwhm > 0

        sigma_inst = ...
            tau_fwhm/(2*sqrt(2*log(2)));


        half_win = 4*sigma_inst;


        wn_kernel = ...
            (-half_win:dw:half_win)';


        kernel = exp( ...
            -wn_kernel.^2/(2*sigma_inst^2));


        kernel = kernel/sum(kernel);


        n_pad = length(kernel);


        G_pad = [ ...
            G(1)*ones(n_pad,1); ...
            G; ...
            G(end)*ones(n_pad,1)];


        G_conv = conv(G_pad,kernel,'same');


        G_conv = G_conv( ...
            n_pad+1:n_pad+length(G));


    else

        G_conv = G;

    end


    phase_model(:,k) = G_conv;

end


%% ================================================================
% Interpolation sur les nombres d'onde expérimentaux
%% ================================================================

X = zeros(N,Nphase);

for k = 1:Nphase

    if phase(k).use

        X(:,k) = interp1( ...
            wn_model,...
            phase_model(:,k),...
            wavenumber,...
            'linear',...
            0);

    end

end


%% ================================================================
% Ajout d'un offset
%
% Le dernier coefficient du fit correspond au background constant.
%% ================================================================

X_fit = [X ones(N,1)];


%% ================================================================
% Détection du bruit / signal
%% ================================================================

% Estimation robuste du background
background = median(spectrum);


% Spectre centré
spectrum_centered = spectrum - background;


% MAD robuste
MAD_value = median( ...
    abs(spectrum_centered - ...
    median(spectrum_centered)));


noise_sigma = 1.4826*MAD_value;


%% ================================================================
% Protection contre sigma = 0
%% ================================================================

if ~isfinite(noise_sigma) || noise_sigma <= eps

    noise_sigma = std(spectrum_centered);

end


if ~isfinite(noise_sigma) || noise_sigma <= eps

    noise_sigma = eps;

end


%% ================================================================
% SNR
%% ================================================================

signal_amplitude = max(abs(spectrum_centered));

SNR = signal_amplitude/noise_sigma;


%% ================================================================
% Fit par moindres carrés
%% ================================================================

% Coefficients :
%
% A(1) = ACC
% A(2) = CCHH
% A(3) = MHC
% A(4) = Vaterite
% A(5) = Aragonite
% A(6) = Calcite
% A(7) = offset

beta = X_fit\spectrum;


%% ================================================================
% Contraintes physiques
%
% Les quantités de matière doivent être positives.
%% ================================================================

A = beta(1:6);

offset_fit = beta(7);


A(A < 0) = 0;


%% ================================================================
% Reconstruction du modèle
%% ================================================================

model_fit = X*A + offset_fit;


%% ================================================================
% Résidu
%% ================================================================

residual = spectrum - model_fit;


%% ================================================================
% RMS du résidu
%% ================================================================

residual_rms = sqrt(mean(residual.^2));


%% ================================================================
% Résidu exprimé en unités de bruit
%% ================================================================

residual_sigma = ...
    residual_rms/noise_sigma;
      


%% ================================================================
% R²
%% ================================================================

SS_res = sum(residual.^2);

SS_tot = sum( ...
    (spectrum-mean(spectrum)).^2);


if SS_tot > 0

    R2 = 1 - SS_res/SS_tot;

else

    R2 = 0;

end


%% ================================================================
% Erreur sur A
%
% Estimation approximative basée sur la matrice de covariance.
%% ================================================================

dof = max(N-size(X_fit,2),1);

sigma_fit = sqrt(SS_res/dof);


cov_beta = ...
    sigma_fit^2 * pinv(X_fit'*X_fit);


A_error = sqrt(max(diag(cov_beta(1:6,1:6)),0));


%% ================================================================
% CRITERES DE VALIDITE
%% ================================================================

%% Critère 1 : présence d'un signal

criterion_SNR = ...
    SNR >= threshold_sigma;


%% Critère 2 : qualité globale du fit

criterion_R2 = ...
    R2 >= R2_min;


%% Critère 3 : compatibilité avec le modèle

criterion_model = ...
    residual_sigma <= residual_sigma_max;


%% Critère 4 : au moins une phase positive

criterion_phase = ...
    sum(A) > 0;


%% ================================================================
% Validité finale
%% ================================================================

valid_pixel = ...
    criterion_SNR && ...
    criterion_R2 && ...
    criterion_model && ...
    criterion_phase;


%% ================================================================
% Informations supplémentaires
%% ================================================================

fit_info.noise_sigma = noise_sigma;

fit_info.background = background;

fit_info.signal_amplitude = signal_amplitude;

fit_info.residual_rms = residual_rms;

fit_info.residual_sigma = residual_sigma;

fit_info.criterion_SNR = criterion_SNR;

fit_info.criterion_R2 = criterion_R2;

fit_info.criterion_model = criterion_model;

fit_info.criterion_phase = criterion_phase;

fit_info.R2_min = R2_min;

fit_info.residual_sigma_max = residual_sigma_max;

fit_info.offset = offset_fit;

fit_info.wavenumber = wavenumber;

fit_info.phase_model = X;


%% ================================================================
% AFFICHAGE
%% ================================================================

if display_figures

    figure('Color','white');
    hold on;

    colors = lines(Nphase);


    for k = 1:Nphase

        if phase(k).use

            contribution = X(:,k)*A(k);


            plot( ...
                wavenumber,...
                contribution,...
                '--',...
                'Color',colors(k,:),...
                'LineWidth',1.5,...
                'DisplayName',phase(k).name);

        end

    end


    plot( ...
        wavenumber,...
        spectrum,...
        'ko',...
        'MarkerSize',4,...
        'DisplayName','Experimental');


    plot( ...
        wavenumber,...
        model_fit,...
        'r-',...
        'LineWidth',2.5,...
        'DisplayName','Model');


    xlabel('Wavenumber (cm^{-1})');

    ylabel('Intensity (a.u.)');


    title(sprintf( ...
        'Carbonate fit | R^2 = %.3f | SNR = %.1f | residual = %.2f \\sigma',...
        R2,...
        SNR,...
        residual_sigma));


    legend('Location','best');

    grid on;
    box on;


    %% ------------------------------------------------------------
    % Résidu
    %% ------------------------------------------------------------

    figure('Color','white');

    plot( ...
        wavenumber,...
        residual,...
        'k',...
        'LineWidth',1.5);

    hold on;

    yline( ...
        residual_sigma_max*noise_sigma,...
        'r--',...
        'LineWidth',1.5);

    yline( ...
        -residual_sigma_max*noise_sigma,...
        'r--',...
        'LineWidth',1.5);


    xlabel('Wavenumber (cm^{-1})');

    ylabel('Residual');

    title(sprintf( ...
        'Fit residual | RMS = %.2f \\sigma',...
        residual_sigma));

    grid on;
    box on;


    %% ------------------------------------------------------------
    % Résumé
    %% ------------------------------------------------------------

    fprintf('\n');
    fprintf('=============================================\n');
    fprintf('          CARBONATE FIT\n');
    fprintf('=============================================\n');

    fprintf('SNR              = %.3f\n',SNR);
    fprintf('R2               = %.3f\n',R2);
    fprintf('Residual RMS     = %.3e\n',residual_rms);
    fprintf('Residual / sigma = %.3f\n',residual_sigma);

    fprintf('\nCriteria:\n');

    fprintf('SNR >= %.2f       : %d\n',...
        threshold_sigma,criterion_SNR);

    fprintf('R2 >= %.2f        : %d\n',...
        R2_min,criterion_R2);

    fprintf('Residual <= %.2fσ : %d\n',...
        residual_sigma_max,criterion_model);

    fprintf('Phase detected    : %d\n',...
        criterion_phase);

    fprintf('\nValid pixel       : %d\n',valid_pixel);

    fprintf('=============================================\n');

end

end