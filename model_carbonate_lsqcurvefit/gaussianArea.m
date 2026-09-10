function G = gaussianArea(wavenumber, nu, sigma)
% Gaussienne normalisee en aire (integrale = 1), centree en nu, d'ecart
% type sigma, evaluee sur la grille wavenumber.
    if sigma > 0
        G = exp(-(wavenumber-nu).^2/(2*sigma^2)) / (sigma*sqrt(2*pi));
    else
        % Raie infiniment fine : delta de Dirac discretise (evite /0).
        G = zeros(size(wavenumber));
        [~, idx] = min(abs(wavenumber-nu));
        dw = wavenumber(2)-wavenumber(1);
        G(idx) = 1/dw;
    end
end