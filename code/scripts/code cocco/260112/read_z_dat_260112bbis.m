%% Variables needed for running the code on its own
clear all;
close all;
%n_pixel_y = 100; n_pixel_x = 100;


%% A COMPLETER : 
% chemin vers data SRS : 

main_dir = 'C:\Users\sacha.bucourt\Documents\Data lab\spectres\campagne cocco\260112b'
sub_dir  = '';
% sub_dir_save = [main_dir '/extracted_data/' sub_dir];

title_fig = 'ACC synthétique';

% observed plan. z_obs = 0 ==> mid plane 
z_obs = 0;

wavelengths = [927.2, 927.6, 928.0, 926.7, 926.5, 926.2, 928.3, 928.7, 929.2, 930.1, 925.7, 925.0, 924.5, 923.9, 930.4, 931.0, 920.1, 920.3, 919.6, 920.8, 961.5, 961.6, 952.0, 927.3]; 
% 
    

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


%% ===== 3D SPECTRUM EXTRACTION (Z-stacks, cocco) =====

cntnt = dir(main_dir);
cntnt = cntnt([cntnt.isdir]);
cntnt = cntnt(~ismember({cntnt.name},{'.','..'}));

n_Z = numel(cntnt);
fprintf('Number of Z folders detected: %d\n', n_Z);

spectrum = nan(n_Z,1);

%intialization imgs_Z

Z_dir_1 = fullfile(main_dir, cntnt(1).name);
ANA_dir_1 = fullfile(Z_dir_1, '1_ANA');

if ~exist(ANA_dir_1,'dir')
    warning('No 1_ANA folder in %s for initialization', cntnt(1).name);

end

files_1 = dir(fullfile(ANA_dir_1,'*.ASC'));
if isempty(files_1)
    warning('No ASC files_1 in %s', ANA_dir_1);

end

n_files_1 = numel(files_1);

% --- Read Z stack ---
% --- Read first image to get dimensions ---
fname0 = fullfile(ANA_dir_1, files_1(1).name);

txt = fileread(fname0);
txt_fixed = regexprep(txt, '(?<=\d),(?=\d)', '.');

tmpname = [tempname '.tmp'];
fid = fopen(tmpname,'w');
fwrite(fid, txt_fixed);
fclose(fid);

img0 = dlmread(tmpname);
delete(tmpname);

[Ny1, Nx1] = size(img0);

% --- Allocate Z stack ---
imgs_Z = zeros(n_Z,Ny1, Nx1, n_files_1);

% Store first image
% imgs_Z(1,:,:,1) = img0; 

for k = 1:n_Z

    Z_dir = fullfile(main_dir, cntnt(k).name);
    ANA_dir = fullfile(Z_dir, '1_ANA');

    fprintf('Processing folder: %s\n', cntnt(k).name);

    if ~exist(ANA_dir,'dir')
        warning('No 1_ANA folder in %s', cntnt(k).name);
        continue
    end

    files = dir(fullfile(ANA_dir,'*.ASC'));
    if isempty(files)
        warning('No ASC files in %s', ANA_dir);
        continue
    end

    n_files = numel(files);

    % --- Read Z stack ---
    % --- Read first image to get dimensions ---
    fname0 = fullfile(ANA_dir, files(1).name);

    txt = fileread(fname0);
    txt_fixed = regexprep(txt, '(?<=\d),(?=\d)', '.');

    tmpname = [tempname '.tmp'];
    fid = fopen(tmpname,'w');
    fwrite(fid, txt_fixed);
    fclose(fid);

    img0 = dlmread(tmpname);
    delete(tmpname);

    [Ny, Nx] = size(img0);

    % --- Allocate Z stack ---
    % imgs_Z = zeros(Ny, Nx, n_files);

    % Store first image
    imgs_Z(k,:,:,1) = img0;

    for j = 1:n_files
        fname = fullfile(ANA_dir, files(j).name);

        txt = fileread(fname);
        txt_fixed = regexprep(txt, '(?<=\d),(?=\d)', '.');

        tmpname = [tempname '.tmp'];
        fid = fopen(tmpname,'w');
        fwrite(fid, txt_fixed);
        fclose(fid);

        imgs_Z(k,:,:,j) = dlmread(tmpname);
        delete(tmpname);
    end

    % --- Middle Z plane ---
    z_mid = round(n_files/2);
    img_mid = imgs_Z(:,:,z_mid);

    % --- Mean intensity ---
    spectrum(k) = mean(img_mid,'all');
end

cd(main_dir);
%% Plot spectrum with interactive ROI selection (chatGPT generated)

% --- Find index of maximum spectrum (déjà fait chez toi)

%% =========================================================
% ROI selection and spectrum extraction FROM imgs_Z
% =========================================================

%% --- Image de référence pour définir les ROI (somme sur TOUS les z) ---

% imgs_Z : [n_lambda x 150 x 150 x nZ]
img_ref = squeeze(sum(imgs_Z, [1 4]));  % somme sur lambda et z
% -> dimension 150x150

figure;
imagesc(img_ref);
axis image;
colormap;
colorbar;
title('Select SIGNAL ROI (sum over all Z)');

roi_signal = drawrectangle;
mask_signal = roi_signal.createMask;

title('Select BACKGROUND ROI');
roi_bg = drawrectangle;
mask_bg = roi_bg.createMask;


%% =========================================================
% INTERACTIVE Z-SLIDER FOR SPECTRUM + PEAK FITTING
% =========================================================

nZ = size(imgs_Z,4);

% --- Figure ---
hFig = figure('Name','Interactive Z spectrum','NumberTitle','off');
hAx  = axes('Parent',hFig);
hold(hAx,'on');
grid(hAx,'on');

xlabel(hAx,'Wavenumber (cm^{-1})');
ylabel(hAx,'Intensity (a.u.)');

% --- Slider ---
hSlider = uicontrol('Style','slider', ...
    'Min',1,'Max',nZ,'Value',round(nZ/2), ...
    'SliderStep',[1/(nZ-1) 5/(nZ-1)], ...
    'Units','normalized', ...
    'Position',[0.2 0.02 0.6 0.04]);

hText = uicontrol('Style','text', ...
    'Units','normalized', ...
    'Position',[0.82 0.02 0.15 0.04], ...
    'String','z = ');

% --- First plot ---
updateSpectrum(round(nZ/2));

% --- Callback ---
hSlider.Callback = @(src,evt) updateSpectrum(round(src.Value));

%% =========================================================
% UPDATE FUNCTION
% =========================================================
function updateSpectrum(z)

    cla(hAx); hold(hAx,'on');

    % --- Extract Z plane ---
    plan_z = squeeze(imgs_Z(:,:,:,z));   % [n_lambda x Ny x Nx]

    spectrum_signal = zeros(n_Z,1);
    spectrum_bg     = zeros(n_Z,1);

    for k = 1:n_Z
        img_k = squeeze(plan_z(k,:,:));
        spectrum_signal(k) = mean(img_k(mask_signal));
        spectrum_bg(k)     = mean(img_k(mask_bg));
    end

    sp = spectrum_signal - spectrum_bg;

    % --- Sort by wavenumber ---
    data = [wavenumber(:), sp(:)];
    data = data(isfinite(data(:,1)) & isfinite(data(:,2)),:);
    data = sortrows(data,1);

    wn = data(:,1);
    sp = data(:,2);

    % --- Plot spectrum ---
    plot(hAx, wn, sp, 'k-', 'LineWidth', 1.2);

    % --- Peak detection ---
    if max(sp) > 0
        [pks, locs, widths] = findpeaks(sp, wn, ...
            'MinPeakProminence', 0.05*max(sp), ...
            'MinPeakDistance', 0.5);
    else
        pks = []; locs = []; widths = [];
    end

    % --- Gaussian + offset model ---
    gauss_offset = fittype('a*exp(-((x-b)/c)^2) + d', ...
        'independent','x', ...
        'coefficients',{'a','b','c','d'});

    for k = 1:numel(pks)

        win = 1.5 * widths(k);
        idx_fit = wn > locs(k)-win & wn < locs(k)+win;
        if sum(idx_fit) < 5, continue; end

        xfit = wn(idx_fit);
        yfit = sp(idx_fit);

        y_sorted = sort(yfit);
        n_base = max(2, round(0.2*numel(y_sorted)));
        baseline_est = mean(y_sorted(1:n_base));

        opts = fitoptions(gauss_offset);
        opts.StartPoint = [ ...
            max(yfit)-baseline_est, ...
            locs(k), ...
            widths(k)/2, ...
            baseline_est ];

        opts.Lower = [0, min(xfit), 0, 0];
        opts.Upper = [Inf, max(xfit), Inf, max(yfit)];

        ft = fit(xfit, yfit, gauss_offset, opts);

        xx = linspace(min(xfit), max(xfit), 300);
        plot(hAx, xx, ft(xx), 'r-', 'LineWidth', 1.2);

        % --- FWHM ---
        FWHM = 2*sqrt(log(2))*abs(ft.c);
        y_half = ft.d + ft.a/2;
        plot(hAx, [ft.b-FWHM/2 ft.b+FWHM/2], [y_half y_half], 'r-', 'LineWidth', 2);
        plot(hAx, ft.b, ft.d+ft.a, 'rv','MarkerFaceColor','r');
    end

    title(hAx, sprintf('Spectrum – z = %d / %d', z, nZ));
    set(hText,'String',sprintf('z = %d',z));
    drawnow;

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
% fit_fig_dir = [sub_dir_save '/spectra_fit_figures/'];

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