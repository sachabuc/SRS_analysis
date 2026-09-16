function [phase_model] = ...
          model_carbonate_phases( ...
          tau_fwhm, ...
          use_ACC, ...
          use_CCHH, ...
          use_MHC, ...
          use_VAT, ...
          use_ARA, ...
          use_CAL, ... 
          display_figures)

%% ================================================================
%  MODELISATION DES PHASES DU CARBONATE
%
% Chaque G_phi est une gaussienne normalisée en aire.
%
% La réponse instrumentale est également supposée gaussienne.
% La convolution est donc faite analytiquement :
%
%   sigma_eff^2 = sigma_phase^2 + sigma_instrument^2
%
%
% PHASES :
%
%   1 = ACC
%   2 = CCHH
%   3 = MHC
%   4 = Vaterite
%   5 = Aragonite
%   6 = Calcite
%
% use_xxx = true  -> phase utilisée
% use_xxx = false -> phase ignorée
%
%
%
% SORTIE :
%
%  structure phase_model
%

%% ================================================================
% 1. Définition des phases


phase_model(1).name  = "CAL";
phase_model(1).nu    = 1085.5;
phase_model(1).FWHM  = 2;
phase_model(1).ratio = 1;
phase_model(1).sigma_eff = 0;
phase_model(1).A = 0;
phase_model(1).use   = use_CAL;

phase_model(2).name  = "ARA";
phase_model(2).nu    = 1085.5;
phase_model(2).FWHM  = 2;
phase_model(2).ratio = 1;
phase_model(2).sigma_eff = 0;
phase_model(2).A = 0;
phase_model(2).use   = use_ARA;

phase_model(3).name  = "VAT";
phase_model(3).nu    = [1075 1081 1090];
phase_model(3).FWHM  = [4 4 4];
phase_model(3).ratio = [0.4 0.3 1]; 
phase_model(3).sigma_eff = [0 0 0];
phase_model(3).A = 0;
phase_model(3).use   = use_VAT;

phase_model(4).name  = "ACC";
phase_model(4).nu    = 1077;
phase_model(4).FWHM  = 20;
phase_model(4).ratio = 1;
phase_model(4).sigma_eff = 0;
phase_model(4).A = 0;
phase_model(4).use   = use_ACC;

phase_model(5).name  = "CCHH";
phase_model(5).nu    = 1102;
phase_model(5).FWHM  = 4;
phase_model(5).ratio = 1;
phase_model(5).sigma_eff = 0;
phase_model(5).A = 0;
phase_model(5).use   = use_CCHH;

phase_model(6).name  = "MHC";
phase_model(6).nu    = 1075;
phase_model(6).FWHM  = 2;
phase_model(6).ratio = 1;
phase_model(6).sigma_eff = 0;
phase_model(6).A = 0;
phase_model(6).use   = use_MHC;


%% ================================================================
% 2. Grille théorique

wn_min = 1050;
wn_max = 1150;

dw = 0.05;

wavenumber = wn_min:dw:wn_max;

%% ================================================================
% 3. Réponse instrumentale

if tau_fwhm > 0

    sigma_inst = tau_fwhm/2.355;

else

    sigma_inst = 0;

end


%% ================================================================
% 4. Calcul des sigma_eff

% On conserve également chaque fonction de base
% pour pouvoir afficher les contributions.

for k = 1:length(phase)

    % -------------------------------------------------------------
    % Phase désactivée
    % -------------------------------------------------------------

    if ~phase(k).use

        continue

    end

    % -------------------------------------------------------------
    % Initialisation
    % -------------------------------------------------------------

    G = zeros(size(wavenumber));

    % -------------------------------------------------------------
    % Normalisation des ratios pour la vatérite 
    % -------------------------------------------------------------

    ratios = phase(k).ratio;

    ratios = ratios/sum(ratios);

    % -------------------------------------------------------------
    % Construction de chaque raie
    % -------------------------------------------------------------

    for p = 1:length(phase(k).nu)


        % FWHM -> sigma
        sigma_phase = ...
            phase(k).FWHM(p)/2.355;


        % ---------------------------------------------------------
        % Convolution analytique
        %
        % G_sigma_phase * G_sigma_inst
        %
        % sigma_eff² =
        % sigma_phase² + sigma_inst²
        % ---------------------------------------------------------

        sigma_eff(p) = sqrt(sigma_phase^2+sigma_inst^2);

        phase(k).sigma_eff(p) = sigma_eff(p);

        % ---------------------------------------------------------
        % Gaussienne normalisée en aire
        % ---------------------------------------------------------

        Gp = ratios(p) ./ (sqrt(2*pi)*sigma_eff) .* ...
             exp(-(wavenumber-phase(k).nu(p)).^2 / (2*sigma_eff^2));

        G = G+Gp;

    end

end

%% ================================================================
% 5. AFFICHAGE
%% ================================================================

if display_figures

    %% ------------------------------------------------------------
    % Grille dense pour affichage
    %% ------------------------------------------------------------

    dw_display = 0.01;

    wavenumber_display = ...
        min(wavenumber_sorted):dw_display:max(wavenumber_sorted);


    %% ------------------------------------------------------------
    % Calcul des contributions sur grille dense
    %% ------------------------------------------------------------

    phase_display = cell(6,1);

    for k = 1:length(phase)

        if ~phase(k).use
            continue
        end

        G_display = zeros(size(wavenumber_display));

        ratios = phase(k).ratio;
        ratios = ratios/sum(ratios);

        for p = 1:length(phase(k).nu)

            sigma_phase = ...
                phase(k).FWHM(p)/2.355;

            if tau_fwhm > 0
                sigma_inst = tau_fwhm/2.355;
            else
                sigma_inst = 0;
            end

            % Convolution analytique
            sigma_eff = sqrt( ...
                sigma_phase^2 + sigma_inst^2);

            % Gaussienne normalisée en aire
            Gp = ratios(p) ./ ...
                 (sqrt(2*pi)*sigma_eff) .* ...
                 exp(-(wavenumber_display-phase(k).nu(p)).^2 ...
                 /(2*sigma_eff^2));

            G_display = G_display + Gp;

        end

        % Quantité de matière
        phase_display{k} = ...
            A(k)*G_display;

    end

    %% ------------------------------------------------------------
    % Modèle total
    %% ------------------------------------------------------------

    total_display = ...
        offset_fit*ones(size(wavenumber_display));

    for k = 1:length(phase)

        if phase(k).use

            total_display = ...
                total_display + phase_display{k};

        end

    end

    %% ------------------------------------------------------------
    % Figure
    %% ------------------------------------------------------------

    figure( ...
        'Color','white',...
        'Position',[100 100 1100 700]);

    hold on;

    %% ------------------------------------------------------------
    % Contributions individuelles
    %% ------------------------------------------------------------

    colors = lines(6);

    for k = 1:length(phase)

        if ~phase(k).use
            continue
        end

        plot(wavenumber_display,...
             phase_display{k},...
             '--',...
             'Color',colors(k,:),...
             'LineWidth',2,...
             'DisplayName',phase(k).name);

    end


    %% ------------------------------------------------------------
    % Modèle total
    %% ------------------------------------------------------------

    plot(wavenumber_display,...
         total_display,...
         'k-',...
         'LineWidth',3,...
         'DisplayName','Total fit');


    %% ------------------------------------------------------------
    % Mise en forme
    %% ------------------------------------------------------------

    xlabel('Wavenumber (cm^{-1})',...
           'FontSize',13);

    ylabel('Intensity (a.u.)',...
           'FontSize',13);

    title(sprintf( ...
        'Carbonate fit : R^2 = %.4f | SNR = %.2f',...
        R2,SNR),...
        'FontSize',14);

    legend('Location','best');

    grid on;
    box on;

    set(gca,'FontSize',12);

end

end