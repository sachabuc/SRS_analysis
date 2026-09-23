
function [phase_model] = model_carbonate_phases( ...
          fwhm_instr, ...
          use_CAL, ...
          use_ARA, ...
          use_VAT, ...
          use_ACC, ...
          use_CCHH, ...
          use_MHC, ...                           
          display_figures)
%% ================================================================
%MODEL_CARBONATE_PHASES Modele theorique des phases du carbonate.
%
%   [phase_model, wavenumber] = MODEL_CARBONATE_PHASES(fwhm_instr, use_ACC,
%   use_CCHH, use_MHC, use_VAT, use_ARA, use_CAL, display_figures)
%
%   Construit, pour chaque phase activee (use_xxx = true), le spectre
%   Raman theorique (somme de gaussiennes normalisees en aire) convolue
%   par la reponse instrumentale (supposee gaussienne, de largeur donnee
%   par fwhm_instr). La convolution de deux gaussiennes etant elle-meme une
%   gaussienne, elle est calculee analytiquement via :
%
%       sigma_eff(p) = sqrt(sigma_phase(p)^2 + sigma_inst^2)
%
%   Si display_figures = true, deux figures sont produites :
%     1) Comparaison du modele analytique (formule ci-dessus) avec un
%        modele numerique obtenu par convolution discrete explicite
%        (conv() avec un noyau instrumental gaussien), pour valider la
%        formule analytique.
%     2) Spectre total (somme des phases actives) pour plusieurs valeurs
%        de tau_fwhm (2 a 14 ps), pour visualiser l'effet de la reponse
%        instrumentale sur la resolution spectrale.
%
%   ENTREES
%     fwhm_instr          : FWHM (cm-1) de la reponse instrumentale utilisee
%                          pour le modele principal (celui retourne dans
%                          phase_model). fwhm_instr <= 0 -> pas
%                          d'elargissement instrumental.
%     use_ACC...use_CAL : booleens activant/desactivant chaque phase.
%     display_figures   : booleen, affiche ou non les figures de controle.
%
%   SORTIES
%     phase_model : structure (1x6), une entree par phase, avec les
%                   champs .name .nu .FWHM .ratio .use .A .sigma_eff
%                   .G_analytical (spectre de la phase sur `wavenumber`,
%                   rempli seulement si .use = true)
%     wavenumber  : grille de nombre d'onde (cm^-1) sur laquelle
%                   phase_model(:).G_analytical est evalue.
 
%% ================================================================
% 1. Definition des phases
% (ordre reel utilise ici : 1=CAL 2=ARA 3=VAT 4=ACC 5=CCHH 6=MHC)
 
phase_model(1).name  = "CAL";
phase_model(1).nu    = 1085.5;
% phase_model(1).nu    = 1085.3;
phase_model(1).FWHM  = 3.5;
% phase_model(1).FWHM  = 4.3;
phase_model(1).ratio = 1;
phase_model(1).use   = use_CAL;
 
phase_model(2).name  = "ARA";
phase_model(2).nu    = 1086;
phase_model(2).FWHM  = 3.5;
phase_model(2).ratio = 1;
phase_model(2).use   = use_ARA;
 
phase_model(3).name  = "VAT";
phase_model(3).nu    = [1075 1080 1090.8];
phase_model(3).FWHM  = [8 8 8];
phase_model(3).ratio = [0.4 0.3 1];
phase_model(3).use   = use_VAT;
 
phase_model(4).name  = "ACC";
phase_model(4).nu    = 1077;
% phase_model(4).nu    = 1080;
phase_model(4).FWHM  = 35;
% phase_model(4).FWHM  = 30;
phase_model(4).ratio = 1;
phase_model(4).use   = use_ACC;
 
phase_model(5).name  = "CCHH";
phase_model(5).nu    = 1097;
phase_model(5).FWHM  = 6.3;
phase_model(5).ratio = 1;
phase_model(5).use   = use_CCHH;
 
phase_model(6).name  = "MHC";
phase_model(6).nu    = 1067.5;
phase_model(6).FWHM  = 5.8;
phase_model(6).ratio = 1;
phase_model(6).use   = use_MHC;
 
% Amplitude relative de chaque phase, utilisee UNIQUEMENT pour les
% graphes de controle de cette fonction (poids de visualisation = 1 par
% defaut, ce n'est pas un resultat de fit). La future fonction de fit sur
% les donnees experimentales pourra ecraser ce champ avec la
% concentration reelle estimee.

for k = 1:numel(phase_model)
    phase_model(k).A            = 1;
    phase_model(k).sigma_eff    = [];
    phase_model(k).G_analytical = [];
end

% phase_model(4).A = 1;
 
%% ================================================================
% 2. Grille theorique
 
wn_min = 1040;
wn_max = 1130;
dw     = 0.05;
 
wavenumber = wn_min:dw:wn_max;
 
%% ================================================================
% 3. Reponse instrumentale (modele principal)

sigma_inst = fwhm2sigma(fwhm_instr);
 
%% ================================================================
% 4. Modele analytique (sigma_eff) pour chaque phase active
 
for k = 1:numel(phase_model)
 
    if ~phase_model(k).use
        continue
    end
 
    [G, sigma_eff] = analyticalPhaseSpectrum( ...
        wavenumber, phase_model(k).nu, phase_model(k).FWHM, ...
        phase_model(k).ratio, sigma_inst);
 
    phase_model(k).sigma_eff    = sigma_eff;
    phase_model(k).G_analytical = G;
end
 
%% ================================================================
% 5. AFFICHAGE

 
if display_figures
 
    figCompareAnalyticalNumerical(phase_model, wavenumber, dw, sigma_inst, fwhm_instr);
 
    tau_list_ps = [10 7 4];
    figMultiTau(phase_model, wavenumber, tau_list_ps);


    material_ratios = [];
    figIntensityRatioACCvsCAL(phase_model, material_ratios);
 
end
 
end
 
% function [phase_model, wavenumber] = model_carbonate_phases( ...
%           fwhm_instr, ...
%           use_ACC, ...
%           use_CCHH, ...
%           use_MHC, ...
%           use_VAT, ...
%           use_ARA, ...
%           use_CAL, ...
%           display_figures, ...
%           material_ratios)
% %MODEL_CARBONATE_PHASES Modele theorique des phases du carbonate.
% %
% %   [phase_model, wavenumber] = MODEL_CARBONATE_PHASES(fwhm_instr, use_ACC,
% %   use_CCHH, use_MHC, use_VAT, use_ARA, use_CAL, display_figures, ...
% %   material_ratios)
% %
% %   Construit, pour chaque phase activee (use_xxx = true), le spectre
% %   Raman theorique (somme de gaussiennes normalisees en aire) convolue
% %   par la reponse instrumentale (supposee gaussienne, de largeur donnee
% %   par fwhm_instr). La convolution de deux gaussiennes etant elle-meme une
% %   gaussienne, elle est calculee analytiquement via :
% %
% %       sigma_eff(p) = sqrt(sigma_phase(p)^2 + sigma_inst^2)
% %
% %   Si display_figures = true, trois figures sont produites :
% %     1) Comparaison du modele analytique (formule ci-dessus) avec un
% %        modele numerique obtenu par convolution discrete explicite
% %        (conv() avec un noyau instrumental gaussien), pour valider la
% %        formule analytique.
% %     2) Spectre total (somme des phases actives) pour plusieurs valeurs
% %        de fwhm_instr (2 a 14 ps), pour visualiser l'effet de la reponse
% %        instrumentale sur la resolution spectrale.
% %     3) Rapport des HAUTEURS DE PIC I_ACC/I_CAL en fonction de
% %        fwhm_instr, pour plusieurs rapports de quantite de matiere
% %        A_ACC/A_CAL supposes (material_ratios) -- prediction theorique
% %        independante de use_ACC/use_CAL (utilise directement les nu/FWHM
% %        de phase_model, quel que soit leur statut actif pour cet appel).
% %        Contrairement a l'amplitude (aire, quasi invariante avec
% %        fwhm_instr), la hauteur de pic A/(sigma_eff*sqrt(2*pi)) est LA
% %        quantite qui s'effondre pour une raie etroite (CAL) quand
% %        fwhm_instr grandit -- c'est elle qui porte l'effet recherche.
% %
% %   ENTREES
% %     fwhm_instr          : FWHM (ps) de la reponse instrumentale utilisee
% %                          pour le modele principal (celui retourne dans
% %                          phase_model). fwhm_instr <= 0 -> pas
% %                          d'elargissement instrumental.
% %     use_ACC...use_CAL : booleens activant/desactivant chaque phase.
% %     display_figures   : booleen, affiche ou non les figures de controle.
% %     material_ratios    : vecteur des rapports A_ACC/A_CAL supposes pour
% %                          la figure 3 (une courbe par valeur). Optionnel,
% %                          defaut [1 0.5 0.1] si omis ou [].
% %
% %   SORTIES
% %     phase_model : structure (1x6), une entree par phase, avec les
% %                   champs .name .nu .FWHM .ratio .use .A .sigma_eff
% %                   .G_analytical (spectre de la phase sur `wavenumber`,
% %                   rempli seulement si .use = true)
% %     wavenumber  : grille de nombre d'onde (cm^-1) sur laquelle
% %                   phase_model(:).G_analytical est evalue.
% 
% %% ================================================================
% % 0. Valeur par defaut
% 
% if nargin < 9 || isempty(material_ratios)
%     material_ratios = [1 0.5 0.1];
% end
% 
% %% ================================================================
% % 1. Definition des phases
% % (ordre reel utilise ici : 1=CAL 2=ARA 3=VAT 4=ACC 5=CCHH 6=MHC)
% 
% phase_model(1).name  = "CAL";
% phase_model(1).nu    = 1085.5;
% phase_model(1).FWHM  = 3.5;
% phase_model(1).ratio = 1;
% phase_model(1).use   = use_CAL;
% 
% phase_model(2).name  = "ARA";
% phase_model(2).nu    = 1086;
% phase_model(2).FWHM  = 3.5;
% phase_model(2).ratio = 1;
% phase_model(2).use   = use_ARA;
% 
% phase_model(3).name  = "VAT";
% phase_model(3).nu    = [1075 1080 1090.8];
% phase_model(3).FWHM  = [8 8 8];
% phase_model(3).ratio = [0.4 0.3 1];
% phase_model(3).use   = use_VAT;
% 
% phase_model(4).name  = "ACC";
% phase_model(4).nu    = 1077;
% phase_model(4).FWHM  = 35;
% phase_model(4).ratio = 1;
% phase_model(4).use   = use_ACC;
% 
% phase_model(5).name  = "CCHH";
% phase_model(5).nu    = 1097;
% phase_model(5).FWHM  = 6.3;
% phase_model(5).ratio = 1;
% phase_model(5).use   = use_CCHH;
% 
% phase_model(6).name  = "MHC";
% phase_model(6).nu    = 1067.5;
% phase_model(6).FWHM  = 5.8;
% phase_model(6).ratio = 1;
% phase_model(6).use   = use_MHC;
% 
% % Amplitude relative de chaque phase, utilisee UNIQUEMENT pour les
% % graphes de controle de cette fonction (poids de visualisation = 1 par
% % defaut, ce n'est pas un resultat de fit). La future fonction de fit sur
% % les donnees experimentales pourra ecraser ce champ avec la
% % concentration reelle estimee.
% 
% for k = 1:numel(phase_model)
%     phase_model(k).A            = 1;
%     phase_model(k).sigma_eff    = [];
%     phase_model(k).G_analytical = [];
% end
% 
% % phase_model(4).A = 1;
% 
% %% ================================================================
% % 2. Grille theorique
% 
% wn_min = 1050;
% wn_max = 1150;
% dw     = 0.05;
% 
% wavenumber = wn_min:dw:wn_max;
% 
% %% ================================================================
% % 3. Reponse instrumentale (modele principal)
% 
% sigma_inst = fwhm2sigma(fwhm_instr);
% 
% %% ================================================================
% % 4. Modele analytique (sigma_eff) pour chaque phase active
% 
% for k = 1:numel(phase_model)
% 
%     if ~phase_model(k).use
%         continue
%     end
% 
%     [G, sigma_eff] = analyticalPhaseSpectrum( ...
%         wavenumber, phase_model(k).nu, phase_model(k).FWHM, ...
%         phase_model(k).ratio, sigma_inst);
% 
%     phase_model(k).sigma_eff    = sigma_eff;
%     phase_model(k).G_analytical = G;
% end
% 
% %% ================================================================
% % 5. AFFICHAGE
% %% ================================================================
% 
% if display_figures
% 
%     figCompareAnalyticalNumerical(phase_model, wavenumber, dw, sigma_inst, fwhm_instr);
% 
%     tau_list_ps = [2 4 6 8 10 12 14];
%     figMultiTau(phase_model, wavenumber, tau_list_ps);
% 
%     figIntensityRatioACCvsCAL(phase_model, material_ratios);
% 
% end
% 
% end
% 
% 