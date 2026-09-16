%% Variables needed for running the code on its own
clear all;
close all;
%n_pixel_y = 100; n_pixel_x = 100;

addpath('C:\Users\sacha.bucourt\Documents\MATLAB\MesFonctions')
addpath('C:\Users\sacha.bucourt\Documents\MATLAB\fonctions_banque_spectre')


%% A COMPLETER : 
% chemin vers dossier dans lequel se trouve le dossier ANA (data SRS) : 
main_dir = 'C:\Users\sacha.bucourt\Documents\Data lab\CHIRP\260603\15-34-49_ACC_7ps_bis'

sub_dir  = '';
sub_dir_save = [main_dir '/extracted_data/' sub_dir];

title_fig = 'calcite geologique - chirp 7ps';

wavelengths =[929,929.7,930,927,927.5,927.9,928.3,928.6,929.4,927.2,926.6,926.4,926,924.9];

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

%% Map 
I_raw = squeeze(imgs);

% noise_study(imgs,3,3);
% figure(99); imagesc(); colorbar;

% figure(100); imagesc(sum(I_raw,3)); colorbar;
% x1_s = 110;
% x1_e = 20;
% x2_s = 120;
% x2_e = 30;
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

% figure(101); imagesc(sum(I_corr,3)); colorbar;
%Afficher images SRS 
n1 = 1; 
n2 = 3;
n3 = 4;
n4 = 6; 
% n5 = 5;
I1 = I_raw(:,:,n1); % ACC Chira
I2 = I_raw(:,:,n2); % inf ACC 
I3 = I_raw(:,:,n3); % Calcite
I4 = I_raw(:,:,n4); % ACC 
% I5 = I_corr(:,:,n5); % fluo 2

figure(102); clf;
Imax = 150;
Imin= 80;

subplot(2,3,1);
imagesc(I1); caxis([Imin Imax]); colorbar;
title('ACC Chahira (I1)');


subplot(2,3,3);
imagesc(I2); caxis([Imin Imax]); colorbar;
title('inf ACC (I2)');


subplot(2,3,2);
imagesc(I3); caxis([Imin Imax]); colorbar;
title('Calcite (I3)');
hold on;


subplot(2,3,4);
imagesc(I4); caxis([Imin Imax]); colorbar;
title('ACC (I4)');


    subplot(2,3,5);
imagesc(I4-I2); caxis([0 10]); colorbar;
title('I4-I2)');

subplot(2,3,6);
imagesc(I4-I1); caxis([0 10]); colorbar;
title('I3-I1');  

sgtitle('Map ACC + Calcite', 'FontSize', 12, 'FontWeight', 'bold');

%% Plot spectrum with interactive ROI selection (chatGPT generated)


% --- Find index of maximum spectrum 
[~, nj_max] = max(spectrum);

% Image utilisée pour définir les ROI
%img_max = squeeze(imgs(n_ch, :, :, 25));   % Y x X
I_raw = squeeze(imgs);
figure('Name','Sélection ROI','NumberTitle','off');
imagesc(sum(I_raw,3));
% imagesc(I_raw(:,:,1));
axis image;
colormap parula;
colorbar;
title('1) Sélectionnez le ROI BACKGROUND puis double-clic');

% -------- ROI BACKGROUND --------
roi_bg = drawrectangle('Color','b');
wait(roi_bg);   % attendre double-clic
mask_bg = createMask(roi_bg);

title('2) Sélectionnez le ROI SIGNAL puis double-clic');

% -------- ROI SIGNAL --------
roi_sig = drawrectangle('Color','r');
wait(roi_sig);
mask_sig = createMask(roi_sig);

close(gcf);

% -------- Extraction du spectre --------

n_files = size(imgs,4);
spectrum_sig = zeros(n_files,1);
spectrum_bg  = zeros(n_files,1);

for nj = 1:n_files
    img = squeeze(imgs(n_ch,:,:,nj));

    spectrum_sig(nj) = mean(img(mask_sig));
    spectrum_bg(nj)  = mean(img(mask_bg));
end

% Soustraction du background
spectrum_corr = spectrum_sig - spectrum_bg;

% --- Tri par wavenumber ---
data = [wavenumber(:), spectrum_corr(:)];
data_sorted = sortrows(data, 1);

wavenumber_sorted = data_sorted(:,1);
sp_sorted = data_sorted(:,2);

% Supprimer point aberrant si nécessaire
%spectrum_corr(9) = []; %calcite no chirp 

%-------- Plot final --------
figure;
plot(wavenumber_sorted, sp_sorted,'-o','LineWidth',1.5);
xlabel('wavenumber (cm-1)');
ylabel('Intensity (a.u.)');
title(['Spectrum (Channel ' num2str(n_ch) ', BG corrected)']);
grid on;

% superpose_spectre_Vaterite(wavenumber_sorted,sp_sorted)

%% supperpose spectres

superpose_spectre_ACC(wavenumber_sorted,sp_sorted,4)

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


