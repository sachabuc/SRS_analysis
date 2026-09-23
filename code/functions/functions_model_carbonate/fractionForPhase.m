function frac = fractionForPhase(pf, active_idx, k)
% Fraction de composition de la phase k sur ce pixel -- meme quantite
% que priority_min_fraction dans SEGMENT_CARBONATE_PHASES (amplitudes
% positives des phases actives, normalisees par leur somme).
    A_active = pf.A(active_idx);
    A_pos = max(A_active, 0);
    total = sum(A_pos);
    if total <= 0
        frac = 0;
    else
        frac = max(pf.A(k), 0) / total;
    end
end