function params = parameters_SRS_v1_cocco_261127_bleach_coral2bis()


    %% Paths to folders

    this_dir     = fileparts(mfilename('fullpath'));
    project_root = fileparts(fileparts(this_dir));

    %%%%%% Data 
    day_folder_data = '261127';
    folder_data = 'bleach_coral2bis'; 
    %%%%%% 

    % if different acquisition in the same folder_data, add \acquisition_name

    params.main_dir = fullfile(project_root, 'data', 'raw', 'Corals', ...
    day_folder_data, folder_data);

    % Chemins des fonctions
    params.function_paths = {
        fullfile(project_root, 'code', 'functions', 'functions_model_carbonate'), ...
        fullfile(project_root, 'code', 'utils')};

    %% Display images
    
    params.show_all_images = true;
    params.frame_rate = 5;
    params.colormap = parula(256);

    %% Noise study 

    params.show_nois_figures = true;
    params.ROI_background = [5 10 5 10];

    %% First analysis - images soustraction 

    params.intervals.aragonite = [1081 1088];
    params.intervals.acc = [1071 1080];
    params.intervals.cchh = [1096 1108];
    params.intervals.background = [1060 1068];
    
    params.Z = 1;
    params.T = 1;
    params.title = 'Comparaison des phases';

    params.showContours = false;       % Afficher les lignes de niveaux
    params.contourLevels = 1;         % Nombre de niveaux
    params.contourColor = 'k';        % Couleur des lignes
    params.contourLineWidth = 0.75;   % Épaisseur des lignes

    params.alpha = 1;
    
    % Réglage indépendant des huit caxis
    params.caxis.aragonite = [];
    params.caxis.acc = [];
    params.caxis.cchh = [];
    params.caxis.background = [];
    
    params.caxis.acc_minus_background = [];
    params.caxis.acc_minus_aragonite = [-0.02 0.02];
    params.caxis.cchh_minus_aragonite = [-0.02 0.02];
    params.caxis.cchh_minus_background = [];

    params.caxis.acc_minus_background_normalized = [-1 1];
    params.caxis.acc_minus_aragonite_normalized = [-1 1];
    params.caxis.cchh_minus_aragonite_normalized = [-1 1];
    params.caxis.cchh_minus_background_normalized = [-1 1];

%% Cabonate mapping

    params.cfg = struct();





%     params.sub_dir = fullfile(project_root, 'data', 'processed', 'Data', ...
%         day_folder_data, folder_data);

    params.results_dir = fullfile(project_root, 'results', 'extracted_data', ...
    day_folder_data,folder_data);

    params.figures_dir = fullfile(project_root, 'results', 'figures', ...
    day_folder_data,folder_data);

    if ~exist(params.results_dir, 'dir')
        mkdir(params.results_dir);
    end

    params.path2pixel_fit = fullfile(project_root, 'results', 'extracted_data', ...
    day_folder_data,folder_data,'pixel_fit');



    params.fwhm_mesure = 9.9;
    params.fwhm_ref = 3.5;
    % params.fwhm_instr = 10;

    % Paramètres de prétraitement
    params.x1_s = 10; params.x1_e = 15;
    params.x2_s = 10; params.x2_e = 15;
    params.wi = 4;
    params.idl = 100; params.idc = 97;
    params.xl_s = 100; params.xl_e = 110;
    params.xc_s = 109; params.xc_e = 115;
      
    % Paramètres d'affichage (pour plot_srs_images)
    params.ni = [8, 6, 2, 3]; % [n1, n2, n3, n4]
    params.Imin = -10;
    params.Imax = 10;
    params.diff_min = -5;
    params.diff_max = 5;
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
    params.nu_is_variable = [true params.use_ARA params.use_VAT params.use_ACC params.use_CCHH false];
    params.FWHM_is_variable = [false params.use_ARA params.use_VAT true params.use_CCHH false];
    params.nu_LB = [1084,   1084, 1073, 1073, 1097, 1064];
    params.nu_UB = [1087, 1086.5, 1093, 1084, 1102, 1072];
    params.FWHM_LB = [1, 1, 3, 25, 3, 1];
    params.FWHM_UB = [8 , 4, 10, 60, 10, 13];
    params.lineshape_type = 'gaussian';
    params.ci_alpha = 0.5;

    % Paramètres de segmentation
    params.R2_min_final = 0.5;
    params.threshold_sigma_final = 1;
    params.min_points_above_noise = 1;
    params.alpha_dominance = 1;
    params.dominance_phases = [false false false false false false];
    params.detection_method = 'significance';
    params.threshold_A = 10;
    params.nbr_pix_per_phase = [30 90];
    params.priority_phases =       [false false false false false false];
    params.priority_min_fraction = [0 0 0 0 0 0];
    params.methode_ref_spectra = 'amplitude';

    % Paramètres spectres ROI 
    params.shift_row = 0;
    params.shift_col = 0;

        params.roi1 = [58+params.shift_row 60+params.shift_row...
        66+params.shift_col 68+params.shift_col]; %[row_start row_end col_start col_end]
    params.roi2 = [43+params.shift_row 49+params.shift_row...
        73+params.shift_col 77+params.shift_col]; %[row_start row_end col_start col_end]
    params.roi_alone = [43+params.shift_row 46+params.shift_row...
        73+params.shift_col 77+params.shift_col];

%      params.roi1 = [58+params.shift_row 60+params.shift_row...
%         66+params.shift_col 68+params.shift_col]; %[row_start row_end col_start col_end]
%     params.roi2 = [43+params.shift_row 46+params.shift_row...
%         74+params.shift_col 77+params.shift_col]; %[row_start row_end col_start col_end]
    
    % params.roi1 = [58+params.shift_row 60+params.shift_row...
    % 66+params.shift_col 68+params.shift_col]; 
    % params.roi2 = [44+params.shift_row 50+params.shift_row...
    % 71+params.shift_col 78+params.shift_col]; 

    % params.roi1 = [58+params.shift_row 60+params.shift_row...
    %     66+params.shift_col 68+params.shift_col]; %[row_start row_end col_start col_end]
    % params.roi2 = [98+params.shift_row 105+params.shift_row...
    %     4+params.shift_col 8+params.shift_col]; %[row_start row_end col_start col_end]

    params.roi_alone = [46+params.shift_row 50+params.shift_row...
        95+params.shift_col 100+params.shift_col];



    % params.colors_roi = [0.85 0.20 0.10; 0.10 0.10 0.10];
    % params.phase_colors = [0, 0.4470, 0.7410; 1, 0.5, 0];
    params.colors_roi = [0.85 0.20 0.10; 0.10 0.10 0.10];
    params.phase_colors = [
        0, 0.4470, 0.7410;  % Bleu 
        1, 0.5, 0;         % Orange 
        0, 0.7, 0.3        % Vert 
    ];


    params.nu_interval = [1075 1095];

    % Paramètres d'affichage
    params.load_pixel_fit = false;
    params.calcul_fwhm_instr = true;
    params.do_noise_study = true;
    params.do_lsqnonneg_treatment = false;
    params.display_intensity_maps = true;
    params.display_figures = true;
    params.plot_ref_spectra = true;
    params.plot_pixel_fits = true;
    params.display_fit = true;
    params.do_ref_spectrum_analysis = true; 
    params.do_ref_roi_analysis = false;
    params.do_ref_roi_alone_analysis = false;
    params.compare_2ps_7ps = false;
    params.compare_acquisition = false;
    params.display_fit_stat = true;
    params.display_R2_stat = false;

    %sauvegarde
    params.exportgraphics_segm_roi = false;

end