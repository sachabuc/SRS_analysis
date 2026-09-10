function summary = compare_phase_detectability_vs_tau(mat_files)
%COMPARE_PHASE_DETECTABILITY_VS_TAU Compare, entre plusieurs acquisitions
%a tau_instrumental different, la detectabilite de chaque phase, a
%partir des ref_spectra sauvegardes par PLOT_PHASE_REFERENCE_SPECTRA.
%
%   summary = COMPARE_PHASE_DETECTABILITY_VS_TAU(mat_files)
%
%   Charge chaque fichier .mat de mat_files (un par acquisition), lit sa
%   variable ref_spectra, et regroupe les resultats par NOM de phase
%   (donc peu importe l'ordre dans lequel les phases apparaissent d'un
%   fichier a l'autre). Trace 4 metriques en fonction de tau_fwhm :
%
%     - Aire ajustee (A_mean de la phase elle-meme)      -- "controle" :
%       devrait rester stable si le fit reste fiable
%     - Hauteur de pic mesuree (max du spectre moyen - fond)  -- la
%       quantite qui s'effondre pour une phase etroite (ex CAL) quand
%       tau_instrumental grandit, contrairement a une phase large (ex ACC)
%     - Taille du pool (nb de pixels ou la phase est dominante, AVANT
%       troncature a n_top)  -- proxy direct de detectabilite
%     - R^2 du pixel le moins bon garde  -- tendance de qualite du fit
%
%   ENTREE
%     mat_files : cell array de chemins vers des fichiers .mat contenant
%                 chacun une variable ref_spectra (issue d'un appel a
%                 PLOT_PHASE_REFERENCE_SPECTRA sur une acquisition
%                 donnee, avec son propre tau_fwhm)
%
%   SORTIE
%     summary : structure, une entree par NOM de phase rencontre :
%                 .name
%                 .tau_fwhm         (trie croissant)
%                 .A_own            amplitude propre de la phase
%                 .peak_height_meas hauteur de pic mesuree (donnees)
%                 .peak_height_theo hauteur de pic theorique (NaN si
%                                   show_theoretical=false a la generation)
%                 .n_used, .n_pool
%                 .R2_worst_used
%
%   NOTE : les fichiers plus anciens generes avant l'ajout du champ
%   n_pool donneront NaN pour cette metrique -- relancez
%   PLOT_PHASE_REFERENCE_SPECTRA si vous en avez besoin.
 
%% ================================================================
% 1. Chargement et mise a plat de toutes les entrees, tous fichiers confondus
 
all_entries = struct('name', {}, 'phase_idx', {}, 'tau_fwhm', {}, ...
    'A_own', {}, 'peak_height_meas', {}, 'peak_height_theo', {}, ...
    'n_used', {}, 'n_pool', {}, 'R2_worst_used', {});
 
for f = 1:numel(mat_files)
    loaded = load(mat_files{f}, 'ref_spectra');
    rs = loaded.ref_spectra;
 
    for i = 1:numel(rs)
        if rs(i).n_used == 0
            continue
        end
 
        entry.name       = rs(i).name;
        entry.phase_idx   = rs(i).phase_idx;
        entry.tau_fwhm    = rs(i).tau_fwhm;
        entry.A_own       = rs(i).A_mean(rs(i).phase_idx);
        entry.peak_height_meas = max(rs(i).mean_spectrum) - rs(i).background_mean;
 
        if all(~isnan(rs(i).theoretical_spectrum))
            entry.peak_height_theo = max(rs(i).theoretical_spectrum) - rs(i).background_mean;
        else
            entry.peak_height_theo = NaN;
        end
 
        entry.n_used = rs(i).n_used;
        if isfield(rs(i), 'n_pool')
            entry.n_pool = rs(i).n_pool;
        else
            entry.n_pool = NaN;
        end
        entry.R2_worst_used = rs(i).R2_worst_used;
 
        all_entries(end+1) = entry; %#ok<AGROW>
    end
end
 
assert(~isempty(all_entries), 'Aucune entree exploitable dans les fichiers fournis.');
 
%% ================================================================
% 2. Regroupement par nom de phase, trie par tau croissant
 
names = unique({all_entries.name}, 'stable');
summary = struct([]);
 
for p = 1:numel(names)
    mask = strcmp({all_entries.name}, names{p});
    sub  = all_entries(mask);
 
    [tau_sorted, order] = sort([sub.tau_fwhm]);
 
    summary(p).name             = names{p};
    summary(p).tau_fwhm          = tau_sorted;
    summary(p).A_own             = [sub(order).A_own];
    summary(p).peak_height_meas   = [sub(order).peak_height_meas];
    summary(p).peak_height_theo   = [sub(order).peak_height_theo];
    summary(p).n_used             = [sub(order).n_used];
    summary(p).n_pool             = [sub(order).n_pool];
    summary(p).R2_worst_used      = [sub(order).R2_worst_used];
end
 
%% ================================================================
% 3. Affichage
 
plotDetectabilityVsTau(summary);
 
end
 
 