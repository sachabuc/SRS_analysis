function colors = defaultPhaseColors(n_phases)
% Couleurs par phase, bien separees en teinte (espacement regulier sur
% la roue HSV) -- plus fiable que linhttps://chatgpt.com/codexes() au-dela de quelques couleurs,
% et stable par phase (l'ordre suit toujours phase_model, independant
% du sous-ensemble reellement actif d'un run a l'autre).
    hues = (0:n_phases-1)' / n_phases;
    colors = hsv2rgb([hues, 0.85*ones(n_phases,1), 0.90*ones(n_phases,1)]);
end