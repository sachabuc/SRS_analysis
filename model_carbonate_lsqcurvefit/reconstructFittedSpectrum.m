function I_model = reconstructFittedSpectrum(pf, phase_model, active_idx, wavenumber, fwhm_instr)
%RECONSTRUCTFITTEDSPECTRUM Reconstruit le spectre modele a partir des
%parametres DEJA AJUSTES d'un pixel (pf = pixel_fit(iy,ix)), sans
%repasser par lsqcurvefit -- utile pour verifier visuellement un fit
%apres coup (ex : PLOT_PIXEL_FITS_FROM_REF_SPECTRA).
%
%   I_model = RECONSTRUCTFITTEDSPECTRUM(pf, phase_model, active_idx, ...
%       wavenumber, fwhm_instr)
%
%   pf.nu{k} et pf.FWHM{k} contiennent deja soit la valeur ajustee, soit
%   la valeur fixee (selon nu_is_variable/FWHM_is_variable au moment du
%   fit) -- donc reutilisables directement ici sans distinction de cas.
    sigma_inst = fwhm2sigma(fwhm_instr);
    I_model = pf.background * ones(size(wavenumber));

    for a = 1:numel(active_idx)
        k = active_idx(a);
        A    = pf.A(k);
        nu   = pf.nu{k};
        FWHM = pf.FWHM{k};

        ratio = phase_model(k).ratio;
        ratio = ratio/sum(ratio);

        G = zeros(size(wavenumber));
        for p = 1:numel(nu)
            sigma_phase = fwhm2sigma(FWHM(p));
            sigma_eff   = sqrt(sigma_phase^2 + sigma_inst^2);
            G = G + ratio(p) * gaussianArea(wavenumber, nu(p), sigma_eff);
        end

        I_model = I_model + A*G;
    end
end
