function results = analyze_carbonate_phase_spectra( ...
    imgs, phase_map, wavenumber, n_ch, tau_fwhm, ...
    threshold_sigma, min_points_bckg, display_figures,R2_min,residual_sigma_max)

%% ================================================================
% Spectres agrégés des différentes phases à partir de phase_map
%
% phase_map :
%   0 = background
%   1 = ACC
%   2 = CCHH
%   3 = MHC
%   4 = Vaterite
%   5 = Aragonite
%   6 = Calcite
%% ================================================================


%% --- Extraction du canal ---

if ndims(imgs) == 4

    data = squeeze(imgs(:,:,:,n_ch));

else

    data = imgs;

end


[Nx,Ny,Nw] = size(data);

wavenumber = wavenumber(:);


%% ================================================================
% Vérification
%% ================================================================

if length(wavenumber) ~= Nw

    error('wavenumber et imgs ont des dimensions incompatibles.');

end

if ~isequal(size(phase_map),[Nx Ny])

    error('phase_map doit avoir la même taille X,Y que imgs.');

end


%% ================================================================
% TRI DES NOMBRES D'ONDE
%
% IMPORTANT :
% On trie simultanément wavenumber et la 3e dimension
% de data pour conserver la correspondance :
%
% data(:,:,k) <-> wavenumber(k)
%% ================================================================

[wavenumber,ind_sort] = sort(wavenumber);

data = data(:,:,ind_sort);


%% ================================================================
% Noms des phases
%% ================================================================

names = { ...
    'ACC',...
    'CCHH',...
    'MHC',...
    'Vaterite',...
    'Aragonite',...
    'Calcite'};

Nphase = 6;


%% ================================================================
% Initialisation
%% ================================================================

spectra_phase = zeros(Nw,Nphase);

Npixels = zeros(Nphase,1);


%% ================================================================
% Extraction des spectres
%% ================================================================

for k = 1:Nphase

    % -------------------------------------------------------------
    % Masque de la phase
    % -------------------------------------------------------------

    mask = (phase_map == k);

    [ix,iy] = find(mask);

    Npixels(k) = length(ix);


    if Npixels(k) == 0

        continue

    end


    % -------------------------------------------------------------
    % Somme des spectres
    % -------------------------------------------------------------

    for p = 1:Npixels(k)

        spectrum = squeeze(data(ix(p),iy(p),:));


        if all(isfinite(spectrum))

            spectra_phase(:,k) = ...
                spectra_phase(:,k) + spectrum;

        end

    end

end


%% ================================================================
% Spectre total
%% ================================================================

spectrum_total = sum(spectra_phase,2);


%% ================================================================
% FIT
%% ================================================================

[A,A_error,valid_pixel,model_fit,residual,...
 R2,noise_sigma,SNR,fit_info] = ...
    fit_carbonate_phases( ...
        wavenumber,...
        spectrum_total,...
        tau_fwhm,...
        true,...       % ACC
        false,...       % CCHH
        false,...       % MHC
        false,...       % Vaterite
        false,...       % Aragonite
        true,...       % Calcite
        threshold_sigma,...
        min_points_bckg,...
        display_figures,...
        R2_min, ...
        residual_sigma_max);


%% ================================================================
% AFFICHAGE
%% ================================================================

if display_figures

    figure('Color','white');
    hold on;

    colors = lines(Nphase);


    % -------------------------------------------------------------
    % Spectres de chaque phase
    % -------------------------------------------------------------

    for k = 1:Nphase

        if Npixels(k) > 0

            plot( ...
                wavenumber,...
                spectra_phase(:,k),...
                '--',...
                'Color',colors(k,:),...
                'LineWidth',1.5,...
                'DisplayName', ...
                sprintf('%s (%d pixels)',...
                names{k},Npixels(k)));

        end

    end


    % -------------------------------------------------------------
    % Spectre total
    % -------------------------------------------------------------

    plot( ...
        wavenumber,...
        spectrum_total,...
        'k',...
        'LineWidth',2.5,...
        'DisplayName','Total');


    % -------------------------------------------------------------
    % Fit
    % -------------------------------------------------------------

    plot( ...
        wavenumber,...
        model_fit,...
        'r',...
        'LineWidth',2,...
        'DisplayName','Fit');


    xlabel('Wavenumber (cm^{-1})');

    ylabel('Intensity (a.u.)');

    title(sprintf( ...
        'Aggregated carbonate spectra - R^2 = %.3f',...
        R2));

    legend('Location','best');

    grid on;
    box on;

end


%% ================================================================
% RESULTATS
%% ================================================================

results.wavenumber = wavenumber;

results.spectra_phase = spectra_phase;

results.spectrum_total = spectrum_total;

results.Npixels = Npixels;

results.A = A;

results.A_error = A_error;

results.model_fit = model_fit;

results.residual = residual;

results.R2 = R2;

results.noise_sigma = noise_sigma;

results.SNR = SNR;

results.valid_pixel = valid_pixel;

results.fit_info = fit_info;

end