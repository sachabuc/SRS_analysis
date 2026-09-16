%% Initialisation
clear all;
close all;

%% Charger les paramètres
params = parameters_260713_corals_7ps_ter();

%% Ajouter les chemins des fonctions
for i = 1:length(params.function_paths)
    addpath(params.function_paths{i});
end

%% Exécution du pipeline
% 1. Chargement des données
[imgs, acq] = loadSRSImageStack(params.main_dir, params.sub_dir, ...
    params.n_depart, params.wavenumber);
I_raw = squeeze(imgs);

%% 2. Mesure de la FWHM 
if params.calcul_fwhm_instr
    [FWHM_mesure, FWHM_error, fit_result, ROI_background, ROI_phase] = ...
        measure_reference_FWHM(I_raw, params.wavenumber);

    [~,fwhm_instr] = deconvolve(FWHM_mesure, params.fwhm_ref, 0);
else 
    FWHM_mesure = params.fwhm_mesure;

    [~,fwhm_instr] = deconvolve(FWHM_mesure, params.fwhm_ref, 0);
end

%% 3. Soustraction du fond
[I_corr, background_spectrum, noise_map, noise_global] = ...
    estimate_background_noise_roi(I_raw, params.wavenumber,...
    params.x1_s, params.x1_e, params.x2_s, params.x2_e);

%% 4. Étude du bruit (si activé)
if params.do_noise_study
    [fit_params, mean_noise] = noise_study(I_corr, params.wavenumber,...
        background_spectrum, params.idl, params.idc, params.wi, ...
        params.xl_s, params.xl_e, params.xc_s, params.xc_e);
end
% %%
% [I_corr, background_spectrum, noise_spectral, ...
%           noise_spatial, fit_params] = ...
%     estimate_background_noise_final(imgs, params.wavenumber, ...
%                               params.x1_s, params.x1_e, params.x2_s, params.x2_e, ...
%                               params.wi, params.idl, params.idc);

%% 5. Affichage des images principales
if params.display_intensity_maps
    plot_srs_images(I_corr, params.ni, params.Imin, params.Imax,...
        params.titles, params.diff_ranges)
end

%% 6. Modèle théorique des phases
[phase_model] = model_carbonate_phases(...
    fwhm_instr, params.use_CAL, params.use_ARA, params.use_VAT, ...
    params.use_ACC, params.use_CCHH, params.use_MHC, true);

%% 7. Initialisation linéaire
pixel_init = init_pixel_amplitudes(...
    I_corr, phase_model, params.wavenumber, ...
    params.R2_init, params.threshold_sigma_init, true);

%% 8. Fit non linéaire
if params.load_pixel_fit
    % Vérifier si le fichier existe
    loaded_data = load(params.path2pixel_fit);
    pixel_fit = loaded_data.pixel_fit;
else
    % Si params.load_pixel_fit est false, calculer pixel_fit avec fit_pixel_phases
    pixel_fit = fit_pixel_phases(...
        I_corr, phase_model, params.wavenumber, pixel_init, ...
        params.nu_is_variable, params.FWHM_is_variable, fwhm_instr, ...
        params.nu_LB, params.nu_UB, params.FWHM_LB, params.FWHM_UB, ...
        params.lineshape_type, params.ci_alpha, params.display_figures);
end
%% 9. Segmentation / quantification
[phase_map, composition_map] = segment_carbonate_phases(...
    I_corr, pixel_fit, phase_model, noise_map, ...
    params.R2_min_final, params.threshold_sigma_final, ...
    params.min_points_above_noise,params.alpha_dominance,...
    params.dominance_phases,params.priority_phases,...
    params.priority_min_fraction, params.display_figures);


%% 10. Affichage des spectres de référence
ref_spectra = plot_phase_reference_spectra(...
    I_corr, params.wavenumber, pixel_fit, phase_map, phase_model, ...
    params.phase2plot, params.nbr_pix_per_phase, fwhm_instr, params.display_fit);

if params.plot_pixel_fits
    plot_pixel_fits_from_ref_spectra( ...
          ref_spectra, I_corr, params.wavenumber, pixel_fit, phase_model, ...
          fwhm_instr, 12);
end

%% 11. Comparaison avec les spectres 7ps
if params.compare_acquisition 
    ref_spectra_7ps = load(params.path2ref_spectra_7ps);
    ref_spectra_shifted = extract_shifted_reference_spectra(...
        ref_spectra_7ps, params.wavenumber_7ps, I_corr, params.wavenumber, ...
        phase_model, params.shift_row, params.shift_col, fwhm_instr, pixel_fit, ...
        false, false);
end
%% 12. Statistiques
if params.display_fit_stat
    fprintf('\n============================================================\n');
    fprintf('          STATISTIQUES DES SPECTRES DE REFERENCE\n');
    fprintf('============================================================\n');
    display_reference_statistics(ref_spectra, fwhm_instr);

    if params.compare_acquisition
        fprintf('\n============================================================\n');
        fprintf('      STATISTIQUES DES SPECTRES DE REFERENCE SHIFTED\n');
        fprintf('============================================================\n');
        display_reference_statistics(ref_spectra_shifted, fwhm_instr);
    end

end

% 13. Statistiques sur R²
if params.display_R2_stat
    stats = analyze_R2(pixel_fit, phase_model, params.display_figures);
end

%% 14. Traitement lsqnonneg (si activé)
if params.do_lsqnonneg_treatment
    [phase_map, A_maps, ratio_maps] = ...
        map_carbonate_phases(...
        I_corr, params.wavenumber, params.n_ch, fwhm_instr, ...
        true, false, false, false, false, true, ...
        params.threshold_sigma, 3, 0.5, true, params.sub_dir_save, ...
        params.R2_min, 10);
end

%% 15. Sauvegarde des résultats
    %saveDataOrImage(myStruct, 'results/structures', 'Name', 'my_struct', 'Format', 'mat');
    %saveDataOrImage(myImage, 'results/images', 'Name', 'my_image', 'Format', 'png');

saveDataOrImage(phase_model, params.results_dir, 'Name', 'phase_model');
saveDataOrImage(pixel_fit, params.results_dir, 'Name', 'pixel_fit');
saveDataOrImage(ref_spectra, params.results_dir, 'Name', 'ref_spectra');