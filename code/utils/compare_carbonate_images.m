

function [results, fig] = compare_carbonate_images(data, wavenumber, intervals, params)
%COMPARE_CARBONATE_IMAGES Comparaison rapide des signaux carbonate.
%
% [results, fig] = compare_carbonate_images(data, wavenumber, intervals)
% [results, fig] = compare_carbonate_images(data, wavenumber, intervals, params)
%
% INPUTS
%   data        : données SRS [Y X L Z T]
%   wavenumber  : axe spectral en cm-1
%
%   intervals  : structure contenant les intervalles spectraux :
%       .aragonite = [1082 1088]
%       .acc       = [1072 1080]
%       .cchh      = [1097 1105]
%       .background = [1110 1120]  % Hors carbonate
%
%   params      : structure optionnelle :
%       .Z        : plan Z initial (défaut : 1)
%       .T        : timepoint initial (défaut : 1)
%       .title    : titre général
%
%       .caxis    : limites indépendantes pour chaque image.
%                   [] = ajustement automatique.
%                   Exemple :
%       .caxis.aragonite = [0 100]
%       .caxis.acc = [0 80]
%       .caxis.cchh = [0 50]
%       .caxis.background = [0 20]
%       .caxis.acc_minus_background = [-20 50]
%       .caxis.acc_minus_aragonite = [-30 30]
%       .caxis.cchh_minus_aragonite = [-30 30]
%       .caxis.cchh_minus_background = [-20 50]
%
% OUTPUTS
%   results : images calculées pour le plan Z/T initial.
%             Les résultats du plan actuellement affiché sont également
%             disponibles dans fig.UserData après navigation.
%   fig     : figure MATLAB.
%
% ORGANISATION DU SUBPLOT
%
%   Ligne 1 : Aragonite | ACC | CCHH | Hors carbonate
%   Ligne 2 : ACC - hors carbonate | ACC - aragonite |
%             CCHH - aragonite | CCHH - hors carbonate

    %% Vérification des entrées

    if nargin < 4 || isempty(params)
        params = struct();
    end

    if ~isstruct(intervals)
        error('intervals doit être une structure.');
    end

    requiredIntervals = {'aragonite', 'acc', 'cchh', 'background'};

    for k = 1:numel(requiredIntervals)
        field = requiredIntervals{k};

        if ~isfield(intervals, field)
            error('Intervalle manquant : intervals.%s', field);
        end

        currentInterval = intervals.(field);

        if ~isnumeric(currentInterval) || ...
                numel(currentInterval) ~= 2 || ...
                any(~isfinite(currentInterval)) || ...
                currentInterval(1) == currentInterval(2)

            error('Intervalle invalide pour %s.', field);
        end
    end

    wavenumber = double(wavenumber(:));

    if numel(wavenumber) ~= size(data, 3)
        error(['La longueur de wavenumber (%d) ne correspond pas ' ...
               'à la dimension spectrale de data (%d).'], ...
               numel(wavenumber), size(data, 3));
    end

    if any(~isfinite(wavenumber))
        error('wavenumber contient des valeurs non finies.');
    end

    %% Dimensions

    nZ = size(data, 4);
    nT = size(data, 5);

    %% Paramètres initiaux

    if ~isfield(params, 'Z') || isempty(params.Z)
        params.Z = 1;
    end

    if ~isfield(params, 'T') || isempty(params.T)
        params.T = 1;
    end

    if ~isfield(params, 'title') || isempty(params.title)
        params.title = 'Comparaison des phases carbonatées';
    end

    iZ = min(max(round(params.Z), 1), nZ);
    iT = min(max(round(params.T), 1), nT);

    %% Paramètres caxis

    caxisNames = { ...
        'aragonite', ...
        'acc', ...
        'cchh', ...
        'background', ...
        'acc_minus_background', ...
        'acc_minus_aragonite', ...
        'cchh_minus_aragonite', ...
        'cchh_minus_background'};

    if ~isfield(params, 'caxis') || isempty(params.caxis)
        params.caxis = struct();
    end

    if ~isstruct(params.caxis)
        error('params.caxis doit être une structure.');
    end

    for k = 1:numel(caxisNames)

        field = caxisNames{k};

        if ~isfield(params.caxis, field)
            params.caxis.(field) = [];
        end

        limits = params.caxis.(field);

        if ~isempty(limits)
            if ~isnumeric(limits) || numel(limits) ~= 2 || ...
                    any(~isfinite(limits)) || limits(1) >= limits(2)

                error('Limites caxis invalides pour %s.', field);
            end

            params.caxis.(field) = double(limits(:)');
        end
    end

    %% Masques spectraux

    masks = struct();

    for k = 1:numel(requiredIntervals)

        field = requiredIntervals{k};
        limits = sort(intervals.(field));

        masks.(field) = ...
            wavenumber >= limits(1) & wavenumber <= limits(2);

        if ~any(masks.(field))
            error(['Aucun point spectral dans l''intervalle %s ' ...
                   '[%.2f %.2f] cm-1.\nPlage spectrale disponible : ' ...
                   '[%.2f %.2f] cm-1.'], ...
                   field, limits(1), limits(2), ...
                   min(wavenumber), max(wavenumber));
        end
    end

    %% Création de la figure

    fig = figure( ...
        'Name', 'Comparaison des phases carbonatées', ...
        'Color', 'w', ...
        'NumberTitle', 'off', ...
        'Position', [100 100 1500 800]);

    tl = tiledlayout(fig, 2, 4, ...
        'TileSpacing', 'compact', ...
        'Padding', 'compact');

    tl.Position = [0.035 0.14 0.93 0.80];

    sgtitle(tl, params.title, 'FontWeight', 'bold');

    titles = { ...
        sprintf('Aragonite [%.1f–%.1f cm^{-1}]', sort(intervals.aragonite)), ...
        sprintf('ACC [%.1f–%.1f cm^{-1}]', sort(intervals.acc)), ...
        sprintf('CCHH [%.1f–%.1f cm^{-1}]', sort(intervals.cchh)), ...
        sprintf('Hors carbonate [%.1f–%.1f cm^{-1}]', sort(intervals.background)), ...
        sprintf('ACC - hors carbonate'), ...
        sprintf('ACC - aragonite'), ...
        sprintf('CCHH - aragonite'), ...
        sprintf('CCHH - hors carbonate')};

    hAx = gobjects(8,1);
    hImg = gobjects(8,1);

    %% Calcul des premières images

    initialImages = calculateImages(iZ, iT);

    for k = 1:8

        hAx(k) = nexttile(tl, k);

        hImg(k) = imagesc(hAx(k), initialImages{k});

        axis(hAx(k), 'image');
        set(hAx(k), 'YDir', 'normal');

        title(hAx(k), titles{k}, 'FontWeight', 'bold');

        if k <= 4
            colormap(hAx(k), parula(256));
        else
            colormap(hAx(k), blueWhiteRed(256));
        end

        applyCaxis(hAx(k), initialImages{k}, caxisNames{k});

        colorbar(hAx(k));

        xlabel(hAx(k), 'X (pixels)');
        ylabel(hAx(k), 'Y (pixels)');
    end

    %% Contrôles Z et T

    hZSlider = [];
    hTSlider = [];

    if nZ > 1

        uicontrol(fig, ...
            'Style', 'text', ...
            'Units', 'normalized', ...
            'Position', [0.20 0.055 0.08 0.035], ...
            'String', 'Position Z', ...
            'BackgroundColor', 'w');

        hZSlider = uicontrol(fig, ...
            'Style', 'slider', ...
            'Units', 'normalized', ...
            'Position', [0.28 0.06 0.25 0.025], ...
            'Min', 1, ...
            'Max', nZ, ...
            'Value', iZ, ...
            'SliderStep', [1/max(nZ-1,1), ...
                           min(5/max(nZ-1,1),1)], ...
            'Callback', @updateImages);
    end

    if nT > 1

        uicontrol(fig, ...
            'Style', 'text', ...
            'Units', 'normalized', ...
            'Position', [0.56 0.055 0.08 0.035], ...
            'String', 'Time T', ...
            'BackgroundColor', 'w');

        hTSlider = uicontrol(fig, ...
            'Style', 'slider', ...
            'Units', 'normalized', ...
            'Position', [0.64 0.06 0.25 0.025], ...
            'Min', 1, ...
            'Max', nT, ...
            'Value', iT, ...
            'SliderStep', [1/max(nT-1,1), ...
                           min(5/max(nT-1,1),1)], ...
            'Callback', @updateImages);
    end

    %% Résultats initiaux

    results = buildResults(initialImages, iZ, iT);
    fig.UserData = results;

    %% Fonctions imbriquées

    function images = calculateImages(z, t)

        volume = double(data(:,:,:,z,t));

        imgAra = meanFinite(volume(:,:,masks.aragonite), 3);
        imgACC = meanFinite(volume(:,:,masks.acc), 3);
        imgCCHH = meanFinite(volume(:,:,masks.cchh), 3);
        imgBg = meanFinite(volume(:,:,masks.background), 3);

        % Différences
        imgACC_Bg = imgACC - imgBg;
        imgACC_Ara = imgACC - imgAra;
        imgCCHH_Ara = imgCCHH - imgAra;
        imgCCHH_Bg = imgCCHH - imgBg;

        images = { ...
            imgAra, ...
            imgACC, ...
            imgCCHH, ...
            imgBg, ...
            imgACC_Bg, ...
            imgACC_Ara, ...
            imgCCHH_Ara, ...
            imgCCHH_Bg};
    end

    function updateImages(src, ~)

        if ~isempty(hZSlider)
            iZ = round(get(hZSlider, 'Value'));
            set(hZSlider, 'Value', iZ);
        end

        if ~isempty(hTSlider)
            iT = round(get(hTSlider, 'Value'));
            set(hTSlider, 'Value', iT);
        end

        currentImages = calculateImages(iZ, iT);

        for j = 1:8

            set(hImg(j), 'CData', currentImages{j});

            % Recalcule uniquement les limites automatiques.
            % Les limites manuelles restent inchangées.
            applyCaxis(hAx(j), currentImages{j}, caxisNames{j});
        end

        titleText = sprintf('%s | Z = %d/%d | T = %d/%d', ...
            params.title, iZ, nZ, iT, nT);

        sgtitle(tl, titleText, 'FontWeight', 'bold');

        % Les résultats actualisés sont accessibles via fig.UserData.
        fig.UserData = buildResults(currentImages, iZ, iT);

    end

    function applyCaxis(ax, img, field)

        limits = params.caxis.(field);

        if isempty(limits)

            finiteValues = img(isfinite(img));

            if isempty(finiteValues)
                limits = [0 1];
            else
                limits = [min(finiteValues), max(finiteValues)];

                % Évite un caxis de largeur nulle.
                if limits(1) == limits(2)
                    delta = max(abs(limits(1))*1e-6, 1e-6);
                    limits = limits + [-delta delta];
                end
            end
        end

        caxis(ax, limits);
    end

    function out = buildResults(images, z, t)

        out = struct();

        out.Aragonite = images{1};
        out.ACC = images{2};
        out.CCHH = images{3};
        out.Background = images{4};

        out.ACC_minus_Background = images{5};
        out.ACC_minus_Aragonite = images{6};
        out.CCHH_minus_Aragonite = images{7};
        out.CCHH_minus_Background = images{8};

        out.Z = z;
        out.T = t;
    end

end

%% Fonctions locales

function img = meanFinite(volume, dim)
% Moyenne en ignorant les NaN et les Inf.

    valid = isfinite(volume);

    volume(~valid) = 0;

    count = sum(valid, dim);
    total = sum(volume, dim);

    img = total ./ count;
    img(count == 0) = NaN;
end

function cmap = blueWhiteRed(n)
% Colormap bleu - blanc - rouge.

    if nargin < 1
        n = 256;
    end

    n1 = floor(n/2);
    n2 = n - n1;

    blue = [0.1 0.2 0.8];
    white = [1 1 1];
    red = [0.8 0.1 0.1];

    part1 = [ ...
        linspace(blue(1), white(1), n1)', ...
        linspace(blue(2), white(2), n1)', ...
        linspace(blue(3), white(3), n1)'];

    part2 = [ ...
        linspace(white(1), red(1), n2)', ...
        linspace(white(2), red(2), n2)', ...
        linspace(white(3), red(3), n2)'];

    cmap = [part1; part2];
end
