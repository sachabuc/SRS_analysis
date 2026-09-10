function G = lineShapeArea(wavenumber, nu, width, lineshape_type)
%LINESHAPEAREA Dispatcher pour la forme de raie utilisee dans le fit.
%
%   G = LINESHAPEAREA(wavenumber, nu, width, lineshape_type)
%
%   'width' est l'ecart-type (sigma) pour 'gaussian'. Le sens de 'width'
%   dependra de la forme choisie (ex : demi-largeur gamma pour un futur
%   'lorentzian') -- c'est a l'appelant de fournir la bonne quantite.
%
%   Point d'extension : pour ajouter une nouvelle forme de raie plus
%   tard (lorentzienne, Voigt...), ajouter un nouveau cas ici et une
%   fonction dediee (ex : lorentzianArea.m), sans modifier le reste du
%   pipeline de fit (FIT_PIXEL_PHASES n'a aucune connaissance de la
%   forme de raie utilisee).
    switch lineshape_type
        case 'gaussian'
                if width > 0
                    G = exp(-(wavenumber-nu).^2/(2*width^2)) / (width*sqrt(2*pi));
                else
                    % Raie infiniment fine : delta de Dirac discretise (evite /0).
                    G = zeros(size(wavenumber));
                    [~, idx] = min(abs(wavenumber-nu));
                    dw = wavenumber(2)-wavenumber(1);
                    G(idx) = 1/dw;
                end
        case 'lorentzian'
            error('lineShapeArea:notImplemented', ...
                ['Forme de raie lorentzienne pas encore implementee. ' ...
                 'Ajouter lorentzianArea.m puis completer ce cas.']);
        otherwise
            error('lineShapeArea:unknownType', ...
                'lineshape_type inconnu : %s', lineshape_type);
    end
end
