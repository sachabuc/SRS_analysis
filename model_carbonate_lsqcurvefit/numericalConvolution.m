function G_num = numericalConvolution(wavenumber, dw, G_raw, sigma_inst)
% Convolution NUMERIQUE explicite de G_raw (spectre non elargi, evalue
% sur `wavenumber`, pas dw) par un noyau instrumental gaussien d'ecart
% type sigma_inst. Sert de reference pour valider le calcul analytique.
    if sigma_inst <= 0
        G_num = G_raw;
        return
    end
 
    n_half    = ceil(max(5*sigma_inst, dw) / dw);   % noyau symetrique, longueur impaire
    wn_kernel = (-n_half:n_half) * dw;
    kernel    = exp(-wn_kernel.^2/(2*sigma_inst^2));
    kernel    = kernel/(sum(kernel)*dw);             % aire du noyau = 1
 
    G_num = conv(G_raw, kernel, 'same') * dw;
end