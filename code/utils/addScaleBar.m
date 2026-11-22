
function h = addScaleBar(ax, pixelSizeX, FOV_X_um, varargin)
%ADDSCALEBAR Ajoute une barre d'échelle blanche sur une image MATLAB.
%
% h = addScaleBar(ax, pixelSizeX, FOV_X_um)
%
% INPUTS
%   ax          : handle de l'axe MATLAB
%   pixelSizeX  : taille d'un pixel en X (µm/pixel)
%   FOV_X_um    : champ de vue horizontal (µm).
%                 Si absent ou invalide, il est estimé avec :
%                 pixelSizeX * nombre de pixels en X.
%
% OPTIONS
%   'Color'     : couleur (défaut : 'w')
%   'LineWidth' : épaisseur de la barre (défaut : 3)
%   'FontSize'  : taille du texte (défaut : 9)
%   'MarginX'   : marge horizontale normalisée (défaut : 0.04)
%   'MarginY'   : marge verticale normalisée (défaut : 0.05)
%
% La longueur physique de la barre représente 1/10 du FOV_X.
%
% OUTPUT
%   h : structure contenant les handles de la ligne et du texte.
%
% Exemple :
%   addScaleBar(gca, 0.6667, 200);
%
%   addScaleBar(gca, 0.6667, 200, ...
%       'Color','w','LineWidth',2,'FontSize',8);

    %% Paramètres

    p = inputParser;

    addParameter(p, 'Color', 'w');
    addParameter(p, 'LineWidth', 3);
    addParameter(p, 'FontSize', 9);
    addParameter(p, 'MarginX', 0.04);
    addParameter(p, 'MarginY', 0.05);
    addParameter(p, 'ScaleBarLength_um', [], ...
    @(x) isempty(x) || (isscalar(x) && isnumeric(x) && isfinite(x) && x > 0));

    parse(p, varargin{:});

    opt = p.Results;

    %% Vérifications

    if ~isgraphics(ax, 'axes')
        error('ax doit être un handle d''axe MATLAB valide.');
    end

    if ~isscalar(pixelSizeX) || ...
            ~isfinite(pixelSizeX) || pixelSizeX <= 0
        error('pixelSizeX doit être positif et fini.');
    end

    %% Détermination du FOV horizontal

    xLimits = xlim(ax);
    yLimits = ylim(ax);

    xRange = abs(diff(xLimits));
    yRange = abs(diff(yLimits));

    % Si FOV_X_um est absent, estimation à partir de la taille
    % de l'image et du pixel size.
    if isempty(FOV_X_um) || ~isscalar(FOV_X_um) || ...
            ~isfinite(FOV_X_um) || FOV_X_um <= 0

        FOV_X_um = pixelSizeX * xRange;
    end

    %% Longueur de la barre


        % Longueur physique de la barre
    if isempty(p.Results.ScaleBarLength_um)
        % Par défaut : 1/10 du champ de vue
        scaleLengthUm = FOV_X_um / 10;
    else
        % Longueur spécifiée par l'utilisateur
        scaleLengthUm = p.Results.ScaleBarLength_um;
    end
    
    % Conversion en pixels
    scaleLengthPx = scaleLengthUm / pixelSizeX;


    if scaleLengthPx > xRange
        warning('La barre d''échelle est plus large que l''image.');
        h = struct('Line', [], 'Text', []);
        return;
    end

    %% Position en bas à droite

    marginX = opt.MarginX * xRange;
    marginY = opt.MarginY * yRange;

    xRight = max(xLimits) - marginX;
    xLeft = xRight - scaleLengthPx;

    % Adaptation à l'orientation de l'axe Y.
    if strcmpi(ax.YDir, 'reverse')
        yBar = max(yLimits) - marginY;
        yText = yBar - 0.02*yRange;
    else
        yBar = min(yLimits) + marginY;
        yText = yBar + 0.02*yRange;
    end

    %% Création graphique

    holdState = ishold(ax);
    hold(ax, 'on');

    h.Line = line(ax, ...
        [xLeft xRight], [yBar yBar], ...
        'Color', opt.Color, ...
        'LineWidth', opt.LineWidth, ...
        'Clipping', 'on');

    % Format de la longueur physique
    if scaleLengthUm >= 10
        label = sprintf('%.0f \\mum', scaleLengthUm);
    else
        label = sprintf('%.1f \\mum', scaleLengthUm);
    end

    h.Text = text(ax, ...
        mean([xLeft xRight]), yText, label, ...
        'Color', opt.Color, ...
        'FontSize', opt.FontSize, ...
        'FontWeight', 'normal', ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom', ...
        'Clipping', 'on');

    if ~holdState
        hold(ax, 'off');
    end

end
