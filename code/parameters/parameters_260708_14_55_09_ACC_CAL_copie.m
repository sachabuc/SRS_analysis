function params = parameters_260708_14_55_09_ACC_CAL_copie()

    % Chemin des dossiers
    this_dir     = fileparts(mfilename('fullpath'));
    project_root = fileparts(fileparts(this_dir));

    % Data 
    day_folder_data = '260708';
    folder_data = '14-55-09_ACC_Cal_Copie';

    % Data to compare 
    day_folder_data_2compare = '';
    folder_data_2compare = '';

    params.main_dir = fullfile(project_root, 'data', 'raw', 'data_chirp', ...
        day_folder_data, folder_data);
    params.sub_dir = '';

    params.results_dir = fullfile(project_root, 'results', 'extracted_data', ...
    day_folder_data,folder_data);

    params.figures_dir = fullfile(project_root, 'results', 'figures', ...
    day_folder_data,folder_data);

    if ~exist(params.results_dir, 'dir')
        mkdir(params.results_dir);
    end

    params.path2pixel_fit = fullfile(project_root, 'results', 'extracted_data', ...
    day_folder_data,folder_data,'pixel_fit');

    % Chemins pour les données à comparer
    params.path2phase_model_7ps = fullfile(project_root, 'results', 'extracted_data', ...
    day_folder_data_2compare,folder_data_2compare,'phase_model');
    params.path2ref_spectra_7ps = fullfile(project_root, 'results', 'extracted_data', ...
    day_folder_data_2compare,folder_data_2compare,'ref_spectra');

    % Chemins des fonctions
    params.function_paths = {
        fullfile(project_root, 'code', 'functions', 'functions_model_carbonate'), ...
        fullfile(project_root, 'code', 'utils') ...
    };


    % Paramètres d'acquisition
    params.n_depart = 3;
    params.n_ch = 1;
    params.wavelengths = [927, 927.5, 928, 928.3, 928.6, 929.1, 929.4, 929.6, 929.8, 930.4, ...
                           930.8, 931.1, 931.5, 931.8, 932.5, 932.9, 926.4, 926, 925.6, ...
                           925.2, 924.8, 924, 923];
    params.wavelengths_7ps = [928.6, 929.1, 929.5, 929.8, 930.2, 930.6, 931.1, 928, 927.6, ...
                               927.2, 926.8, 926.4, 926, 925.5, 928.3];
    params.pompe = 1031;
    params.wavenumber = 1e7 ./ params.wavelengths - 1e7 ./ params.pompe;
    params.wavenumber_7ps = 1e7 ./ params.wavelengths_7ps - 1e7 ./ params.pompe;

    params.fwhm_mesure = 14.3;
    params.fwhm_ref = 3.5;

    % Paramètres de prétraitement
    params.x1_s = 90; params.x1_e = 95;
    params.x2_s = 75; params.x2_e = 80;
    params.wi = 4;
    params.idl = 125; params.idc = 97;
    params.xl_s = 100; params.xl_e = 125;
    params.xc_s = 109; params.xc_e = 125;
      
    % Paramètres d'affichage (pour plot_srs_images)
    params.ni = [8, 6, 2, 3]; % [n1, n2, n3, n4]
    params.Imin = -10;
    params.Imax = 10;
    params.diff_min = -5;
    params.diff_min = 5;
    params.titles = {'ACC Chahira (I1)', 'inf ACC (I2)', 'Calcite (I3)', 'ACC (I4)'};

    % Paramètres du modèle théorique
    params.use_CAL = true;
    params.use_ARA = false;
    params.use_VAT = false;
    params.use_ACC = true;
    params.use_CCHH = false;
    params.use_MHC = false;

    % Paramètres d'initialisation linéaire
    params.R2_init = 0.5;
    params.threshold_sigma_init = 1;

    % Paramètres de fit non linéaire
    params.nu_is_variable = [true false false true false false];
    params.FWHM_is_variable = [true false false true false false];
    params.nu_LB = [1084.5, 1084, 1073, 1073, 1097, 1066];
    params.nu_UB = [1086.5, 1086.5, 1093, 1082, 1102, 1070];
    params.FWHM_LB = [1, 1, 3, 20, 3, 3];
    params.FWHM_UB = [4, 4, 10, 40, 10, 10];
    params.lineshape_type = 'gaussian';
    params.ci_alpha = 0.5;

    % Paramètres de segmentation
    params.R2_min_final = 0.5;
    params.threshold_sigma_final = 1;
    params.min_points_above_noise = 1;
    params.alpha_dominance = 1;
    params.dominance_phases = [false false false true false false];
    params.detection_method = 'significance';
    params.threshold_A = 10;
    params.phase2plot = [1 4];
    params.nbr_pix_per_phase = [30 90];
    params.priority_phases =       [false false false true false false];
    params.priority_min_fraction = [0 0 0 1 0 0];
    params.methode_ref_spectra = '';


    
    
    params.roi1 = [75 80 100 105]; %[row_start row_end col_start col_end]
    params.roi2 = [25 33 60 70]; %[row_start row_end col_start col_end]

    params.colors_roi = [0, 0.4470, 0.7410; 0.8500, 0.3250, 0.0980];
    params.phase_colors = [0.4660, 0.6740, 0.1880; 0.4940, 0.1840, 0.5560];

    params.roi1_phase_idx = params.phase2plot(1);
    params.roi2_phase_idx = params.phase2plot(2);

    params.shift_row = 2;
    params.shift_col = 2;

    % Paramètres d'affichage
    params.load_pixel_fit = true;
    params.calcul_fwhm_instr = false;
    params.do_noise_study = true;
    params.do_lsqnonneg_treatment = false;
    params.display_intensity_maps = true;
    params.display_figures = true;
    params.plot_ref_spectra = true;
    params.plot_pixel_fits = true;
    params.display_fit = true;
    params.compare_acquisition = false;
    params.display_fit_stat = true;
    params.display_R2_stat = false;

    %sauvegarde
    params.exportgraphics_segm_roi = true;

end