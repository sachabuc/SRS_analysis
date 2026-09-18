function params = parameters_260715_corals_2ps()

    % Chemin des dossiers
    this_dir     = fileparts(mfilename('fullpath'));
    project_root = fileparts(fileparts(this_dir));

    % Data 
    day_folder_data = '260715';
    folder_data = '14-15-43_coral_2ps';

    % Data to compare 
    day_folder_data_2compare = '';
    folder_data_2compare = '';

    params.main_dir = fullfile(project_root, 'data', 'raw', 'data_chirp', ...
        day_folder_data, folder_data);
    params.sub_dir = '';

    params.results_dir = fullfile(project_root, 'results', 'extracted_data', ...
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
    params.wavelengths = [927.2,927.5,927.7,928.1,928.5,929.1,929.6,930.2,931.1,...
            926.7,926.3,925.8];
    params.wavelengths_7ps = [928.6,929.1,929.5,929.8,930.2,930.6,931.1,928,927.6, ... 
  927.2,926.8,926.4,926,925.5,928.3];
    params.pompe = 1031;
    params.wavenumber = 1e7 ./ params.wavelengths - 1e7 ./ params.pompe;
    params.wavenumber_7ps = 1e7 ./ params.wavelengths_7ps - 1e7 ./ params.pompe;

    params.fwhm_mesure = 11.1;
    params.fwhm_ref = 3.5;

    % Paramètres de prétraitement
    params.x1_s = 15; params.x1_e = 30;
    params.x2_s = 5; params.x2_e = 15;
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
    params.use_CAL = false;
    params.use_ARA = true;
    params.use_VAT = false;
    params.use_ACC = true;
    params.use_CCHH = false;
    params.use_MHC = false;

    % Paramètres d'initialisation linéaire
    params.R2_init = 0.5;
    params.threshold_sigma_init = 1;

    % Paramètres de fit non linéaire
    params.nu_is_variable = [params.use_CAL params.use_ARA params.use_VAT params.use_ACC params.use_CCHH params.use_MHC];
    params.FWHM_is_variable = [params.use_CAL params.use_ARA params.use_VAT params.use_ACC params.use_CCHH params.use_MHC];
    params.nu_LB = [1084.5, 1084, 1073, 1073, 1097, 1066];
    params.nu_UB = [1086.5, 1086.5, 1093, 1082, 1102, 1070];
    params.FWHM_LB = [1, 1, 3, 20, 3, 3];
    params.FWHM_UB = [5, 5, 10, 40, 10, 10];
    params.lineshape_type = 'gaussian';
    params.ci_alpha = 0.5;

    % Paramètres de segmentation
    params.R2_min_final = 0.7;
    params.threshold_sigma_final = 4;
    params.min_points_above_noise = 2;
    params.alpha_dominance = 10;
    params.dominance_phases = [false false false false false false];
    params.detection_method = 'significance';
    params.threshold_A = 10;
    params.phase2plot = [2 4];
    params.nbr_pix_per_phase = [30 30];
    params.priority_phases =       [false false false params.use_ACC false false];
    params.priority_min_fraction = [0 0 0 0.3 0 0];

    % Paramètres de décalage
    params.shift_row = 2;
    params.shift_col = 2;

    % Paramètres d'action
    params.load_pixel_fit = true;
    params.calcul_fwhm_instr = false;
    params.do_noise_study = true;
    params.do_lsqnonneg_treatment = false;
    params.compare_acquisition = false;

    % Paramètres d'affichage
    params.display_intensity_maps = true;
    params.display_figures = true;
    params.plot_ref_spectra = true;
    params.plot_pixel_fits = true;
    params.display_fit = true;
    params.display_fit_stat = true;
    params.display_R2_stat = false;


end