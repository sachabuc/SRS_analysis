function params = parameters_260527_13_05_52_vaterite_7ps()

    % Chemin des dossiers
    this_dir     = fileparts(mfilename('fullpath'));
    project_root = fileparts(fileparts(this_dir));

    % Data 
    day_folder_data = '260527';
    folder_data = '13-05-52_vaterite_7ps';

    % Data to compare 
    day_folder_data_2compare = '';
    folder_data_2compare = '';

    params.main_dir = fullfile(project_root, 'data', 'raw', 'data_chirp', ...
        day_folder_data, folder_data);
    params.sub_dir = fullfile(project_root, 'data', 'processed', 'data_chirp', ...
        day_folder_data, folder_data);

    params.results_dir = fullfile(project_root, 'results', 'extracted_data', ...
    day_folder_data,folder_data);

    params.figures_dir = fullfile(project_root, 'results', 'figures', ...
    day_folder_data,folder_data);

    if ~exist(params.results_dir, 'dir')
        mkdir(params.results_dir);
    end

    % Chemins pour les données à comparer
    params.path2pixel_fit = fullfile(project_root, 'results', 'extracted_data', ...
    day_folder_data,folder_data,'pixel_fit');

    params.path2ref_roi_compare = fullfile(project_root, 'results', 'extracted_data', ...
    day_folder_data,folder_data,'ref_roi_compare');

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
    params.wavelengths = [926.6,927.1,927.6,928,928.5,929,927.8,927.4,926.8,926.2,925.8];
    params.wavelengths_7ps = [926.7,927.1,927.5,927.9,928.5,928.8,929.3,929.6,930,926.9,926.1,926.5,925.7,925,924.4];
    params.pompe = 1031;
    params.wavenumber = 1e7 ./ params.wavelengths - 1e7 ./ params.pompe;
    params.wavenumber_7ps = 1e7 ./ params.wavelengths_7ps - 1e7 ./ params.pompe;

    params.fwhm_mesure = 5.5;
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
    params.use_CAL = false;
    params.use_ARA = false;
    params.use_VAT = true;
    params.use_ACC = false;
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
    params.FWHM_UB = [4, 4, 10, 40, 10, 10];
    params.lineshape_type = 'gaussian';
    params.ci_alpha = 0.5;

    % Paramètres de segmentation
    params.R2_min_final = 0.7;
    params.threshold_sigma_final = 1.7;
    params.min_points_above_noise = 1;
    params.alpha_dominance = 1;
    params.dominance_phases = [false false false false false false];
    params.detection_method = 'significance';
    params.threshold_A = 10;
    params.nbr_pix_per_phase = 30;
    params.priority_phases =       [false false false false false false];
    params.priority_min_fraction = [0 0 0 0 0 0];
    params.methode_ref_spectra = '';

    % Paramètres spectres ROI 
    params.shift_row = 0;
    params.shift_col = 0;
    
    % params.roi2 = [75+params.shift_row 80+params.shift_row...
    %     100+params.shift_col 105+params.shift_col]; %[row_start row_end col_start col_end]
    params.roi1 = [66+params.shift_row 69+params.shift_row...
        113+params.shift_col 116+params.shift_col]; %[row_start row_end col_start col_end]
    params.roi2 = [];

    params.colors_roi = [0.8500, 0.3250, 0.0980;0, 0.4470, 0.7410];
    params.phase_colors = [0.4660, 0.6740, 0.1880];

    params.nu_interval = [min(params.wavenumber) max(params.wavenumber)];

    % Paramètres d'affichage
    params.load_pixel_fit = false;
    params.calcul_fwhm_instr = false;
    params.do_noise_study = true;
    params.do_lsqnonneg_treatment = false;
    params.display_intensity_maps = true;
    params.display_figures = true;
    params.plot_ref_spectra = true;
    params.plot_pixel_fits = true;
    params.display_fit = true;
    params.ref_roi_compare = false; 
    params.compare_acquisition = false;
    params.display_fit_stat = true;
    params.display_R2_stat = false;

    %sauvegarde
    params.exportgraphics_segm_roi = false;

end