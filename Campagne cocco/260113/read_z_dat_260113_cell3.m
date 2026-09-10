%% Variables needed for running the code on its own
clear all;
close all;
%n_pixel_y = 100; n_pixel_x = 100;
addpath('C:\Users\sacha.bucourt\Documents\MATLAB\MesFonctions')

%% A COMPLETER : 
% chemin vers data SRS : 

main_dir = 'C:\Users\sacha.bucourt\Documents\Data lab\spectres\campagne cocco\260113\cell3'
sub_dir  = '';
sub_dir_save = [main_dir '/extracted_data/' sub_dir];

% title_fig = 'ACC synthétique';

% observed plan. z_obs = 0 ==> mid plane 
z_obs = 0;

wavelengths = [927.4,928.6,925.8,929.4,927.2]; 
% 
 
contrast = true;

pompe = 1031;
wavenumber = 1e7 ./ wavelengths - 1e7 ./ pompe; % wavenumber in cm-1

%% DATA CACHE (avoid reloading folders every time)


cache_dir  = fullfile(main_dir, 'extracted_data');
if ~exist(cache_dir,'dir')
    mkdir(cache_dir)
end

cache_file = fullfile(cache_dir, 'cache_full_dataset.mat');

use_cache = true;   % mettre false si tu veux forcer la relecture

%% LOAD DATA (with cache)

if use_cache && exist(cache_file,'file')

    fprintf('Loading cached dataset...\n');
    load(cache_file, ...
        'imgs','imgs_Z','n_ch_tot','n_ch_ana','n_ch_dig', ...
        'n_pixel_x','n_pixel_y','wdth_img','hght_img', ...
        'pol_angle','pol_offset','z_pos','x_min','x_max', ...
        'y_min','y_max','calib','stage_x','stage_y', ...
        'delay_offset','delay_img','dwell_time','pixel_rep', ...
        'lambda_tisaf','OPO_measured_wavelength','OPO_set_wavelength', ...
        'OPO_power','cntnt','n_files_txt','z_mid');

    nW = numel(cntnt);

else

    fprintf('No cache found → reading raw folders...\n');

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
    
    cntnt_all = dir(main_dir);
    cntnt_all = cntnt_all([cntnt_all.isdir]);
    cntnt_all = cntnt_all(~ismember({cntnt_all.name},{'.','..'}));
    
    % --- Keep only folders containing 1_ANA ---
    isZfolder = false(numel(cntnt_all),1);
    
    for k = 1:numel(cntnt_all)
        if exist(fullfile(main_dir, cntnt_all(k).name, '1_ANA'),'dir')
            isZfolder(k) = true;
        end
    end
    
    cntnt = cntnt_all(isZfolder);
    nW = numel(cntnt);
    
    fprintf('Number of valid Z folders detected: %d\n', nW);
    
    spectrum = nan(nW,1);
    
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
    imgs_Z = zeros(nW,Ny1, Nx1, n_files_1);
    
    % Store first image
    % imgs_Z(1,:,:,1) = img0; 
    
    for k = 1:nW
    
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

    %% ================== SAVE CACHE ==================
    fprintf('Saving cache file...\n');

    save(cache_file, ...
        'imgs','imgs_Z','n_ch_tot','n_ch_ana','n_ch_dig', ...
        'n_pixel_x','n_pixel_y','wdth_img','hght_img', ...
        'pol_angle','pol_offset','z_pos','x_min','x_max', ...
        'y_min','y_max','calib','stage_x','stage_y', ...
        'delay_offset','delay_img','dwell_time','pixel_rep', ...
        'lambda_tisaf','OPO_measured_wavelength','OPO_set_wavelength', ...
        'OPO_power','cntnt','n_files_txt','z_mid',...
        '-v7.3');   % IMPORTANT pour gros tableaux

end
%% contrast entre images sélectionnées 
if contrast == true

    % figure(99); imagesc(); colorbar;

    I_raw = squeeze(imgs_Z(:,:,:,z_mid));

    figure(101); imagesc(squeeze(sum(I_raw,1))); colorbar;
    x1_s = 120;
    x1_e = 140;
    x2_s = 120;
    x2_e = 140;
    I_bckg(:) =mean(mean(I_raw(:,x1_s:x1_e,x2_s:x2_e),2),3);

    for ii = 1:size(I_raw,1)
        I_corr(ii,:,:) = I_raw(ii,:,:) - I_bckg(ii);
    end

%Contrast

% [927,928.6,925.8,929.2,927.3,928.6]

    n1 = 1; 
    n2 = 3;
    n3 = 2;
    n4 = 4;
    % n5 = ;
    I1 = squeeze(I_corr(n1,:,:)); % calcite
    I2 = squeeze(I_corr(n2,:,:)); % CCHH inf 
    I3 = squeeze(I_corr(n3,:,:)); % ACChira
    I4 = squeeze(I_corr(n4,:,:)); % inf ACC
    % I5 = squeeze(I_corr(n5,:,:)); % inf ACC 
    % C=(I1-I2)./(I1+I2);
    C1=(I1-I2);
    C3=(I3-I2);
    C4=(I4-I2);
    % C5=(-I5-I2);

    figure(102);

    subplot(3,3,1);
    imagesc(I1); caxis([-1 5]); colorbar;
    title('calcite (I1)');
    hold on;
    contour(I1, 1, 'w', 'LineWidth', 1);
    %     % Superposition des pixels avec R² > seuil_R2
    % [rows, cols] = find(R2_map > seuil_R2);
    % scatter(cols, rows, 10, 'r', 'filled', 'MarkerFaceAlpha', 0.5, 'MarkerEdgeAlpha', 0.5);
    hold off;

    subplot(3,3,2);
    imagesc(I3); caxis([-1 2]); colorbar;
    title('ACChira (I3)');
    hold on;
    contour(I1, 1, 'w', 'LineWidth', 1);
    %     % Superposition des pixels avec R² > seuil_R2
    % [rows, cols] = find(R2_map > seuil_R2);
    % scatter(cols, rows, 10, 'r', 'filled', 'MarkerFaceAlpha', 0.5, 'MarkerEdgeAlpha', 0.5);
    hold off;

    subplot(3,3,3);
    imagesc(I4); caxis([-1 2]); colorbar;
    title('inf ACC (I4)');
    hold on;
    contour(I1, 1, 'w', 'LineWidth', 1);
    %     % Superposition des pixels avec R² > seuil_R2
    % [rows, cols] = find(R2_map > seuil_R2);
    % scatter(cols, rows, 10, 'r', 'filled', 'MarkerFaceAlpha', 0.5, 'MarkerEdgeAlpha', 0.5);
    hold off;

    subplot(3,3,4);
    imagesc(I2); caxis([-1 2]); colorbar;
    title('sup CCHH (I2)');
    hold on;
    contour(I1, 1, 'w', 'LineWidth', 1);
    %     % Superposition des pixels avec R² > seuil_R2
    % [rows, cols] = find(R2_map > seuil_R2);
    % scatter(cols, rows, 10, 'r', 'filled', 'MarkerFaceAlpha', 0.5, 'MarkerEdgeAlpha', 0.5);
    hold off;

    subplot(3,3,5);
    imagesc(I3-I1); caxis([-1 2]); colorbar;
    title('(I3-I1)');
    hold on;
    contour(I1, 1, 'w', 'LineWidth', 1);
    %     % Superposition des pixels avec R² > seuil_R2
    % [rows, cols] = find(R2_map > seuil_R2);
    % scatter(cols, rows, 10, 'r', 'filled', 'MarkerFaceAlpha', 0.5, 'MarkerEdgeAlpha', 0.5);
    hold off;

    subplot(3,3,6);
    imagesc(I3-I2); caxis([-1 2]); colorbar;
    title('I3-I2');
    hold on;
    contour(I1, 1, 'w', 'LineWidth', 1);
    %     % Superposition des pixels avec R² > seuil_R2
    % [rows, cols] = find(R2_map > seuil_R2);
    % scatter(cols, rows, 10, 'r', 'filled', 'MarkerFaceAlpha', 0.5, 'MarkerEdgeAlpha', 0.5);
    hold off;

    subplot(3,3,7);
    imagesc(I2-I1); caxis([-1 2]); colorbar;
    title('I2-I1');
    hold on;
    contour(I1, 1, 'w', 'LineWidth', 1);
    %     % Superposition des pixels avec R² > seuil_R2
    % [rows, cols] = find(R2_map > seuil_R2);
    % scatter(cols, rows, 10, 'r', 'filled', 'MarkerFaceAlpha', 0.5, 'MarkerEdgeAlpha', 0.5);
    hold off;

    subplot(3,3,8);
    imagesc(I3-I4); caxis([-1 2]); colorbar;
    title('I3-I4');
    hold on;
    contour(I1, 1, 'w', 'LineWidth', 1);
    %     % Superposition des pixels avec R² > seuil_R2
    % [rows, cols] = find(R2_map > seuil_R2);
    % scatter(cols, rows, 10, 'r', 'filled', 'MarkerFaceAlpha', 0.5, 'MarkerEdgeAlpha', 0.5);
    hold off;

    subplot(3,3,9);
    imagesc(I4-I1); caxis([-1 2]); colorbar;
    title('I4-I1');
    hold on;
    contour(I1, 1, 'w', 'LineWidth', 1);
    %     % Superposition des pixels avec R² > seuil_R2
    % [rows, cols] = find(R2_map > seuil_R2);
    % scatter(cols, rows, 10, 'r', 'filled', 'MarkerFaceAlpha', 0.5, 'MarkerEdgeAlpha', 0.5);
    hold off;

    
    imgs_Zpermute = permute(imgs_Z, [4,2, 3, 1]); % Réorganiser en (nZ,Nx, Ny, Nlambda) pour adapter aux fonctions suivantes
    
    % choisir stack
    image_Zi = imgs_Zpermute(8,:, :, :); % Si imgs_Z est déjà de taille (Nx, Ny, Nlambda), pas besoin de changer

    
    
    
    [mask_calcite, mask_acc] = detect_calcite_acc_mistral(squeeze(image_Zi),wavenumber,2);

    figure(103);
    subplot(1,2,1); imagesc(mask_calcite); title('Calcite');
    subplot(1,2,2); imagesc(mask_acc); title('ACC');

    intensityprofile(image_Zi,wavenumber,1,10,10,0)

end
%% Plot spectrum with interactive ROI selection (chatGPT generated)

% --- Find index of maximum spectrum (déjà fait chez toi)

%% =========================================================
% ROI selection and spectrum extraction FROM imgs_Z
% =========================================================

%% --- Image de référence pour définir les ROI (somme sur TOUS les z) ---

% imgs_Z : [n_lambda x 150 x 150 x nZ]
img_ref = squeeze(sum(imgs_Z, [1 4]));  % somme sur lambda et z
% -> dimension 150x150


figure('Name','Sélection ROI','NumberTitle','off');
imagesc(img_ref);
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
mask_signal = createMask(roi_sig);




% figure;
% imagesc(img_ref);
% axis image;
% colormap;
% colorbar;
% title('Select SIGNAL ROI (sum over all Z)');
% 
% roi_signal = drawrectangle;
% mask_signal = roi_signal.createMask;
% 
% title('Select BACKGROUND ROI');
% roi_bg = drawrectangle;
% mask_bg = roi_bg.createMask;

%% --- Sélection des plans z à tracer (max 10) ---

nZ = size(imgs_Z,4);
maxZplot = 10;

if nZ <= maxZplot
    z_list = 1:nZ;
else
    % Plans répartis incluant début, milieu et fin
    z_list = unique(round(linspace(1, nZ, maxZplot)));
end

%% --- Spectres pour les plans z sélectionnés ---

figure; hold on;
legend_entries = cell(length(z_list),1);

results = struct;

for iz = 1:length(z_list)

    z = z_list(iz);
    planW = squeeze(imgs_Z(:,:,:,z));  % [n_lambda x 150 x 150]

    spectrum_signal = zeros(nW,1);
    spectrum_bg     = zeros(nW,1);

    for k = 1:nW
        img_k = squeeze(planW(k,:,:));
        spectrum_signal(k) = mean(img_k(mask_signal));
        spectrum_bg(k)     = mean(img_k(mask_bg));
    end

    sp = spectrum_signal - spectrum_bg;

    % --- Tri par wavenumber ---
    data = [wavenumber(:), sp(:)];
    data_sorted = sortrows(data, 1);

    wavenumber_sorted = data_sorted(:,1);
    sp_sorted = data_sorted(:,2);

    % --- Tracé ---
    plot(wavenumber_sorted, sp_sorted, 'LineWidth', 1.2);

    legend_entries{iz} = sprintf('z = %d', z);


end

xlabel('Wavenumber (cm^{-1})');
ylabel('Intensity (a.u.)');
title('Spectrum for selected Z planes');
grid on;
legend(legend_entries, 'Location', 'best');
hold off;




%% Simple multi-peak detection and Gaussian fitting

%% === Multi-peak detection and Gaussian fitting (per z) ===

% % --- Clean data ---
% valid = isfinite(sp_sorted) & isfinite(wavenumber_sorted);
% wn = wavenumber_sorted(valid);
% sp = sp_sorted(valid);
% 
% % --- Peak detection ---
% [pks, locs, widths] = findpeaks(sp, wn, ...
%     'MinPeakProminence', 0.05*max(sp), ...
%     'MinPeakDistance', 0.5);
% 
% n_peaks = numel(pks);
% fprintf('z = %d : %d peaks detected\n', z, n_peaks);
% 
% % --- Display raw spectrum ---
% figure;
% plot(wn, sp, 'k.'); hold on;
% title(sprintf('z = %d', z));
% 
% % --- Gaussian + offset model ---
% gauss_offset = fittype('a*exp(-((x-b)/c)^2) + d', ...
%     'independent','x', ...
%     'coefficients',{'a','b','c','d'});
% 
% % --- Storage ---
% lambda0   = nan(n_peaks,1);
% FWHM_fit  = nan(n_peaks,1);
% amplitude = nan(n_peaks,1);
% offset    = nan(n_peaks,1);
% 
% for k = 1:n_peaks
% 
%     % --- Local fitting window ---
%     win = 1.5 * widths(k);
%     idx_fit = wn > locs(k)-win & wn < locs(k)+win;
% 
%     if sum(idx_fit) < 5
%         continue
%     end
% 
%     xfit = wn(idx_fit);
%     yfit = sp(idx_fit);
% 
%     % --- Robust baseline estimate ---
%     y_sorted = sort(yfit);
%     n_base = max(2, round(0.2*numel(y_sorted)));
%     baseline_est = mean(y_sorted(1:n_base));
% 
%     % --- Fit options ---
%     opts = fitoptions(gauss_offset);
%     opts.StartPoint = [ ...
%         max(yfit)-baseline_est, ...
%         locs(k), ...
%         widths(k)/2, ...
%         baseline_est ];
% 
%     opts.Lower = [0, min(xfit), 0, 0];
%     opts.Upper = [Inf, max(xfit), Inf, max(yfit)];
% 
%     % --- Fit ---
%     ft = fit(xfit, yfit, gauss_offset, opts);
% 
%     % --- Extract parameters ---
%     a = ft.a;
%     b = ft.b;
%     c = abs(ft.c);
%     d = ft.d;
% 
%     lambda0(k)   = b;
%     amplitude(k) = a;
%     offset(k)    = d;
%     FWHM_fit(k)  = 2*sqrt(log(2))*c;
% 
%     % --- Plot fit ---
%     xx = linspace(min(xfit), max(xfit), 300);
%     plot(xx, ft(xx), 'LineWidth', 1.5);
% 
%     % --- Plot FWHM ---
%     y_half = d + a/2;
%     plot([b-FWHM_fit(k)/2, b+FWHM_fit(k)/2], ...
%          [y_half y_half], 'r-', 'LineWidth', 2);
% 
%     % --- Peak marker ---
%     plot(b, d+a, 'rv', 'MarkerFaceColor','r');
% 
% end
% 
% xlabel('Wavenumber (cm^{-1})');
% ylabel('Intensity (a.u.)');
% grid on;

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

%% Save selected figures into extracted_data


% Définir le chemin du dossier pour sauvegarder les figures
fig_dir = fullfile(pwd, 'figures');

% Créer le dossier s'il n'existe pas
if ~exist(fig_dir, 'dir')
    mkdir(fig_dir);
end

% Numéros des figures à sauvegarder
fig_nums = [102, 1, 2];

% Obtenir un timestamp pour éviter d'écraser les fichiers existants
timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');

% Sauvegarder chaque figure
for k = 1:numel(fig_nums)
    fig_num = fig_nums(k);
    if ishandle(fig_num)
        hFig = figure(fig_num);  % Activer la figure
        % Sauvegarder en format .png
        fname_png = fullfile(fig_dir, sprintf('figure_%d_%s.png', fig_num, timestamp));
        exportgraphics(hFig, fname_png, 'Resolution', 300);
        fprintf('Saved figure %d → %s\n', fig_num, fname_png);

        % Sauvegarder en format .fig
        fname_fig = fullfile(fig_dir, sprintf('figure_%d_%s.fig', fig_num, timestamp));
        savefig(hFig, fname_fig);
        fprintf('Saved figure %d → %s\n', fig_num, fname_fig);
    else
        warning('Figure %d does not exist, skipped.', fig_num);
    end

end