
%% Variables needed for running the code on its own

clear all;
close all;

% ---- Matlab files function -------------------------------------------

% addpath('C:\Users\sacha.bucourt\Documents\MATLAB\MesFonctions')
% addpath('C:\Users\sacha.bucourt\Documents\MATLAB\fonctions_banque_spectre')
% addpath('C:\Users\sacha.bucourt\Documents\MATLAB\model_carbonate_lsqcurvefit')
% addpath('C:\Users\sacha.bucourt\Documents\MATLAB\CHIRP\')
% addpath('C:\Users\sacha.bucourt\Documents\MATLAB\model_carbonate_lsqnonneg')

addpath('D:\MATLAB')
addpath('D:\MATLAB\CHIRP')
addpath('D:\MATLAB\model_carbonate_lsqcurvefit')
addpath('D:\MATLAB\MesFonctions')


%% ======================================================================
%  1. PARAMETRAGE -- A COMPLETER

 
% ---- 1.1 Acquisition / chargement des donnees (LOADSRSIMAGESTACK) -----

main_dir = 'C:\Users\sacha\OneDrive\Documents\FRESNEL\CHIRP\260715\14-15-43_coral_2ps'
% main_dir = 'C:\Users\sacha.bucourt\Documents\Data lab\CHIRP\260715\14-15-43_coral_2ps'

sub_dir  = '';
sub_dir_save = [main_dir '/extracted_data/' sub_dir];

n_depart = 3; % 3 = saute '.' et '..', 4 si dossier cache supplementaire
n_ch=1;
 
wavelengths =[927.2,927.5,927.7,928.1,928.5,929.1,929.6,930.2,931.1,...
            926.7,926.3,925.8];  % nm, ordre d'acquisition (pas trie)


wavelengths_7ps =[928.6,929.1,929.5,929.8,930.2,930.6,931.1,928,927.6, ... 
  927.2,926.8,926.4,926,925.5,928.3];

pompe = 1031;  % nm, longueur d'onde de la pompe
wavenumber = 1e7 ./ wavelengths - 1e7 ./ pompe;   % cm^-1
wavenumber_7ps=1e7 ./ wavelengths_7ps - 1e7 ./ pompe;

fwhm_mesure = 10.7; %fwhm mesuré de la calcite
fwhm_aragonite = 3.5; %fwhm réel de la calcite
[f_calc, fwhm_inst] = deconvolve(fwhm_mesure, fwhm_aragonite, 0);
% fwhm_inst  = 6.7;   % cm-1
 
% ---- 1.2 Pretraitement (soustraction de fond) --------------------------

%Coordonnées ROI background dont l'intensité des piexels est moyenné puis 
%soustrait au reste des pixels 

x1_s = 15; % ligne start 
x1_e = 30; % ligne end
x2_s = 5; % column start
x2_e = 15; % column end

% noise study on line / column - spatial variation  : 
wi= 4; %wanumber number wi
idl = 125; idc=97;  %index line/column
xl_s=100; xl_e=125; xc_s=109; xc_e=125; %sart/end line/column
 
% ---- 1.3 Modele theorique des phases (MODEL_CARBONATE_PHASES) ---------
 
use_CAL   = false;       % Calcite
use_ARA   = true;        % Aragonite
use_VAT   = false;       % Vaterite
use_ACC   = true;        % Carbonate de calcium amorphe
use_CCHH  = false;       % Monohydrocalcite hydratee (CCHH)
use_MHC   = false;       % Monohydrocalcite (MHC)
 
% ---- 1.4 Initialisation lineaire (INIT_PIXEL_AMPLITUDES) --------------
R2_min          = 0.5;   % R^2 minimal pour valid_pixel (diagnostic seulement,
                          % ne filtre aucun pixel a ce stade)
threshold_sigma = 1;     % facteur x bruit sous lequel une amplitude initiale
                          % est mise a 0 (bruit estime par residu pour
                          % l'instant -- a remplacer par le bruit substrat,
                          % cf. schema)
 
% ---- 1.5 Fit non lineaire (FIT_PIXEL_PHASES) ---------------------------
% Un booleen par phase, dans l'ordre CAL, ARA, VAT, ACC, CCHH, MHC
nu_is_variable    = [false true false true false false];  % position libre ?
FWHM_is_variable  = [false true false true false false];  % largeur libre ?
 
% Bornes absolues (cm^-1) par phase, dans l'ordre CAL, ARA, VAT, ACC, CCHH, MHC
% -- la meme borne s'applique a toutes les raies d'une phase (ex : les 3
% raies de VAT partagent [nu_LB(3) nu_UB(3)]). Ignore pour une phase dont
% nu_is_variable/FWHM_is_variable est false.
nu_LB   = [1084.5,   1084, 1073, 1073, 1097, 1066];   % cm^-1
nu_UB   = [1086.5, 1086.5, 1093, 1082, 1102, 1070];   % cm^-1
FWHM_LB = [     1,      1,    3,   20,    3,    3];   % cm^-1
FWHM_UB = [     5,      5,   10,   40,   10,   10];   % cm^-1
 
lineshape_type  = 'gaussian';    % 'gaussian' pour l'instant ('lorentzian' a venir)
ci_alpha        = 0.5;          % niveau pour l'IC sur chaque amplitude (0.05 -> IC 95%)

% ---- Comparer au 7ps -----------------------------------------
shift_row = 2;
shift_col = 2;


% path2phase_model_7ps = 'C:\Users\sacha.bucourt\Documents\Data lab\CHIRP\260708\16-25-59_ACC_Cal_7ps\extracted_data\phase_model';
% path2ref_spectra_7ps = 'C:\Users\sacha.bucourt\Documents\Data lab\CHIRP\260708\16-25-59_ACC_Cal_7ps\extracted_data\ref_spectra';

% path2phase_model_2ps ='C:\Users\sacha\OneDrive\Documents\FRESNEL\CHIRP\260708\14-55-09_ACC_Cal - copie\extracted_data\phase_model.mat';
% path2ref_spectra_2ps ='C:\Users\sacha\OneDrive\Documents\FRESNEL\CHIRP\260708\14-55-09_ACC_Cal - copie\extracted_data\ref_spectra.mat';

% phase_model_7ps = load(path2phase_model_7ps); 
% ref_spectra_7ps = load(path2ref_spectra_7ps);

% ---- 1.6 Segmentation / quantification (SEGMENT_CARBONATE_PHASES) -----
R2_min_final            = 0.5;   % R^2 minimal pour garder un pixel (filtre reel, ici)
threshold_sigma_final   = 1;     % facteur x noise_map pour compter un point "au-dessus du bruit"
min_points_above_noise  = 1;     % nb minimal de points au-dessus du bruit pour garder le pixel
alpha_dominance         = 1;

dominance_phases = [false false false true false false]; % true =
%                                 cette phase participe a la comparaison
%                                 de dominance.
detection_method = 'significance';
threshold_A = 10;

phase2plot = [2 4]; % 1=CAL, 2=ARA, 3=VAT, 4=ACC, 5=CCHH, 6=MHC
nbr_pix_per_phase = [10 15]; %number of pixel corresponding to phase 
%mentionned in "phase2plot"



% ---- 1.7 Affichage ------------------------------------------------------
load_pixel_fit = false;
pixel_fit_file = 'data/pixel_fit.mat';

do_noise_study = true;
do_lsqnonneg_treatment = false; 
mesure_fwhm = false;

display_intensity_maps = true;
display_figures = true;    % figures de controle a chaque etape
plot_ref_spectra = true;
plot_ref_spectra_shifted = false;

display_fit_stat = true;
display_R2_stat = true; 


%%-----------------------------------------------------------------------
%% 2. EXECUTION DU PIPELINE
%%----------------------------------------------------------------------

% ---- 2.1 Chargement ---------------------------------------------------
[imgs, acq] = loadSRSImageStack(main_dir, sub_dir, n_depart ,wavenumber);

I_raw = squeeze(imgs);

if mesure_fwhm
    [FWHM_mesure, FWHM_error, fit_result, ROI_background, ROI_phase] = ...
        measure_reference_FWHM(I_raw, wavenumber);
end

%% ---- background substraction --------------------------------------- 

[I_corr, background_spectrum, noise_map, noise_global] = ...
    estimate_background_noise_roi(I_raw, wavenumber, x1_s, x1_e, x2_s, x2_e);

if do_noise_study 
    [fit_params, mean_noise] = noise_study(I_corr, wavenumber, background_spectrum,idl, idc, wi, xl_s, xl_e, xc_s, xc_e);
end


figure(100);
imagesc(sum(I_raw,3));
colorbar;
colormap(gray); % Optionnel : pour une meilleure visualisation

% Ajout du rectangle pour le ROI
hold on;
rectangle('Position', [x2_s, x1_s, x2_e - x2_s, x1_e - x1_s], ...
          'EdgeColor', 'r', ...
          'LineWidth', 2, ...
          'LineStyle', '-');
% Ajout des lignes idl et idc si do_noise_study est vrai
if do_noise_study
    % Ligne horizontale pour idl (uniquement entre x2_s et x2_e)
    line([xl_s, xl_e], [idl, idl], 'Color', 'g', 'LineWidth', 1.5, 'LineStyle', '--');

    % Ligne verticale pour idc (uniquement entre x1_s et x1_e)
    line([idc, idc], [xc_s, xc_e], 'Color', 'b', 'LineWidth', 1.5, 'LineStyle', '--');
end

hold off;


%% ---- Display main wavenumber images ---------------------------------

if display_intensity_maps 

    % figure(101); imagesc(sum(I_corr,3)); colorbar;
    %Afficher images SRS 
    n1 = 8; 
    n2 = 6;
    n3 = 2;
    n4 = 3; 
    % n5 = 5;
    I1 = I_corr(:,:,n1); % ACC Chira
    I2 = I_corr(:,:,n2); % inf ACC 
    I3 = I_corr(:,:,n3); % Calcite
    I4 = I_corr(:,:,n4); % ACC 
    % I5 = I_corr(:,:,n5); % fluo 2
    
    figure(102); clf;
    Imax = 10;
    Imin= -10;
    
    subplot(2,3,1);
    imagesc(I1); caxis([Imin Imax]); colorbar;
    title('ACC Chahira (I1)');
    
    
    subplot(2,3,3);
    imagesc(I2); caxis([Imin Imax]); colorbar;
    title('inf ACC (I2)');
    
    
    subplot(2,3,2);
    imagesc(I3); caxis([Imin 300]); colorbar;
    title('Calcite (I3)');
    hold on;
    
    
    subplot(2,3,4);
    imagesc(I4); caxis([Imin Imax]); colorbar;
    title('ACC (I4)');
    
    
        subplot(2,3,5);
    imagesc(I4-I3); caxis([-5 5]); colorbar;
    title('I4-I3)');
    
    subplot(2,3,6);
    imagesc(I4-I1); caxis([-5 5]); colorbar;
    title('I4-I1');  
    
    sgtitle('Map ACC + Calcite', 'FontSize', 12, 'FontWeight', 'bold');

end

%% ---- 2.3 Modele theorique ----------------------------------------

[phase_model] = model_carbonate_phases( ...
          fwhm_inst, ... %fwhm_inst
          use_CAL, ... %use_CAL
          use_ARA, ... %use_ARA
          use_VAT, ... %use_VAT
          use_ACC, ... %use_ACC
          use_CCHH, ... %use_CCHH
          use_MHC, ... %use_MHC
          true);

%% ---- 2.4 Initialisation lineaire lsqnonneg ---------------------

pixel_data = init_pixel_amplitudes( ...
          I_corr, phase_model, wavenumber, ...
          R2_min, threshold_sigma, true);


%% ---- 2.5 Fit non lineaire lsqcurvefit ---------------------------

pixel_fit = fit_pixel_phases( ...
    I_corr, phase_model, wavenumber, pixel_data, ...
    nu_is_variable, FWHM_is_variable, fwhm_inst, ...
    nu_LB, nu_UB, FWHM_LB, FWHM_UB, ...
    lineshape_type, ci_alpha, display_figures);

%% ---- 2.6 Segmentation / quantification --------------------------

[phase_map, composition_map] = segment_carbonate_phases_bis( ...
          I_corr, pixel_fit, phase_model, noise_map, ...
          R2_min_final, threshold_sigma_final, min_points_above_noise, ...
          alpha_dominance, display_figures);

presence_map = plot_phase_presence_map( ...
          pixel_fit, phase_map, phase_model, 4, ...
          detection_method, threshold_A, display_figures);

%% ---- Spectra of selected pixels ----------------------------------
ref_spectra = plot_phase_reference_spectra( ...
          I_corr, wavenumber, pixel_fit, phase_map, phase_model, ...
          phase2plot, nbr_pix_per_phase,fwhm_inst,true);

if plot_ref_spectra
    plot_pixel_fits_from_ref_spectra( ...
              ref_spectra, I_corr, wavenumber, pixel_fit, phase_model, ...
              fwhm_inst, 12)
end

%% ---- Shifted Spectra compare to 7ps  ----------------------------------
ref_spectra_shifted = extract_shifted_reference_spectra( ...
          ref_spectra_7ps,wavenumber_7ps, I_corr, wavenumber,...
          phase_model, shift_row, shift_col, fwhm_inst, pixel_fit, ...
          false, false);

if plot_ref_spectra_shifted
    plot_pixel_fits_from_ref_spectra( ...
              ref_spectra_shifted, I_corr, wavenumber, pixel_fit, phase_model, ...
              fwhm_inst, 12)
end

%% ---- Display Fit Stat --------------------------------------------

if display_fit_stat 

    fprintf('\n');
    fprintf('============================================================\n');
    fprintf('          STATISTIQUES DES SPECTRES DE REFERENCE\n');
    fprintf('============================================================\n');

    display_reference_statistics(ref_spectra, fwhm_inst)

    if plot_ref_spectra_shifted
        fprintf('\n');
        fprintf('============================================================\n');
        fprintf('      STATISTIQUES DES SPECTRES DE REFERENCE SHIFTED\n');
        fprintf('============================================================\n');
    
        display_reference_statistics(ref_spectra_shifted, fwhm_inst)
    end
end 

% Stat on R² 

if display_R2_stat

    stats = analyze_R2(pixel_fit,phase_model,display_figures);

end

%% ----- traitement lsqnonneg ---------------------------------------

if do_lsqnonneg_treatment 

    min_points_bckg = 3;
    residual_sigma_max = 10;
    
    
    [phase_map, A_maps, ratio_maps] = ...
        map_carbonate_phases( ...
        I_corr, ...            % stack d'images
        wavenumber, ...        % nombres d'onde
        n_ch, ...              % canal
        fwhm_inst, ...          % FWHM réponse instrumentale
        true, ...              % ACC
        false, ...             % CCHH
        false, ...             % MHC
        false, ...             % Vaterite
        false, ...             % Aragonite
        true, ...              % Calcite
        threshold_sigma, ...   % seuil bruit = 3 sigma
        min_points_bckg,...    %min_points_bckg
        0.5, ...               % seuil ACC/Calcite
        true,  ...     
        sub_dir_save,...
        R2_min, ...
        residual_sigma_max);   
    
    
    results = analyze_carbonate_phase_spectra( ...
        I_corr,...
        phase_map,...
        wavenumber,...
        n_ch,...
        fwhm_inst,...
        threshold_sigma,...
        min_points_bckg,...
        true,...          
        R2_min, ...
        residual_sigma_max);
end

%% ---------SAVE ----------------------------------------

% Sauvegarder une structure
% saveDataOrImage(myStruct, 'results/structures', 'Name', 'my_struct');

% Sauvegarder une image en PNG
% saveDataOrImage(myImage, 'results/images', 'Name', 'my_image', 'Format', 'png');

% Sauvegarder une image en MAT (pour conserver les données brutes)
% saveDataOrImage(myImage, 'results/images', 'Name', 'my_image_raw', 'Format', 'mat');

saveDataOrImage(phase_model, sub_dir_save, 'Name','phase_model');
saveDataOrImage(pixel_fit, sub_dir_save, 'Name','pixel_fit');
saveDataOrImage(ref_spectra, sub_dir_save, 'Name','ref_spectra');
