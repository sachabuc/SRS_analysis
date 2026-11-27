%% Initialisation
clear all;
close all;
   
%% Charger les paramètres
params = parameters_SRS_v1_cocco_261127_Hux_cell(); 

%% Ajouter les chemins des fonctions
for i = 1:length(params.function_paths)
    addpath(params.function_paths{i});
end
 
%% 1. Chargement des données

SRS = load_SRS_TIFF_only(params.main_dir, params.cfg);

 


%% 2. Display Images 

fig = display_SRS_images(SRS.data,SRS.metadata, params);

%% 3. Noise study 

% ROI rectangular : [x1 x2 y1 y2] 

[data_corr, noise_matrix, background_matrix] = ...
    correct_SRS_background(SRS.data, params.ROI_background, params);


 
%% 4. First analysis - Images subtraction 
% 
[results_compare, fig] = compare_carbonate_images( ...
    data_corr, SRS.wavenumber, params.intervals, params);

% [results_compare, fig] = compare_carbonate_images_v2(data_corr, SRS.wavenumber, params.intervals,  background_matrix,params);
 
%%

cfg.T = -1;
cfg.nGauss=1;
cfg.subtractBackground  = false;

SRS.data = data_corr;

results_analyze_roi = analyze_SRS_TIFF_ROI(SRS,cfg);

%% 5. drift analysis 
% image de dimension X Y 1 1 T
% results = analyze_XY_image_drift(data_corr(:,:,1,1,1));


%%%%%%%%%%%%%%%%%%%%% 6. Fit and segmentation %%%%%%%%%%%%%%%%%%%%%%%%%% 

%% 2. Mesure de la FWHM 

% data_corr = data_corr(:,:,:,7,1);
% 
% if params.calcul_fwhm_instr
%     [FWHM_mesure, FWHM_error, fit_result, ROI_background, ROI_phase] = ...
%         measure_reference_FWHM(data_corr, SRS.wavenumber);
% 
%     [~,fwhm_instr] = deconvolve(FWHM_mesure, params.fwhm_ref, 0); 
%     % deconvolve(fwhm_mesure, fwhm_phase, fwhm_inst)
% else 
%     FWHM_mesure = params.fwhm_mesure;
% 
%     [~,fwhm_instr] = deconvolve(FWHM_mesure, params.fwhm_ref, 0);
%     % deconvolve(fwhm_mesure, fwhm_phase, fwhm_inst)
% end
% 
% % fwhm_instr = params.fwhm_instr;
% 
% 
% %%
% [I_corr, background_spectrum, noise_map, spatial_dispersion_bg_global, spatial_dispersion_bg] = ...
%     estimate_background_noise_roi(I_raw, params.wavenumber,...
%     params.x1_s, params.x1_e, params.x2_s, params.x2_e);
% 
% %% 6. Modèle théorique des phases
% [phase_model] = model_carbonate_phases(...
%     fwhm_instr, params.use_CAL, params.use_ARA, params.use_VAT, ...
%     params.use_ACC, params.use_CCHH, params.use_MHC, true);
% 
% %% 7. Initialisation linéaire
% pixel_init = init_pixel_amplitudes(...
%     data_corr, phase_model, SRS.wavenumber, ...
%     params.R2_init, params.threshold_sigma_init, true);
% 
% %% 8. Fit non linéaire
% if params.load_pixel_fit
%     % Vérifier si le fichier existe
%     loaded_data = load(params.path2pixel_fit);
%     pixel_fit = loaded_data.pixel_fit;
% else
%     % Si params.load_pixel_fit est false, calculer pixel_fit avec fit_pixel_phases
%     pixel_fit = fit_pixel_phases(...
%         data_corr, phase_model, SRS.wavenumber, pixel_init, ...
%         params.nu_is_variable, params.FWHM_is_variable, fwhm_instr, ...
%         params.nu_LB, params.nu_UB, params.FWHM_LB, params.FWHM_UB, ...
%         params.lineshape_type, params.ci_alpha, params.display_figures);
% 
%         saveDataOrImage(pixel_fit, params.results_dir, 'Name', 'pixel_fit');
% 
% end
% 
% active_idx = find([phase_model.use]);
% plotFitMaps(pixel_fit, phase_model, active_idx);
% 
% %% 9. Segmentation / quantification
% [phase_map, composition_map] = segment_carbonate_phases(...
%     data_corr, pixel_fit, phase_model, noise_map, ...
%     params.R2_min_final, params.threshold_sigma_final, ...
%     params.min_points_above_noise,params.alpha_dominance,...
%     params.dominance_phases,params.priority_phases,...
%     params.priority_min_fraction, params.display_figures, ...
%     params.phase_colors);
% 
% 
% %% 10. Spectres de référence
% 
% if params.do_ref_spectrum_analysis
% 
%     ref_spectra = plot_phase_reference_spectra(...
%         params,data_corr, SRS.wavenumber, pixel_fit, phase_map, phase_model, spatial_dispersion_bg_global, ...
%         active_idx, params.nbr_pix_per_phase, fwhm_instr,...
%         true,'',params.methode_ref_spectra,params.priority_phases);
% 
%     plot_pixel_fits_from_ref_spectra( ...
%           ref_spectra, data_corr, SRS.wavenumber, pixel_fit, phase_model, ...
%           fwhm_instr, 12);
% 
%     saveDataOrImage(ref_spectra, params.results_dir, 'Name', 'ref_spectra');
% 
% 
%     if params.display_fit_stat
%         fprintf('\n============================================================\n');
%         fprintf('          STATISTIQUES DES SPECTRES DE REFERENCE\n');
%         fprintf('============================================================\n');
%         display_reference_statistics(ref_spectra, fwhm_instr);
% 
%         if params.compare_2ps_7ps
%             fprintf('\n============================================================\n');
%             fprintf('      STATISTIQUES DES SPECTRES DE REFERENCE SHIFTED\n');
%             fprintf('============================================================\n');
%             display_reference_statistics(ref_spectra_compare, ref_spectra_compare(1).fwhm_instr);
%         end
% 
%     end
% 
% end
% 
% 
% %% 11. Spectres ROIs 
% 
% if params.do_ref_roi_analysis 
% 
%     ref_roi = plot_phase_reference_ROI_scaled( ...
%         data_corr,SRS.wavenumber, phase_model, phase_map,spatial_dispersion_bg_global, ...
%         params.roi1, params.roi2,fwhm_instr, active_idx, ...
%         params.phase_colors, params.colors_roi, params.figures_dir, ...
%         params.exportgraphics_segm_roi, 500, params.results_dir,params);
% 
% %     ref_roi = plot_phase_reference_ROI_VAT( ...
% %         data_corr,params.wavenumber, phase_model, phase_map,spatial_dispersion_bg_global, ...
% %         params.roi1, params.roi2,fwhm_instr, active_idx, ...
% %         params.phase_colors, params.colors_roi, params.figures_dir, ...
% %         params.exportgraphics_segm_roi, 500, params.results_dir,params);
% 
%     I_sum = plot_wavenumber_sum_ROI( ...
%         data_corr, SRS.wavenumber, params.nu_interval, ...
%         ref_roi, params.colors_roi);
% 
%     saveDataOrImage(ref_roi, params.results_dir, 'Name', 'ref_roi');
% 
%     if params.compare_2ps_7ps
% 
%         loaded_data = load(params.path2ref_roi_compare);
%         ref_roi_compare = loaded_data.ref_roi;
%         plot_compare_ref_roi(ref_roi,ref_roi_compare,params) 
% 
%     end
% 
% end
% %% One ROI 
% 
% if params.do_ref_roi_alone_analysis 
% 
%     % roi_alone_result = plot_single_ROI_fit( ...
%     %     data_corr, params.wavenumber, phase_model, params.roi_alone, ...
%     %     fwhm_instr, spatial_dispersion_bg_global, spatial_dispersion_bg,active_idx,...
%     %     params.phase_colors, params);
% 
%     roi_alone_result = plot_single_ROI_fit_errorbars( ...
%         data_corr, SRS.wavenumber, phase_model, params.roi_alone, ...
%         fwhm_instr, spatial_dispersion_bg_global, spatial_dispersion_bg,active_idx,...
%         params.phase_colors, params);
% 
%     I_sum_alone = plot_wavenumber_sum_ROI( ...
%         data_corr, SRS.wavenumber, params.nu_interval, roi_alone_result, params.colors_roi);
% 
%     % if params.compare_2ps_7ps
%     % 
%     %     loaded_data = load(params.path2ref_roi_compare);
%     %     ref_roi_compare = loaded_data.ref_roi;
%     %     plot_compare_ref_roi(roi_alone_result,ref_roi_compare,params) 
%     % 
%     % end
% end
% 
% 
% 
% 
% %% 12. Compare
% 
% roi_fits = get_roi_pixel_fits( ...
%     pixel_fit, ...
%     phase_model, ...
%     SRS.wavenumber, ...
%     fwhm_instr, ...
%     params.roi1, ...
%     params.roi2, ...
%     active_idx, ...
%     data_corr, ...
%     true);
% 
% % if params.compare_acquisition 
% %     ref_spectra_7ps = load(params.path2ref_spectra_7ps);
% %     ref_spectra_shifted = extract_shifted_reference_spectra(...
% %         ref_spectra_7ps, params.wavenumber_7ps, data_corr, params.wavenumber, ...
% %         phase_model, params.shift_row, params.shift_col, fwhm_instr, pixel_fit, ...
% %         false, false);
% % end
% 
% %% 13. Statistiques sur R²
% if params.display_R2_stat
%     stats = analyze_R2(pixel_fit, phase_model, params.display_figures);
% end
% 
% %% 14. Traitement lsqnonneg (si activé)
% if params.do_lsqnonneg_treatment
%     [phase_map, A_maps, ratio_maps] = ...
%         map_carbonate_phases(...
%         data_corr, SRS.wavenumber, fwhm_instr, ...
%         true, false, false, false, false, true, ...
%         params.threshold_sigma, 3, 0.5, true, params.sub_dir_save, ...
%         params.R2_min, 10);
% end
% 
% %% 15. Sauvegarde des résultats
%     %saveDataOrImage(myStruct, 'results/structures', 'Name', 'my_struct', 'Format', 'mat');
%     %saveDataOrImage(myImage, 'results/images', 'Name', 'my_image', 'Format', 'png');
% 
% saveDataOrImage(phase_model, params.results_dir, 'Name', 'phase_model');
% 

