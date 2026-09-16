function figIntensityRatioACCvsCAL(phase_model, material_ratios)
% Figure 3 : rapport des hauteurs de pic I_ACC/I_CAL en fonction de
% fwhm_instr, pour plusieurs rapports de quantite de matiere A_ACC/A_CAL
% supposes. Utilise directement les nu/FWHM de phase_model (independant
% de use_ACC/use_CAL pour cet appel precis) :
%
%   I_ACC/I_CAL = (A_ACC/A_CAL) * (sigma_eff_CAL / sigma_eff_ACC)
%
% ou sigma_eff_X = sqrt(sigma_phase_X^2 + sigma_inst^2). Le premier
% facteur (rapport de matiere) est fixe par courbe ; c'est le second,
% dependant de fwhm_instr, qui porte l'effet.
 
    k_CAL = find(strcmp({phase_model.name}, "CAL"), 1);
    k_ACC = find(strcmp({phase_model.name}, "ACC"), 1);
 
    if isempty(k_CAL) || isempty(k_ACC)
        warning('figIntensityRatioACCvsCAL:missingPhase', ...
            'Phase CAL ou ACC introuvable dans phase_model -- figure ignoree.');
        return
    end
 
    sigma_phase_CAL = fwhm2sigma(phase_model(k_CAL).FWHM(1));
    sigma_phase_ACC = fwhm2sigma(phase_model(k_ACC).FWHM(1));
 
    fwhm_instr_range = linspace(0, 20, 200);
 
    figure('Color','white','Position',[100 100 900 650]);
    hold on;
 
    colors = lines(numel(material_ratios));
 
    for i = 1:numel(material_ratios)
        r = material_ratios(i);
 
        sigma_inst_range = arrayfun(@fwhm2sigma, fwhm_instr_range);
        sigma_eff_CAL = sqrt(sigma_phase_CAL^2 + sigma_inst_range.^2);
        sigma_eff_ACC = sqrt(sigma_phase_ACC^2 + sigma_inst_range.^2);
 
        ratio_curve = r * sigma_eff_CAL ./ sigma_eff_ACC;
 
        plot(fwhm_instr_range, ratio_curve, 'LineWidth', 2.5, 'Color', colors(i,:), ...
             'DisplayName', sprintf('A_{ACC}/A_{CAL} = %.2g', r));
    end
 
    xlabel('fwhm\_instr','FontSize',12);
    ylabel('I_{ACC} / I_{CAL}  (rapport des hauteurs de pic)','FontSize',12);
    title('Rapport d''intensite ACC/CAL vs largeur instrumentale','FontSize',13);
    legend('Location','best');
    grid on; box on; set(gca,'FontSize',11);
 
end
% Figure 2 : spectre total (analytique) pour plusieurs valeurs de
% fwhm_instr, pour visualiser l'effet de la reponse instrumentale sur la
% resolution spectrale du modele.