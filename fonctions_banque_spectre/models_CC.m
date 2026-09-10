function signal_conv = models_CC(...
    wavenumber_sorted,...
    sp_sorted,...
    tau_fwhm,...
    display_figures,...
    offset,...
    A_ACC,...
    A_CCHH,...
    A_MHC,...
    A_VAT,...
    A_ARA,...
    A_CAL)
 
%% =======================
%      Carbonate phases
%% =======================

phase(1).name="ACC";
phase(1).A=A_ACC;
phase(1).nu=1075;
phase(1).FWHM=20;
phase(1).ratio=1;

phase(2).name="CCHH";
phase(2).A=A_CCHH;
phase(2).nu=1102;
phase(2).FWHM=4;
phase(2).ratio=1;

phase(3).name="MHC";
phase(3).A=A_MHC;
phase(3).nu=1075;
phase(3).FWHM=2;
phase(3).ratio=1;

phase(4).name="Vaterite";
phase(4).A=A_VAT;
phase(4).nu = [1075 1081 1090];
phase(4).FWHM = [4 4 4];        
phase(4).ratio = [0.4 0.3 1];

phase(5).name="Aragonite";
phase(5).A=A_ARA;
phase(5).nu=1084;
phase(5).FWHM=2;
phase(5).ratio=1;

phase(6).name="Calcite";
phase(6).A=A_CAL;
phase(6).nu=1085.5;
phase(6).FWHM=2;
phase(6).ratio=1;

%% --- Grille commune haute résolution ---
wn_min = min(wavenumber_sorted);
wn_max = max(wavenumber_sorted);
dw     = 0.05;                              % pas fin pour la convolution
wavenumber = wn_min : dw : wn_max;          % grille théorique
 

%% --- Modèle gaussien théorique + convolution instrumentale ---

signal=zeros(size(wavenumber));

signal_phase      = cell(length(phase),1);
signal_phase_conv = cell(length(phase),1);

for k = 1:length(phase)

    if phase(k).A == 0
        continue
    end

    G = zeros(size(wavenumber));
    
    for p = 1:length(phase(k).nu)
    
        sigma = phase(k).FWHM(p)/2.355;
    
        Gp = phase(k).ratio(p) * ...
             phase(k).A/(sqrt(2*pi)*sigma) .* ...
             exp(-(wavenumber-phase(k).nu(p)).^2/(2*sigma^2));
    
        G = G + Gp;
    
    end

    G = G + offset; 

    % -------- Convolution instrumentale --------
    if tau_fwhm > 0

        sigma_wn = tau_fwhm/(2*sqrt(2*log(2)));

        half_win  = 4*sigma_wn;
        wn_kernel = -half_win:dw:half_win;

        kernel = exp(-wn_kernel.^2/(2*sigma_wn^2));
        kernel = kernel/sum(kernel);

        n_pad = length(wn_kernel);

        G_pad = [G(1)*ones(1,n_pad) G G(end)*ones(1,n_pad)];

        G_conv = conv(G_pad,kernel,'same');
        G_conv = G_conv(n_pad+1:n_pad+length(G));

    else

        G_conv = G;

    end

    signal_phase_conv{k} = G_conv;

    signal = signal + G_conv;

end
 
signal_conv = signal;
signal_display = signal_conv/max(signal_conv);

% signal_display = 1.07*signal_conv/max(signal_conv); %coeff display
 
if display_figures

    figure;
    hold on;

    colors = lines(length(phase));

    % ----- Contributions de chaque phase -----
    for k = 1:length(phase)

        if phase(k).A==0
            continue
        end

        plot(wavenumber,...
             signal_phase_conv{k}/max(signal_conv),...
             '--',...
             'Color',colors(k,:),...
             'LineWidth',1.8,...
             'DisplayName',phase(k).name);

    end

    % ----- Somme des contributions -----
    plot(wavenumber,...
         signal_display,...
         'k',...
         'LineWidth',3,...
         'DisplayName','Model');

    % ----- Spectre expérimental -----
    sp_display = sp_sorted - min(sp_sorted);
    sp_display = sp_display/max(sp_display);

    plot(wavenumber_sorted,...
         sp_display,...
         'ro-',...
         'MarkerFaceColor','r',...
         'LineWidth',1.5,...
         'DisplayName','Experimental');

    xlabel('Wavenumber (cm^{-1})')
    ylabel('Normalized intensity')

    title('Carbonate model')

    legend('Location','best')

    grid on
    box on

end

end




