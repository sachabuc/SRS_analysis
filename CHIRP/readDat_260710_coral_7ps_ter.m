%% Variables needed for running the code on its own
clear all;
close all;
%n_pixel_y = 100; n_pixel_x = 100;

addpath('C:\Users\sacha.bucourt\Documents\MATLAB\MesFonctions')
addpath('C:\Users\sacha.bucourt\Documents\MATLAB\fonctions_banque_spectre')


%% A COMPLETER : 
% chemin vers dossier dans lequel se trouve le dossier ANA (data SRS) : 
main_dir = 'C:\Users\sacha.bucourt\Documents\Data lab\CHIRP\260710\16-33-10_coral_7ps_ter'

sub_dir  = '';
sub_dir_save = [main_dir '/extracted_data/' sub_dir];

title_fig = 'ACC + cal - no chirp : 2 ps';

wavelengths =[927.2,928,928.3,928.6,929,929.4,926.9,926.5,926,927.6];

pompe = 1031;

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

%% Correction du bruit  

[I_corr,SNR,sigma_spec] = remove_planar_background(imgs,10:15,10:15,true,1);

% I_raw = squeeze(imgs);
% 
% % noise_study(imgs,3,3);
% % figure(99); imagesc(); colorbar;
% 
% figure(100); imagesc(sum(I_raw,3)); colorbar;
% x1_s = 10;
% x1_e = 15;
% x2_s = 10;
% x2_e = 15;
% for ii = 1:size(I_raw,3)
% 
%     % estimation du fond
%     ROI = I_raw(x1_s:x1_e, x2_s:x2_e, ii);
%     I_bckg(ii) = median(ROI(:));   % mieux que mean
% 
%     % soustraction
%     I_corr(:,:,ii) = I_raw(:,:,ii) - I_bckg(ii);
% 
%     % (optionnel)filtrage spatial 
%     % I_corr(:,:,ii) = medfilt2(I_corr(:,:,ii), [3 3]);
% 
% end

%% Map
% figure(101); imagesc(sum(I_corr,3)); colorbar;
%Afficher images SRS 
n1 = 2; 
n2 = 1;
n3 = 10;
% n4 = 3; 
% n5 = 5;
I1 = I_corr(:,:,n1); % ACC Chira
I2 = I_corr(:,:,n2); % Cal 1
I3 = I_corr(:,:,n3); % Cal 2
% I4 = I_corr(:,:,n4); % ACC 
% I5 = I_corr(:,:,n5); % fluo 2

figure(102); clf;
Imax = 10;
Imin= -10;

subplot(2,3,1);
imagesc(I1); caxis([Imin Imax]); colorbar;
title('ACC - 1077 (I1)');


subplot(2,3,2);
imagesc(I2); caxis([Imin Imax]); colorbar;
title('Cal 1 - 1086 (I2)');


subplot(2,3,3);
imagesc(I3); caxis([Imin Imax]); colorbar;
title('Cal 2 - 1081 (I3)');
hold on;


subplot(2,3,4);
imagesc(I1-I2); caxis([-5 5]); colorbar;
title('I1-I2');


 subplot(2,3,5);
imagesc(I1-I3); caxis([-2 2]); colorbar;
title('I1-I3');

subplot(2,3,6);
imagesc(I2-I3); caxis([-2 2]); colorbar;
title('I2-I3');   

sgtitle('Map ACC + Calcite', 'FontSize', 12, 'FontWeight', 'bold');

% Image utilisée pour définir les ROI
I_raw = squeeze(imgs);

figure('Name','Sélection ROI','NumberTitle','off');
imagesc(I3);
caxis([-20 15]);
axis image;
colormap parula;
colorbar;

%% spectres 

ROI_known = true; 


if ROI_known == true 

    % load('C:\Users\sacha.bucourt\Documents\Data lab\CHIRP\260710\15-15-20_coral_2ps_ter\extracted_data\mat_data\calcite_I3bis_channel_1')
    % [shift_x, shift_y, I_ref_crop, I_crop, I_diff]= find_shift_fft_norm(I3bis,I3);
    % fprintf('shift_x = %d ,shift_y = %d',shift_x,shift_y);

    shift_x = 12 ;
    shift_y = 3 ;

        % Image utilisée pour définir les ROI
    I_raw = squeeze(imgs);
    figure('Name','Sélection ROI','NumberTitle','off');
    imagesc(I3); caxis([-10 15]); colorbar;
    axis image;
    colormap parula;
    colorbar;

    % -------- Coordonnées du ROI BACKGROUND (à modifier) --------
x_bg=1.431020e+01; y_bg=2.103116e+01; width_bg=5.524079e+00; height_bg=4.787535e+00;
x_sig1=4.963919e+01; y_sig1=1.026220e+02; width_sig1=2.756044e+00; height_sig1=2.816934e+00;
x_sig2=9.201558e+01; y_sig2=5.270255e+01; width_sig2=3.130312e+00; height_sig2=3.314448e+00;



    x_bg = x_bg + shift_x;
    y_bg = y_bg + shift_y;

    % Créer le masque BACKGROUND
    mask_bg = false(size(I3, 1), size(I3, 2));
    mask_bg(floor(y_bg):floor(y_bg)+height_bg-1, floor(x_bg):floor(x_bg)+width_bg-1) = true;
    pos_bg = [x_bg, y_bg, width_bg, height_bg];

    % Afficher le rectangle BACKGROUND
    rectangle('Position', pos_bg, 'EdgeColor', 'b', 'LineWidth', 2);

    fprintf('ROI BACKGROUND : x=%d, y=%d, largeur=%d, hauteur=%d\n', ...
            pos_bg(1), pos_bg(2), pos_bg(3), pos_bg(4));

    % -------- Coordonnées du ROI SIGNAL 1 (à modifier) --------


    x_sig1 = x_sig1 + shift_x;
    y_sig1 = y_sig1 + shift_y;

    % Créer le masque SIGNAL
    mask_sig1 = false(size(I3, 1), size(I3, 2));
    mask_sig1(floor(y_sig1):floor(y_sig1)+height_sig1-1, floor(x_sig1):floor(x_sig1)+width_sig1-1) = true;
    pos_sig1 = [x_sig1, y_sig1, width_sig1, height_sig1];

    % Afficher le rectangle SIGNAL
    rectangle('Position', pos_sig1, 'EdgeColor', 'r', 'LineWidth', 2);

    fprintf('ROI SIGNAL : x=%d, y=%d, largeur=%d, hauteur=%d\n', ...
            pos_sig1(1), pos_sig1(2), pos_sig1(3), pos_sig1(4));

        % -------- Coordonnées du ROI SIGNAL 2 (à modifier) --------


    x_sig2 = x_sig2 + shift_x;
    y_sig2 = y_sig2 + shift_y;

    % Créer le masque SIGNAL
    mask_sig2 = false(size(I3, 1), size(I3, 2));
    mask_sig2(floor(y_sig2):floor(y_sig2)+height_sig2-1, floor(x_sig2):floor(x_sig2)+width_sig2-1) = true;
    pos_sig2 = [x_sig2, y_sig2, width_sig2, height_sig2];

    % Afficher le rectangle SIGNAL
    rectangle('Position', pos_sig2, 'EdgeColor', 'r', 'LineWidth', 2);

    fprintf('ROI SIGNAL : x=%d, y=%d, largeur=%d, hauteur=%d\n', ...
            pos_sig2(1), pos_sig2(2), pos_sig2(3), pos_sig2(4));

else 
    %% -------- ROI BACKGROUND --------
    title('1) Sélectionnez le ROI BACKGROUND puis double-clic');

    roi_bg = drawrectangle('Color','b');
    wait(roi_bg);
    mask_bg = createMask(roi_bg);

    %% -------- ROI SIGNAL 1 --------
    title('2) Sélectionnez le ROI SIGNAL 1 puis double-clic');

    roi_sig1 = drawrectangle('Color','r');
    wait(roi_sig1);
    mask_sig1 = createMask(roi_sig1);

    %% -------- ROI SIGNAL 2 --------
    title('3) Sélectionnez le ROI SIGNAL 2 puis double-clic');

    roi_sig2 = drawrectangle('Color','g');
    wait(roi_sig2);
    mask_sig2 = createMask(roi_sig2);

    %% -------- Affichage positions --------

    pos_bg = roi_bg.Position;
    fprintf('x_bg=%d; y_bg=%d; width_bg=%d; height_bg=%d;\n', ...
            round(pos_bg(1)), round(pos_bg(2)), ...
            round(pos_bg(3)), round(pos_bg(4)));

    pos_sig1 = roi_sig1.Position;
    fprintf('x_sig1=%d; y_sig1=%d; width_sig1=%d; height_sig1=%d;\n', ...
            round(pos_sig1(1)), round(pos_sig1(2)), ...
            round(pos_sig1(3)), round(pos_sig1(4)));

    pos_sig2 = roi_sig2.Position;
    fprintf('x_sig2=%d; y_sig2=%d; width_sig2=%d; height_sig2=%d;\n', ...
            round(pos_sig2(1)), round(pos_sig2(2)), ...
            round(pos_sig2(3)), round(pos_sig2(4)));
end

%% -------- Extraction des spectres --------

n_files = size(imgs,4);

spectrum_bg   = zeros(n_files,1);
spectrum_sig1 = zeros(n_files,1);
spectrum_sig2 = zeros(n_files,1);

for nj = 1:n_files

    img = squeeze(imgs(n_ch,:,:,nj));

    spectrum_bg(nj)   = mean(img(mask_bg));
    spectrum_sig1(nj) = mean(img(mask_sig1));
    spectrum_sig2(nj) = mean(img(mask_sig2));

end

%% -------- Correction du background --------

sp1_corr = spectrum_sig1 - spectrum_bg;
sp2_corr = spectrum_sig2 - spectrum_bg;

sp_sum_corr = sp1_corr + sp2_corr;

%% -------- Tri par wavenumber --------

data1 = [wavenumber(:), sp1_corr(:)];
data2 = [wavenumber(:), sp2_corr(:)];
data3 = [wavenumber(:), sp_sum_corr(:)];

data1 = sortrows(data1,1);
data2 = sortrows(data2,1);
data3 = sortrows(data3,1);

wavenumber_sorted = data1(:,1);

sp1_sorted = data1(:,2);
sp2_sorted = data2(:,2);
sp_sum_sorted = data3(:,2);

%% -------- Calcul des rapports --------

% Intensités maximales
[Imax1, idx1] = max(sp1_sorted);
[Imax2, idx2] = max(sp2_sorted);

ratio_Imax = Imax1 / Imax2;

% Aires sous la courbe
area1 = trapz(wavenumber_sorted, sp1_sorted);
area2 = trapz(wavenumber_sorted, sp2_sorted);

ratio_area = area1 / area2;

%% -------- Plot final --------

figure

yyaxis left
plot(wavenumber_sorted, sp1_sorted,'-ob','LineWidth',1.5);
ylabel('Intensity ROI 1 (a.u.)')

yyaxis right
plot(wavenumber_sorted, sp2_sorted,'-o','Color', [1 0.5 0],'LineWidth',1.5);
ylabel('Intensity ROI 2 (a.u.)')

xlabel('Wavenumber (cm^{-1})')
title(['Spectra (Channel ' num2str(n_ch) ', BG corrected)'])
legend('ROI Signal 1','ROI Signal 2','Location','best')
grid on


% Marquer les maxima
% plot(wavenumber_sorted(idx1), Imax1,'sr','MarkerFaceColor','r','MarkerSize',8);
% plot(wavenumber_sorted(idx2), Imax2,'sg','MarkerFaceColor','g','MarkerSize',8);

% xlabel('Wavenumber (cm^{-1})');
% ylabel('Intensity (a.u.)');
title(['Spectra (Channel ' num2str(n_ch) ', BG corrected)']);

legend('ROI Signal 1', ...
       'ROI Signal 2', ...
       'Location','best');

grid on;
box on;

% Affichage des rapports sur la figure
txt = {
    sprintf('Max ROI1 = %.3f', Imax1)
    sprintf('Max ROI2 = %.3f', Imax2)
    sprintf('I_{max,1}/I_{max,2} = %.3f', ratio_Imax)
    sprintf('Area ROI1 = %.3f', area1)
    sprintf('Area ROI2 = %.3f', area2)
    sprintf('Area_1/Area_2 = %.3f', ratio_area)
    };

annotation('textbox',[0.73 0.60 0.28 0.25],...
    'String',txt,...
    'FitBoxToText','on',...
    'BackgroundColor','white');


% %Plot spectrum with interactive or manually ROI selection 
% 
% 
% 
% 
% 
% 
% % Image utilisée pour définir les ROI
% %img_max = squeeze(imgs(n_ch, :, :, 25));   % Y x X
% I_raw = squeeze(imgs);
% figure('Name','Sélection ROI','NumberTitle','off');
% % imagesc(sum(I_raw,3));
% imagesc(I3); caxis([-20 15]); colorbar;
% % imagesc(I_raw(:,:,1));
% axis image;
% colormap parula;
% colorbar;
% 
% 
% title('1) Sélectionnez le ROI BACKGROUND puis double-clic');
% 
% % -------- ROI BACKGROUND --------
% roi_bg = drawrectangle('Color','b');
% wait(roi_bg);   % attendre double-clic
% mask_bg = createMask(roi_bg);
% 
% title('2) Sélectionnez le ROI SIGNAL puis double-clic');
% 
% % -------- ROI SIGNAL --------
% roi_sig = drawrectangle('Color','r');
% wait(roi_sig);
% mask_sig = createMask(roi_sig);
% 
% % Position du rectangle BACKGROUND [x, y, largeur, hauteur]
% pos_bg = roi_bg.Position;
% fprintf('x_bg=%d; y_bg=%d; width_bg=%d; height_bg=%d;\n', ...
%         pos_bg(1), pos_bg(2), pos_bg(3), pos_bg(4));
% 
% % Position du rectangle SIGNAL
% pos_sig = roi_sig.Position;
% fprintf('x_sig=%d; y_sig=%d; width_sig=%d; height_sig=%d;\n', ...
%         pos_sig(1), pos_sig(2), pos_sig(3), pos_sig(4));



%% Plot spectrum with interactive or manually ROI selection 
% ROI_known = true; 
% 
% shift_x = -10; 
% shift_y = 1;
% 
% if ROI_known == true 
% 
% 
%     % Image utilisée pour définir les ROI
%     I_raw = squeeze(imgs);
%     figure('Name','Sélection ROI','NumberTitle','off');
%     imagesc(I3); caxis([-10 15]); colorbar;
%     axis image;
%     colormap parula;
%     colorbar;
% 
%     % -------- Coordonnées du ROI BACKGROUND (à modifier) --------
% x_bg=7.339374e+01; y_bg=9.090797e+01; width_bg=8.633776e+00; height_bg=9.620493e+00;
% x_sig=6.130645e+01; y_sig=5.242600e+01; width_sig=4.045541e+01; height_sig=2.836812e+01;
% 
% 
%     x_bg = x_bg + shift_x;
%     y_bg = y_bg + shift_y;
% 
%     % Créer le masque BACKGROUND
%     mask_bg = false(size(I3, 1), size(I3, 2));
%     mask_bg(floor(y_bg):floor(y_bg)+height_bg-1, floor(x_bg):floor(x_bg)+width_bg-1) = true;
%     pos_bg = [x_bg, y_bg, width_bg, height_bg];
% 
%     % Afficher le rectangle BACKGROUND
%     rectangle('Position', pos_bg, 'EdgeColor', 'b', 'LineWidth', 2);
% 
%     fprintf('ROI BACKGROUND : x=%d, y=%d, largeur=%d, hauteur=%d\n', ...
%             pos_bg(1), pos_bg(2), pos_bg(3), pos_bg(4));
% 
%     % -------- Coordonnées du ROI SIGNAL (à modifier) --------
% 
% 
%     x_sig = x_sig + shift_x;
%     y_sig = y_sig + shift_y;
% 
%     % Créer le masque SIGNAL
%     mask_sig = false(size(I3, 1), size(I3, 2));
%     mask_sig(floor(y_sig):floor(y_sig)+height_sig-1, floor(x_sig):floor(x_sig)+width_sig-1) = true;
%     pos_sig = [x_sig, y_sig, width_sig, height_sig];
% 
%     % Afficher le rectangle SIGNAL
%     rectangle('Position', pos_sig, 'EdgeColor', 'r', 'LineWidth', 2);
% 
%     fprintf('ROI SIGNAL : x=%d, y=%d, largeur=%d, hauteur=%d\n', ...
%             pos_sig(1), pos_sig(2), pos_sig(3), pos_sig(4));
% 
% 
% else  
% 
%     % Image utilisée pour définir les ROI
%     %img_max = squeeze(imgs(n_ch, :, :, 25));   % Y x X
%     I_raw = squeeze(imgs);
%     figure('Name','Sélection ROI','NumberTitle','off');
%     % imagesc(sum(I_raw,3));
%     imagesc(I3); caxis([-20 15]); colorbar;
%     % imagesc(I_raw(:,:,1));
%     axis image;
%     colormap parula;
%     colorbar;
% 
% 
%     title('1) Sélectionnez le ROI BACKGROUND puis double-clic');
% 
%     % -------- ROI BACKGROUND --------
%     roi_bg = drawrectangle('Color','b');
%     wait(roi_bg);   % attendre double-clic
%     mask_bg = createMask(roi_bg);
% 
%     title('2) Sélectionnez le ROI SIGNAL puis double-clic');
% 
%     % -------- ROI SIGNAL --------
%     roi_sig = drawrectangle('Color','r');
%     wait(roi_sig);
%     mask_sig = createMask(roi_sig);
% 
%     % Position du rectangle BACKGROUND [x, y, largeur, hauteur]
%     pos_bg = roi_bg.Position;
%     fprintf('x_bg=%d; y_bg=%d; width_bg=%d; height_bg=%d;\n', ...
%             pos_bg(1), pos_bg(2), pos_bg(3), pos_bg(4));
% 
%     % Position du rectangle SIGNAL
%     pos_sig = roi_sig.Position;
%     fprintf('x_sig=%d; y_sig=%d; width_sig=%d; height_sig=%d;\n', ...
%             pos_sig(1), pos_sig(2), pos_sig(3), pos_sig(4));
% end 
% % close(gcf);
% 
% %% -------- Extraction du spectre --------
% 
% n_files = size(imgs,4);
% spectrum_sig = zeros(n_files,1);
% spectrum_bg  = zeros(n_files,1);
% 
% for nj = 1:n_files
%     img = squeeze(imgs(n_ch,:,:,nj));
% 
%     spectrum_sig(nj) = mean(img(mask_sig));
%     spectrum_bg(nj)  = mean(img(mask_bg));
% end
% 
% % Soustraction du background
% spectrum_corr = spectrum_sig - spectrum_bg;
% 
% % --- Tri par wavenumber ---
% data = [wavenumber(:), spectrum_corr(:)];
% data_sorted = sortrows(data, 1);
% 
% wavenumber_sorted = data_sorted(:,1);
% sp_sorted = data_sorted(:,2);
% 
% % Supprimer point aberrant si nécessaire
% %spectrum_corr(9) = []; %calcite no chirp 
% 
% %-------- Plot final --------
% figure;
% plot(wavenumber_sorted, sp_sorted,'-o','LineWidth',1.5);
% xlabel('wavenumber (cm-1)');
% ylabel('Intensity (a.u.)');
% title(['Spectrum (Channel ' num2str(n_ch) ', BG corrected)']);
% grid on;

% superpose_spectre_Vaterite(wavenumber_sorted,sp_sorted)

%% supperpose spectres

superpose_spectre_Cal_ACC(wavenumber_sorted,sp_sorted,10.8);

%% Simple multi-peak detection and Gaussian fitting

% --- Clean data ---
valid = isfinite(sp_sorted) & isfinite(wavenumber_sorted(:));
wn = wavenumber_sorted(valid);
sp = sp_sorted(valid);

% Sort once and for all (CRITICAL)
[wn, idx] = sort(wn);
sp = sp(idx);

% --- Peak detection ---
[pks, locs, widths] = findpeaks(sp, wn, ...
    'MinPeakProminence', 0.05*max(sp), ...
    'MinPeakDistance', 0.01);

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
    win = 2 * widths(k);
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

% Dossier de sauvegarde des figures de fit et des images
fit_fig_dir = [sub_dir_save '/spectra_fit_figures/'];
calcite_img_dir = [sub_dir_save '/calcite_images/']; % Dossier pour les images de calcite
mat_data_dir = [sub_dir_save '/mat_data/']; % Dossier pour les fichiers .mat

% Créer les dossiers s'ils n'existent pas
if exist(fit_fig_dir, 'dir') == 0
    mkdir(fit_fig_dir);
end
if exist(calcite_img_dir, 'dir') == 0
    mkdir(calcite_img_dir);
end
if exist(mat_data_dir, 'dir') == 0
    mkdir(mat_data_dir);
end

I3bis = I3;

% --- Sauvegarde de la figure de fit ---
% Récupérer la figure courante
hFig = gcf;

% Nom du fichier pour la figure de fit
fname_fig = [fit_fig_dir 'spectrum_fit_channel_' num2str(n_ch) '.png'];

% Sauvegarde haute résolution
exportgraphics(hFig, fname_fig, 'Resolution', 300);
disp(['Figure de fit sauvegardée : ' fname_fig]);

% --- Sauvegarde de l'image de calcite I3 au format .mat ---
% Nom du fichier .mat pour I3
fname_mat = [mat_data_dir 'calcite_I3bis_channel_' num2str(n_ch) '.mat'];

% Enregistrer I3 (et éventuellement d'autres variables utiles)
save(fname_mat, 'I3bis', 'wavelengths', 'wavenumber', 'n_ch', '-v7.3');
disp(['Image de calcite I3 sauvegardée au format .mat : ' fname_mat]);


