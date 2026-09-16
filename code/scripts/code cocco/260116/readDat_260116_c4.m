%% Variables needed for running the code on its own
clear all;
close all;
%n_pixel_y = 100; n_pixel_x = 100;
addpath('C:\Users\sacha.bucourt\Documents\MATLAB\MesFonctions')

%% A COMPLETER : 

find_peaks = false;
contrast = true;

% chemin vers data SRS : 

main_dir = 'C:\Users\sacha.bucourt\Documents\Data lab\spectres\campagne cocco\260116\14-17-49_cell4';

sub_dir  = '';
sub_dir_save = [main_dir '/extracted_data/' sub_dir];

title_fig = '..';


%260114a Z0
wavelengths = [926.9, 930.6, 927.8, 928.7, 929.2]   ; 

pompe = 1030.75;
wavenumber = 1e7 ./ wavelengths - 1e7 ./ pompe; % wavenumber in cm-1

%% get all the contents in the directory
full_dir = [main_dir '/' sub_dir];
cntnt    = dir(full_dir);
n_cntnt  = length(cntnt);

%% find number of analog and digital channels by reading files types in
% these folders
n_ch_ana = 0;
n_ch_dig = 0;

n_depart = 3; %ou 4 en fonction
% Note that there are '2 junk folders' in any folder. They are hidden and
% their names are '.' and '..'. Therefore I start from folder 3 which is
% our first data folder. Please donot save anything else in your 'time
% stamped' folder as it will cause problems in reading the channels
% correctly.
for ni = n_depart : n_cntnt
    cd([full_dir '/' cntnt(ni).name])
    
    
    files_ana = dir('*.ASC');
    files_dig = dir('*.DAT');
    if ~isempty(files_ana)
        n_ch_ana = n_ch_ana + 1;    
    elseif ~isempty(files_dig)
        n_ch_dig = n_ch_dig + 1;
    end
    
    if ni == n_depart
        files_txt = dir('*.TXT');
        n_files_txt = length(files_txt);
    end
end
clear ni
n_ch_tot = n_ch_ana + n_ch_dig;


%% find image acquisition parameters
n_pixel_x               = zeros(n_files_txt,1);
n_pixel_y               = zeros(n_files_txt,1);
wdth_img                = zeros(n_files_txt,1);
hght_img                = zeros(n_files_txt,1);
pol_angle               = zeros(n_files_txt,1);
pol_offset              = zeros(n_files_txt,1);
z_pos                   = zeros(n_files_txt,1);
x_min                   = zeros(n_files_txt,1);
x_max                   = zeros(n_files_txt,1);
y_min                   = zeros(n_files_txt,1);
y_max                   = zeros(n_files_txt,1);
calib                   = zeros(n_files_txt,1);
stage_x                 = zeros(n_files_txt,1);
stage_y                 = zeros(n_files_txt,1);
delay_offset            = zeros(n_files_txt,1);
delay_img               = zeros(n_files_txt,1);
dwell_time              = zeros(n_files_txt,1);
pixel_rep               = zeros(n_files_txt,1);
lambda_tisaf            = zeros(n_files_txt,1);   
OPO_measured_wavelength = zeros(n_files_txt,1);
OPO_set_wavelength      = zeros(n_files_txt,1);
OPO_power               = zeros(n_files_txt,1);

ni = n_depart;
cd([full_dir '/' cntnt(ni).name])
for nj = 1 : n_files_txt
    fid = fopen(files_txt(nj).name,'r');
    C = textscan(fid, '%s');
    data_txt = C{1};
    n_data_txt = length(data_txt);
    for nk = 1 : n_data_txt
        if strcmp(data_txt(nk),'NUMBER_OF_POINTS_X') == 1
            n_pixel_x(nj,1) = str2double(data_txt(nk+1));
        elseif strcmp(data_txt(nk),'NUMBER_OF_POINTS_Y') == 1
            n_pixel_y(nj,1) = str2double(data_txt(nk+1));
        elseif strcmp(data_txt(nk),'IMAGE_WIDTH') == 1
            wdth_img(nj,1) = str2double(data_txt(nk+1));
        elseif strcmp(data_txt(nk),'IMAGE_HEIGTH') == 1
            hght_img(nj,1) = str2double(data_txt(nk+1));
        elseif strcmp(data_txt(nk),'POLAR') == 1
            pol_angle(nj,1) = str2double(data_txt(nk+1));
        elseif strcmp(data_txt(nk),'POLAR_OFFSET') == 1
            pol_offset(nj,1) = str2double(data_txt(nk+1));
        elseif strcmp(data_txt(nk),'FOCUS') == 1
            z_pos(nj,1) = str2double(data_txt(nk+1));
        elseif strcmp(data_txt(nk),'X_MIN') == 1
            x_min(nj,1) = str2double(data_txt(nk+1));
        elseif strcmp(data_txt(nk),'X_MAX') == 1
            x_max(nj,1) = str2double(data_txt(nk+1));
        elseif strcmp(data_txt(nk),'Y_MIN') == 1
            y_min(nj,1) = str2double(data_txt(nk+1));
        elseif strcmp(data_txt(nk),'Y_MAX') == 1
            y_max(nj,1) = str2double(data_txt(nk+1));
        elseif strcmp(data_txt(nk),'CALIBRATION_X') == 1
            calib(nj,1) = str2double(data_txt(nk+1));
        elseif strcmp(data_txt(nk),'X_STAGE') == 1
            stage_x(nj,1) = str2double(data_txt(nk+1));
        elseif strcmp(data_txt(nk),'X_STAGE') == 1
            stage_y(nj,1) = str2double(data_txt(nk+1));            
        elseif strcmp(data_txt(nk),'DELAY_PS') == 1
            delay_img(nj,1) = str2double(data_txt(nk+1));
        elseif strcmp(data_txt(nk),'OFFSET_DELAY_MM') == 1
            delay_offset(nj,1) = str2double(data_txt(nk+1));
        elseif strcmp(data_txt(nk),'DWELL_TIME') == 1
            dwell_time(nj,1) = str2double(data_txt(nk+1));
        elseif strcmp(data_txt(nk),'PIXEL_REP') == 1
            pixel_rep(nj,1) = str2double(data_txt(nk+1));
        elseif strcmp(data_txt(nk),'LAMBDA_TISAF') == 1
            lambda_tisaf(nj,1) = str2double(data_txt(nk+1));
        elseif strcmp(data_txt(nk),'MEASURED_WAVELENGTH_NM') == 1
            OPO_measured_wavelength(nj,1) = str2double(data_txt(nk+1));
        elseif strcmp(data_txt(nk),'SET_WAVELENGTH_NM') == 1
            OPO_set_wavelength(nj,1) = str2double(data_txt(nk+1));
        elseif strcmp(data_txt(nk),'OPO_POWER') == 1
            OPO_power(nj,1) = str2double(data_txt(nk+1));
        end
    end  
end  
clear n nj nk

%% Analyze image acquisition parameters
if max(n_pixel_x) ~= min(n_pixel_x)
    disp('Warning: No of pixels has changed in x direction during the acquisition');
end
%% ---------------------------
if max(n_pixel_y) ~= min(n_pixel_y)
    disp('Warning: No of pixels has changed in y direction during the acquisition');
end
%% ----------------------------
if max(wdth_img) ~= min(wdth_img)
    disp('Warning: Image width has changed during the acquisition');
end
%% ---------------------------
if max(hght_img) ~= min(hght_img)
    disp('Warning: Image height has changed during the acquisition');
end
%% --------------------------
if (max(pol_angle) - min(pol_angle)) >= 1
    disp('Warning: Excitation beam polarization has changed during the acquisition');
end    
%% --------------------------
if (max(pol_offset) - min(pol_offset)) >= 1
    disp('Warning: Polarization offset has changed during the acquisition');
end  
%% --------------------------
if (max(z_pos) - min(z_pos)) >= 0.2
    disp('Warning: Objective height has changed during the acquisition');
end
%% --------------------------
if (max(x_min) - min(x_min)) >= 0.5
    disp('Warning: System zoomed in/out during the acquisition');
end    
%% --------------------------
if (max(x_max) - min(x_max)) >= 0.5
    disp('Warning: System zoomed in/out during the acquisition');
end   
%% --------------------------
if (max(y_min) - min(y_min)) >= 0.5
    disp('Warning: System zoomed in/out during the acquisition');
end    
%% --------------------------
if (max(y_max) - min(y_max)) >= 0.5
    disp('Warning: System zoomed in/out during the acquisition');
end  
%% --------------------------
if (max(stage_x) - min(stage_x)) >= 0.001
    disp('Warning: Stage drifted during the acquisition');
end   
%% --------------------------
if (max(stage_y) - min(stage_y)) >= 0.001
    disp('Warning: Stage drifted during the acquisition');
end    
%% --------------------------
if max(calib) ~= min(calib)
    disp('Warning: Image calibration has changed during the acquisition');
end  
%% --------------------------
if max(delay_offset) ~= min(delay_offset)
    disp('Warning: Delay stage offset has changed during the acquisition');
end  
%% --------------------------
if max(delay_img) ~= min(delay_img)
    disp('Warning: Delay stage has moved during the acquisition');
end
%% --------------------------
if max(lambda_tisaf) ~= min(lambda_tisaf)
    disp('Warning: Ti:sapphire wavelength has changed during the acquisition');
end 
%% --------------------------
if max(OPO_measured_wavelength) ~= min(OPO_measured_wavelength)
    disp('Warning: OPO wavelength has changed during the acquisition');
end 
%% --------------------------
if max(dwell_time) ~= min(dwell_time)
    disp('Warning: Pixel dwell time has changed during the acquisition');
end 
%% --------------------------
if max(pixel_rep) ~= min(pixel_rep)
    disp('Warning: Pixel rep rate has changed during the acquisition');
end 




%% Get all images required for further sorting and analysis
imgs = zeros(n_ch_tot,max(n_pixel_y),max(n_pixel_x),n_files_txt);     % All images in one matrix (Channel No., Y-pixels, X-pixels, Stack)
n_ch = 0;
for ni = n_depart : n_cntnt
    cd([full_dir '/' cntnt(ni).name])
    files_ana = dir('*.ASC');
    files_dig = dir('*.DAT');
    if ~isempty(files_ana)
        n_ch = n_ch + 1;
        files = dir('*.ASC');
        n_files = length(files);
        for nj = 1 : n_files
            fname = files(nj).name;

            % Read file as text
            txt = fileread(fname);
        
            % Replace commas that are between digits with dots (e.g. 51,489 -> 51.489)
            txt_fixed = regexprep(txt, '(?<=\d),(?=\d)', '.');
        
            % Write to temporary file
            tmpname = [fname '_fixed.tmp'];
            fid = fopen(tmpname,'w');
            fwrite(fid, txt_fixed);
            fclose(fid);
        
            % Read numeric data from fixed file
            imgs(n_ch,:,:,nj) = dlmread(tmpname);
        
            % Remove temporary file
            delete(tmpname);
        end
        clear nj
        
    elseif ~isempty(files_dig)
        n_ch = n_ch + 1;
        files = dir('*.DAT');
        n_files = length(files);
        for nj = 1 : n_files
            fid = fopen(files(nj).name, 'r', 'b');
            data = fread(fid,[n_pixel_y(nj), n_pixel_x(nj)],'uint16'); 
            %data = fread(fid,'uint16'); 
            fclose(fid); 
            %imgs_DIG(n_ch,nj,:,:) = reshape(data,n_pixel_y(1),n_pixel_x(1));
            imgs(n_ch,:,:,nj) = data;
        end
    end
end
clear ni nj


%% Plot spectrum 

% à insérer manuellement : 
% pompe = 1030.9 ?
 
% Convert wavenumber to wavenumbers (in cm-1)

%wavenumber = 1e7 ./ wavelengths - 1e7 ./ pompe; % wavenumber in cm-1
 



% Extract and plot the spectrum for the current file
spectrum = zeros(n_files,1);

for nj = 1 : n_files 
    spectrum(nj) = mean(imgs(n_ch,:,:,nj),'all'); % Average over the channel dimension
end 

%spectrum(9) = [] % suppr erreur calcite no chirp 

% spectrum (n_files x 1) and wavelengths defined as in your script
% n_ch is the channel index used when filling imgs

%% Plot spectrum with interactive ROI selection (chatGPT generated)

%%
if contrast == true

    I_raw = squeeze(imgs);
    
    % figure(99); imagesc(); colorbar;

    noise_study(imgs,3,3);
    
    figure(100); imagesc(mean(I_raw,3)); colorbar;
    
    x1_s = 30;
    x1_e = 36;
    x2_s = 48;
    x2_e = 55;
    
    for ii = 1:size(I_raw,3)
        
        % --- estimation du fond (robuste) ---
        ROI = I_raw(x1_s:x1_e, x2_s:x2_e, ii);
        I_bckg(ii) = median(ROI(:));   % mieux que mean
        
        % --- soustraction ---
        I_corr(:,:,ii) = I_raw(:,:,ii) - I_bckg(ii);
        
        % --- (optionnel) petit filtrage spatial ---
        % I_corr(:,:,ii) = medfilt2(I_corr(:,:,ii), [3 3]);
    
    end
    
    
    figure(101); imagesc(sum(I_corr,3)); colorbar;
    %% Contrast - Affichage image SRS
    n1 = 1; 
    n2 = 2;
    n3 = 3;
    n4 = 4;
    n5 = 5;
    I1 = I_corr(:,:,n1); % calcite
    I2 = I_corr(:,:,n2); % fluo 
    I3 = I_corr(:,:,n3); % ACC - H2O
    I4 = I_corr(:,:,n4); % ACChira inf
    I5 = I_corr(:,:,n5); % inf ACC 

    % I1 = I_raw(:,:,n1); % calcite
    % I2 = I_raw(:,:,n2); % fluo 
    % I3 = I_raw(:,:,n3); % ACC - H2O
    % I4 = I_raw(:,:,n4); % ACChira inf
    % I5 = I_raw(:,:,n5); % inf ACC 

    % C=(I1-I2)./(I1+I2);
    C1=(I1-I2);
    C3=(I3-I2);
    C4=(I4-I2);
    C5=(-I5-I2);
    

    % Imax = 200;
    % Imin =-5;

    Imax = 150;
    Imin =-5;

    % figure();
    % subplot(2,2,1);
    % imagesc(I1); caxis([Imin Imax]); colorbar; 
    % title('calcite - 1087 cm^{-1} (I1)');
    % hold on;
    % contour(I1, 3, 'w', 'LineWidth', 1);
    % hold off;
    % 
    % subplot(2,2,3);
    % imagesc(I3); caxis([Imin Imax]); colorbar;
    % title('ACC - 1077 cm^{-1} (I3)');
    % hold on;
    % contour(I1, 3, 'w', 'LineWidth', 1);
    % hold off;
    % 
    % subplot(2,2,2);
    % imagesc(I2); caxis([Imin Imax]); colorbar;
    % title('fluo - 1044 cm^{-1} (I2)');
    % hold on;
    % contour(I1, 3, 'w', 'LineWidth', 1);
    % hold off;
    % 
    % subplot(2,2,4);
    % imagesc(I3-I1); caxis([-3 5]); colorbar;
    % title('soustraction des images ACC et calcite (I3-I1)');
    % hold on;
    % contour(I1, 3, 'w', 'LineWidth', 1);
    % hold off;
    % 
    % sgtitle('Images SRS d''un coccolithophore à différentes longueurs d''onde', 'FontSize', 12, 'FontWeight', 'bold');    

    figure();
    subplot(2,3,1);
    imagesc(I1); caxis([Imin 160]); colorbar;
    title('calcite (I1)');
    hold on;
    contour(I1, 3, 'w', 'LineWidth', 1);
    hold off;


    subplot(2,3,2);
    imagesc(I2); caxis([Imin Imax]); colorbar;
    title('fluo (I2)');
    hold on;
    contour(I1, 3, 'w', 'LineWidth', 1);
    hold off;

    subplot(2,3,3);
    imagesc(I2-I1); caxis([-50 7]); colorbar;
    title('I2-I1');
    hold on;
    contour(I1, 3, 'w', 'LineWidth', 1);
    hold off;

    subplot(2,3,4);
    imagesc(I3-I1); caxis([-3 5]); colorbar;
    title('I_{1077}-I_{1087}');
    hold on;
    contour(I1, 3, 'w', 'LineWidth', 1);
    hold off;

    subplot(2,3,5);
    imagesc(I3-I1); caxis([-50 7]); colorbar;
    title('I3-I1');
    hold on;
    contour(I1, 3, 'w', 'LineWidth', 1);
    hold off;

    subplot(2,3,6);
    imagesc(I5-I1); caxis([-50 7]); colorbar;
    title('I5-I1');
    hold on;
    contour(I1, 3, 'w', 'LineWidth', 1);
    hold off;


    sgtitle('Images SRS ', 'FontSize', 12, 'FontWeight', 'bold');

    figure();
    subplot(2,3,1);
    imagesc(I1); caxis([Imin Imax]); colorbar; 
    title('calcite - 1087 cm^{-1}');
    hold on;
    contour(I1, 3, 'w', 'LineWidth', 1);
    hold off;

    subplot(2,3,3);
    imagesc(I3); caxis([Imin Imax]); colorbar;
    title('potentiel ACC - 1077 cm^{-1}');
    hold on;
    contour(I1, 3, 'w', 'LineWidth', 1);
    hold off;

    subplot(2,3,2);
    imagesc(I2); caxis([Imin Imax]); colorbar;
    title('fluo - 1044 cm^{-1}');
    hold on;
    contour(I1, 3, 'w', 'LineWidth', 1);
    hold off;

    subplot(2,3,4);
    imagesc(I4); caxis([Imin Imax]); colorbar;
    title('potentiel ACC - 1066 cm^{-1}');
    hold on;
    contour(I1, 3, 'w', 'LineWidth', 1);
    hold off;

    subplot(2,3,5);
    imagesc(I5); caxis([Imin Imax]); colorbar;
    title('inf ACC - 1060 cm^{-1}');
    hold on;
    contour(I1, 3, 'w', 'LineWidth', 1);
    hold off;


    sgtitle('Images SRS d''un coccolithophore à différents nombre d''onde', 'FontSize', 12, 'FontWeight', 'bold');

    [roi_sig_coords_ACC, data_sorted_ACC] = intensityprofile(I_corr, wavenumber, 2, 5, 5, 0,90,3,5 );
    [roi_sig_coords_cal, data_sorted_cal] = intensityprofile(I_corr, wavenumber, 1, 5,5,33,72,5,6);
    
    figure;
    yyaxis left; % Échelle de gauche pour le premier plot
    plot(data_sorted_cal(:,1), data_sorted_cal(:,2), '-o', 'LineWidth', 1.5);
    ylabel('Intensity (a.u.) - Calcite region','FontSize', 16);
    
    yyaxis right; % Échelle de droite pour le second plot
    plot(data_sorted_ACC(:,1), data_sorted_ACC(:,2), '-x', 'LineWidth', 1.5);
    ylabel('Intensity (a.u.) - potential ACC region','FontSize', 16);
    
    xlabel('Wavenumber (cm^{-1})','FontSize', 16);
    title('Intensity profiles of two different region of the coccolithophore','FontSize', 18);
    grid on;

    % subplot(3,3,1);
    % imagesc(I1); caxis([-1 200]); colorbar;
    % title('calcite (I1)');
    % hold on;
    % contour(I1, 3, 'w', 'LineWidth', 1);
    % hold off;
    % 
    % subplot(3,3,2);
    % imagesc(I3); caxis([-5 80]); colorbar;
    % title('ACC-H2O (I3)');
    % hold on;
    % contour(I1, 3, 'w', 'LineWidth', 1);
    % hold off;
    % 
    % subplot(3,3,3);
    % imagesc(I4); caxis([-5 80]); colorbar;
    % title('ACChira inf (I4)');
    % hold on;
    % contour(I1, 3, 'w', 'LineWidth', 1);
    % hold off;
    % 
    % subplot(3,3,4);
    % imagesc(I2); caxis([-5 80]); colorbar;
    % title('fluo (I2)');
    % hold on;
    % contour(I1, 3, 'w', 'LineWidth', 1);
    % hold off;
    % 
    % subplot(3,3,5);
    % imagesc(I2-I1); caxis([-3 5]); colorbar;
    % title('I2-I1');
    % hold on;
    % contour(I1, 3, 'w', 'LineWidth', 1);
    % hold off;
    % 
    % subplot(3,3,6);
    % imagesc(I3-I2); caxis([-3 40]); colorbar;
    % title('I3-I2');
    % hold on;
    % contour(I1, 3, 'w', 'LineWidth', 1);
    % hold off;
    % 
    % subplot(3,3,7);
    % imagesc(I5); caxis([-5 80]); colorbar;
    % title('inf ACC (I5)');
    % hold on;
    % contour(I1, 3, 'w', 'LineWidth', 1);
    % hold off;
    % 
    % subplot(3,3,8);
    % imagesc((I3-I1)); caxis([-3 5]); colorbar;
    % title('I3-I1');
    % hold on;
    % contour(I1, 3, 'w', 'LineWidth', 1);
    % hold off;
    % 
    % subplot(3,3,9);
    % imagesc(I2-I3); caxis([-3 5]); colorbar;
    % title('I2-I3');
    % hold on;
    % contour(I1, 3, 'w', 'LineWidth', 1);
    % hold off;


    % [mask_calcite, mask_acc] = detect_calcite_acc_mistral(squeeze(imgs),wavenumber,2);
    % 
    % figure(103);
    % subplot(1,2,1); imagesc(mask_calcite); title('Calcite');
    % subplot(1,2,2); imagesc(mask_acc); title('ACC');

    % intensityprofile(imgs,[],2);
    % intensityprofile(imgs,wavenumber,3);

    %% Correction shift 


    % shift déterminer à l'oeil  (-1,-1)
    % I1sc = I1; % calcite
    % I2sc = correct_xy_shift(I2,-1,-1); % fluo 
    % I3sc = correct_xy_shift(I3,-1,-1); % ACC H2O 
    % I4sc = correct_xy_shift(I4,-1,-1); % ACC Chira
    % I5sc = correct_xy_shift(I5,-1,-1); % fluo 2

    I1sc = I1; % calcite
    I2sc = correct_xy_shift(I2,-1,-1); % fluo 
    I3sc = correct_xy_shift(I3,-1,-1); % ACC H2O 
    I4sc = correct_xy_shift(I4,-1,-1); % ACC Chira
    I5sc = correct_xy_shift(I5,-1,-1); % fluo 2

    imgsc(:,:,1) = I1sc;
    imgsc(:,:,2) = I2sc;
    imgsc(:,:,3) = I3sc;
    imgsc(:,:,4) = I4sc;
    imgsc(:,:,5) = I5sc;

    imgsc_no_cal(:,:,1) = I2sc;
    imgsc_no_cal(:,:,2) = I3sc;
    imgsc_no_cal(:,:,3) = I4sc;
    imgsc_no_cal(:,:,4) = I5sc;

    % shift déterminer par cross corrélation :
    % [dx_f, dy_f] = find_shift_fft_norm(I1, I2)
    % [dx_acc, dy_acc] = find_shift_fft_norm(I1, I3)
    % [dx_acchira, dy_acchiara] = find_shift_fft_norm(I1, I4)
    % [dx_f2, dy_f2] = find_shift_fft_norm(I1, I5)
    % 
    % I1sc = I1; % calcite
    % I2sc = correct_xy_shift(I2,-dx_f,-dy_f); % fluo 
    % I3sc = correct_xy_shift(I3,-dx_acc,-dy_acc); % ACC H2O 
    % I4sc = correct_xy_shift(I4,-dx_acchira,-dy_acchiara); % ACC Chira
    % I5sc = correct_xy_shift(I5,-dx_f2,-dy_f2); % fluo 2
    


    %% Correction Fluo 

    % MAP PARAMETRE FIT FLUO
    % Dossier principal de sauvegarde (à adapter selon votre structure)
    % main_dir = pwd;  % Récupère le répertoire courant (remplacez par votre chemin absolu si nécessaire)
    maps_dir = fullfile(main_dir, 'fluo_maps_no_shift');  % Dossier dédié aux maps
    
    % Créer le dossier s'il n'existe pas
    if ~exist(maps_dir, 'dir')
        mkdir(maps_dir);
        disp(['Dossier créé : ' maps_dir]);
    end
    
    % --- Noms des fichiers ---
    filename_A = fullfile(maps_dir, 'A_map.mat');
    filename_tau = fullfile(maps_dir, 'tau_map.mat');
    filename_C = fullfile(maps_dir, 'C_map.mat');
    filename_Imean = fullfile(maps_dir, 'Imean_map.mat');
    filename_R2 = fullfile(maps_dir, 'R2_map.mat');
    
    % --- Vérification et chargement/calcul des maps ---
    if exist(filename_A, 'file') && exist(filename_tau, 'file') && ...
       exist(filename_C, 'file') && exist(filename_Imean, 'file') && exist(filename_R2, 'file')
        % Charger les maps existantes
        fprintf('Chargement des maps depuis %s...\n', maps_dir);
        load(filename_A, 'A_map');
        load(filename_tau, 'tau_map');
        load(filename_C, 'C_map');
        load(filename_Imean, 'Imean_map');
        load(filename_R2, 'R2_map');
        disp('Maps chargées avec succès.');
    else
        % Calculer les maps
        fprintf('Calcul des maps en cours...\n');
        [A_map, tau_map, C_map, Imean_map, R2_map] = extract_map_fluo(squeeze(imgs));
    
        % Enregistrer les maps
        fprintf('Enregistrement des maps dans %s...\n', maps_dir);
        save(filename_A, 'A_map');
        save(filename_tau, 'tau_map');
        save(filename_C, 'C_map');
        save(filename_Imean, 'Imean_map');
        save(filename_R2, 'R2_map');
        disp('Maps calculées et enregistrées.');
    end

    mask_good_fit = analyze_map_fluo(A_map, tau_map, C_map, Imean_map, R2_map,0.99,I1);




    %% Affichage images SRS shift corrigé
    seuil_R2=1;
    figure(); clf;

    subplot(2,3,1);
    imagesc(I1sc); caxis([Imin 160]); colorbar;
    title('calcite (I1)');
    hold on;
    contour(I1sc, 3, 'w', 'LineWidth', 1);
        % Superposition des pixels avec R² > seuil_R2
    [rows, cols] = find(R2_map > seuil_R2);
    scatter(cols, rows, 10, 'r', 'filled', 'MarkerFaceAlpha', 0.5, 'MarkerEdgeAlpha', 0.5);
    hold off;
    
    subplot(2,3,3);
    imagesc(I3sc); caxis([Imin Imax]); colorbar;
    title('ACC-H₂O (I3)');
    hold on;
    contour(I1sc, 3, 'w', 'LineWidth', 1);
        % Superposition des pixels avec R² > seuil_R2
    [rows, cols] = find(R2_map > seuil_R2);
    scatter(cols, rows, 10, 'r', 'filled', 'MarkerFaceAlpha', 0.5, 'MarkerEdgeAlpha', 0.5);
    hold off;

    subplot(2,3,2);
    imagesc(I2sc); caxis([Imin Imax]); colorbar;
    title('fluo (I2)');
    hold on;
    contour(I1sc, 3, 'w', 'LineWidth', 1);
        % Superposition des pixels avec R² > seuil_R2
    [rows, cols] = find(R2_map > seuil_R2);
    scatter(cols, rows, 10, 'r', 'filled', 'MarkerFaceAlpha', 0.5, 'MarkerEdgeAlpha', 0.5);
    hold off;

    subplot(2,3,4);
    imagesc(I4sc); caxis([Imin Imax]); colorbar;
    title('ACChira (I4)');
    hold on;
    contour(I1sc, 3, 'w', 'LineWidth', 1);
        % Superposition des pixels avec R² > seuil_R2
    [rows, cols] = find(R2_map > seuil_R2);
    scatter(cols, rows, 10, 'r', 'filled', 'MarkerFaceAlpha', 0.5, 'MarkerEdgeAlpha', 0.5);
    hold off;

        subplot(2,3,5);
    imagesc(I3sc./I1sc); caxis([0.5 1.5]); colorbar;
    title('I3/I1');
    hold on;
    contour(I1, 3, 'w', 'LineWidth', 1);
        % Superposition des pixels avec R² > seuil_R2
    [rows, cols] = find(R2_map > seuil_R2);
    scatter(cols, rows, 10, 'r', 'filled', 'MarkerFaceAlpha', 0.5, 'MarkerEdgeAlpha', 0.5);
    hold off;

    subplot(2,3,6);
    imagesc(I3sc-I1sc); caxis([-5 5]); colorbar;
    title('I3-I1');
    hold on;
    contour(I1, 3, 'w', 'LineWidth', 1);
    hold off;

    sgtitle('Images SRS (shift corrigé)', 'FontSize', 12, 'FontWeight', 'bold');
    %% déterminer coef atténuation à la main 
    % I3_corr_fluo = I3 - 0.6*I2;
    % figure(40);
    % subplot(2,2,1);
    % imagesc(I3);caxis([-1 40]); colorbar;
    % subplot(2,2,2);
    % imagesc(I2);caxis([-1 40]); colorbar;
    % subplot(2,2,3);
    % imagesc(I3_corr_fluo);caxis([-1 40]); colorbar;
    % subplot(2,2,4);
    % imagesc(I3_corr_fluo);caxis([-1 40]); colorbar;

    %% Déterminer les paramètres de fit pour la correction fluo 

    % Fit la moyenne des pixels d'un ROI 
    % [A_exp,tau_exp,Imean,Cst] = extract_fluo_cst(imgs, n2,10,10,84,84,4,4); %fluo centre
    

    %fit chaque pixel du ROI respectant les conditions sur R2 et A. On
    %prend la moyenne des paramètres des fits. 
    % x1_ROI = 60;
    % y1_ROI = 65;
    % x2_ROI = 77;
    % y2_ROI = 77; 

    x1_ROI = 50;
    y1_ROI = 50;
    x2_ROI = 80;
    y2_ROI = 80; 

    A_seuil = 2000; % filtre les valeurs aberrantes 
    tau_seuil = 2;
    R2_seuil=0.9; % filtre les fits de mauvaise qualité 

    count = 0; % nombre de fit sélectionné 
    ttau_best = zeros(y2_ROI-y1_ROI+1,x2_ROI-x1_ROI+1);
    tA_best = zeros(y2_ROI-y1_ROI+1,x2_ROI-x1_ROI+1);
    tC_best = zeros(y2_ROI-y1_ROI+1,x2_ROI-x1_ROI+1); 
    
    % figure();


    for i = y1_ROI:y2_ROI
        for j = x1_ROI:x2_ROI
            if R2_map(i,j)>R2_seuil 
                if A_map(i,j)<A_seuil 
                    if tau_map(i,j)<tau_seuil 
                    
                        count = count + 1;
                        tA_best(i,j) = A_map(i,j);
                        ttau_best(i,j) = tau_map(i,j);
                        tC_best(i,j) = C_map(i,j);
    
                        % for tt=1:size(wavenumber)
                        %     scatter()
                    end
                end

            end
       
        end
    end

    A_best = sum(tA_best(:)) / count;
    tau_best = sum(ttau_best(:))/count;
    C_best = sum(tC_best(:))/count ;
    count;

    fprintf('  A_best = %.3g\n', A_best);
    fprintf('  tau_best = %.3g\n', tau_best);
    fprintf('  C_best = %.3g\n', C_best);
    fprintf('  N_sample = %.3g\n', count);

    [A_exp,tau_exp,Imean,Cst] = extract_fluo_cst(imgs, n2,5,5,50,50,30,30);
    disp('Fit parameters extract from ROI :')
    fprintf('  A_ROI = %.3g\n', A_exp);
    fprintf('  tau_ROI = %.3g\n', tau_exp);
    fprintf('  C_ROI = %.3g\n', Cst);

    %% histogrammes 
    
    tA_best_nozeros = tA_best(tA_best~=0);
    ttau_best_nozeros = ttau_best(ttau_best~=0);
    tC_best_nozeros = tC_best(tC_best~=0);

    

    figure();
    
    params = {tA_best_nozeros(:), 'A'; ttau_best_nozeros(:), 'tau'; tC_best_nozeros(:), 'C'};

    p_fit = zeros(3,3);
    
    for i = 1:3
        data = params{i,1};
        name = params{i,2};

        median_val = median(data);
        iqr_val = iqr(data);
        
        fprintf('%s:\n', name);
        fprintf('  mean = %.3g\n', mean(data));
        fprintf('  std = %.3g\n', std(data));
        fprintf('  median = %.3g\n', median_val);
        fprintf('  IQR = %.3g\n', iqr_val);
    
        subplot(3,1,i);
    
        % histogram normalisé
        h = histogram(data, 300);
        hold on;
    
        % centres des bins
        bin_centers = (h.BinEdges(1:end-1) + h.BinEdges(2:end))/2;
        y = h.Values;
    
        % modèle gaussien
        gauss = @(p,x) p(1)*exp(-(x-p(2)).^2/(2*p(3)^2));
        % p = [amplitude, mean, sigma]
    
        % guess initial
        mu0 = mean(data);
        sigma0 = std(data);
        A0 = max(y);
    
        p0 = [A0, mu0, sigma0];
    
        % fit
        p_fit(i,:) = lsqcurvefit(gauss, p0, bin_centers, y);
    
        % affichage fit
        x_fit = linspace(min(data), max(data), 500);
        y_fit = gauss(p_fit(i,:), x_fit);
        plot(x_fit, y_fit, 'r', 'LineWidth', 2);
    
        % stats
        mu = p_fit(i,2);
        sigma = abs(p_fit(i,3));
    
        title(sprintf('%s | mu=%.3g, sigma=%.3g', name, mu, sigma));
        xlabel(name);
        ylabel('fréquence');
    
        hold off;
    end


    figure()
    scatter(tA_best(:), ttau_best(:), '.');
    xlabel('A');
    ylabel('tau');
    title('Corrélation A - tau');

    % figure;
    % subplot(3,1,1);
    % A_hist = histogram(tA_best(:), 300);
    % title('Histogramme de A');
    % xlabel('A');
    % ylabel('Fréquence');
    % 
    % subplot(3,1,2);
    % tau_hist = histogram(ttau_best(:), 300);
    % title('Histogramme de tau');
    % xlabel('tau');
    % ylabel('Fréquence');
    % 
    % subplot(3,1,3);
    % C_hist = histogram(tC_best(:), 300);
    % title('Histogramme de C');
    % xlabel('C');
    % ylabel('Fréquence');



%% Affichage images SRS fluo corrigé 

    % imgs_fluo_corrA = correctfluo_intensityprofile_virginieA(imgsc,n2,p_fit(1,2),p_fit(2,2),p_fit(3,2));
    % imgs_fluo_corrA = correctfluo_intensityprofile_virginieA(imgs,n2,A_best,tau_best,C_best);
    imgs_fluo_corrA = correctfluo_julien(imgsc,p_fit(i,2));


    I1fcA = imgs_fluo_corrA(:,:,n1); % calcite
    I2fcA = imgs_fluo_corrA(:,:,n2); % fluo 
    I3fcA = imgs_fluo_corrA(:,:,n3); % ACC - H2O
    I4fcA = imgs_fluo_corrA(:,:,n4); % ACChira inf
    I5fcA = imgs_fluo_corrA(:,:,n5); % inf ACC 

    figure();

    
    subplot(2,3,1);
    imagesc(I1fcA); caxis([Imin 160]); colorbar;
    title('calcite (I1)');
    hold on;
    contour(I1, 3, 'w', 'LineWidth', 1);
    hold off;

    subplot(2,3,2);
    imagesc(I2fcA); caxis([Imin Imax]); colorbar;
    title('fluo (I2)');
    hold on;
    contour(I1, 3, 'w', 'LineWidth', 1);
    hold off;


    subplot(2,3,3);
    imagesc(I2fcA-I1fcA); caxis([-50 7]); colorbar;
    title('I2-I1');    
    hold on;
    contour(I1, 3, 'w', 'LineWidth', 1);
    hold off;

    subplot(2,3,6);
    imagesc(I5fcA-I1fcA); caxis([-50 7]); colorbar;
    title('I5-I1');
    hold on;
    contour(I1, 3, 'w', 'LineWidth', 1);
    hold off;

    subplot(2,3,4);
    imagesc(I3fcA-I1fcA); caxis([-3 5]); colorbar;
    title('I3-I1');
    hold on;
    contour(I1, 3, 'w', 'LineWidth', 1);
    hold off;

    subplot(2,3,5);
    imagesc(I3fcA-I1fcA); caxis([-50 7]); colorbar;
    title('I3-I1');
    hold on;
    contour(I1, 3, 'w', 'LineWidth', 1);
    hold off;
    sgtitle('Images SRS (shift et fluo corrigé)', 'FontSize', 12, 'FontWeight', 'bold');

    %% caractérisation acteur d'atténuation 
    attenuation_factor(imgsc,2);
    
    %% Profil intensité 
    

    % [ROI_sig_coord_corrA,corr_IprofileA] = intensityprofile(imgs_fluo_corrA,wavenumber,3,10,10,103,92,3,4);% ROI ACC
    % [ROI_sig_coord,Iprofile] = intensityprofile(I_corr,wavenumber,3,10,10,103,92,3,4); % n_ACC,x_ROI_bckg,y_roi_bckg,x_ROI_signal,y_ROI_signal,w_ROI_signal,h_ROI_signal

    % [ROI_sig_coord_corrA,corr_IprofileA] = intensityprofile(imgs_fluo_corrA,wavenumber,3,10,10,64,70,50,50);% ROI fluo
    % [ROI_sig_coord,Iprofile] = intensityprofile(I_corr,wavenumber,3,10,10,64,70,50,50);
    % 
    % figure(109)
    % % plot(corr_Iprofile(:,1),corr_Iprofile(:,2),'-o','LineWidth',1.5,'color','b')
    % hold on 
    % plot(corr_IprofileA(:,1),corr_IprofileA(:,2),'-o','LineWidth',1.5,'color','r')
    % hold on
    % plot(Iprofile(:,1),Iprofile(:,2),'-x','LineWidth',1.5,'color','k')
    % hold on 
    % % plot(Iprofile(:,1),Iprofile(:,2)-corr_Iprofile(:,2),'--','LineWidth',1.5,'color','b');
    % hold on 
    % plot(Iprofile(:,1),Iprofile(:,2)-corr_IprofileA(:,2),'-.','LineWidth',1.5,'color','r');
    % xlabel('wavenumber cm-1')
    % ylabel('intensity')
    % grid on
    % 
    % legend('correction fluo', 'Profil original','[original] - [correction fluo]', 'Location', 'best');
    %% Fit spectrum and extract FWHM
    
    %% Simple multi-peak detection and Gaussian fitting
        
    if find_peaks == true 

        % --- Clean data ---
        valid = isfinite(spectrum_corr) & isfinite(wavenumber(:));
        wn = wavenumber(valid);
        sp = spectrum_corr(valid);
        
        % Sort once and for all (CRITICAL)
        [wn, idx] = sort(wn);
        sp = sp(idx);
        
        % --- Peak detection ---
        [pks, locs, widths] = findpeaks(sp, wn, ...
            'MinPeakProminence', 0.05*max(sp), ...
            'MinPeakDistance', 0.5);
        
        n_peaks = numel(pks);
        fprintf('Number of detected peaks: %d\n', n_peaks);
        
        % --- Display raw spectrum ---
        figure;
        plot(wn, sp, 'k.'); hold on;
        
        % --- Gaussian + offset model ---
        gauss_offset = fittype('a*exp(-((x-b)/c)^2) + d', ...
            'independent','x', ...
            'coefficients',{'a','b','c','d'});
        
        % Storage
        lambda0   = nan(n_peaks,1);
        FWHM_fit  = nan(n_peaks,1);
        amplitude = nan(n_peaks,1);
        offset    = nan(n_peaks,1);
        
        for k = 1:n_peaks
        
            % --- Local fitting window ---
            win = 1.5 * widths(k);
            idx_fit = wn > locs(k)-win & wn < locs(k)+win;
        
            if sum(idx_fit) < 5
                continue
            end
        
            xfit = wn(idx_fit);  xfit = xfit(:);
            yfit = sp(idx_fit);  yfit = yfit(:);
        
            % --- Robust baseline estimate ---
            y_sorted = sort(yfit);
            n_base = max(2, round(0.2*numel(y_sorted)));
            baseline_est = mean(y_sorted(1:n_base));
        
            % --- Fit options ---
            opts = fitoptions(gauss_offset);
            opts.StartPoint = [ ...
                max(yfit)-baseline_est, ... % amplitude
                locs(k), ...                % center
                widths(k)/2, ...            % width
                baseline_est ];             % offset
        
            opts.Lower = [0, min(xfit), 0, 0];
            opts.Upper = [Inf, max(xfit), Inf, max(yfit)];
        
            % --- Fit ---
            ft = fit(xfit, yfit, gauss_offset, opts);
        
            % --- Extract parameters ---
            a = ft.a;
            b = ft.b;
            c = abs(ft.c);
            d = ft.d;
        
            lambda0(k)  = b;
            amplitude(k)= a;
            offset(k)   = d;
        
            FWHM_fit(k) = 2*sqrt(log(2))*c;
        
            % --- Plot fit ---
            xx = linspace(min(xfit), max(xfit), 300);
            plot(xx, ft(xx), 'LineWidth', 1.5);
        
            % --- Plot FWHM ---
            y_half = d + a/2;
            plot([b-FWHM_fit(k)/2, b+FWHM_fit(k)/2], ...
                 [y_half y_half], 'r-', 'LineWidth', 2);
        
            % --- Peak marker ---
            plot(b, d+a, 'rv', 'MarkerFaceColor','r');
        
            % --- Text annotation (stacked) ---
            ypos = 0.85 - 0.12*(k-1);
            txt = sprintf('\\lambda_0 = %.2f\nFWHM = %.2f', b, FWHM_fit(k));
        
            annotation('textbox', [0.65 ypos 0.25 0.10], ...
                'String', txt, ...
                'FitBoxToText','on', ...
                'BackgroundColor','w', ...
                'EdgeColor','k', ...
                'FontSize', 10);
        end
        
        xlabel('Wavenumber (cm^{-1})');
        ylabel('Intensity (a.u.)');
        title(sprintf('spectre – %s', title_fig));
        grid on;

    end
end

%% Save mat files 
cd(main_dir);
if exist(sub_dir_save) == 0
    mkdir(sub_dir_save)
end
for ni = 1 : n_ch_tot
    imgs_stack = squeeze(imgs(ni,:,:,:));
%     figure; imagesc(linspace(y_min(1),y_max(1),n_pixel_y(1)),linspace(x_min(1),x_max(1),n_pixel_x(1)),mean(imgs_stack,3));
%     axis image; colorbar; title(cntnt(ni+2).name); xlabel('\mum'); ylabel('\mum');
    save([sub_dir_save '/' sub_dir cntnt(ni+n_depart-1).name],'main_dir','sub_dir','n_ch_ana','n_ch_dig','n_files_txt','n_pixel_x','n_pixel_y',...
         'wdth_img','hght_img','pol_angle','pol_offset','z_pos','x_min','x_max','y_min','y_max','calib','stage_x','stage_y',...
         'delay_offset','delay_img','dwell_time','pixel_rep','lambda_tisaf','OPO_measured_wavelength','OPO_set_wavelength',...
         'OPO_power','imgs_stack');  
end

%% Save spectra

% Dossier de sauvegarde des figures de fit
fit_fig_dir = [sub_dir_save '/spectra_fit_figures/'];

if exist(fit_fig_dir,'dir') == 0
    mkdir(fit_fig_dir)
end

% Récupérer la figure courante
hFig = gcf;

% Nom du fichier
fname_fig = [fit_fig_dir 'spectrum_fit_channel_' num2str(n_ch) '.png'];

% Sauvegarde haute résolution
exportgraphics(hFig, fname_fig, 'Resolution', 300);

disp(['Figure de fit sauvegardée : ' fname_fig]);

