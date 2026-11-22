
function fig = display_SRS_images(data,metadata, params)
% DISPLAY_SRS_IMAGES
% Affiche les images SRS d'un tableau de dimensions [Y X L Z T].
%
% Navigation indépendante selon les dimensions L, Z et T.
% Un curseur est affiché uniquement si la dimension correspondante > 1.
%
% INPUTS
%   data   : tableau numérique [Y X L Z T]
%   params : structure contenant éventuellement :
%
%       show_all_images : true  -> démarrage à L=1, Z=1, T=1
%                         false -> démarrage à L=1, Z central, T=1
%
%       clim             : limites d'affichage [min max]
%       colormap         : colormap (défaut : parula)
%       frame_rate       : fréquence de lecture (défaut : 5 fps)
%       title            : titre général
%
%       metadata         : métadonnées LabVIEW
%       Labview_data     : métadonnées LabVIEW (alternative)
%
% Métadonnées utilisées :
%       pixel_size_X_um  : taille d'un pixel en X (µm)
%       timelapse        : acquisition temporelle
%       Delta_t_s        : intervalle temporel entre deux images (s)
%
% Barre d'échelle :
%       Longueur = 1/10 du FOV horizontal.
%
% Temps :
%       Format XH XM XS, temps écoulé depuis T=1.
%
% Lecture vidéo :
%       L varie en premier, puis Z, puis T.

    %% 1. Paramètres



    if nargin < 2 || isempty(params)
        params = struct();
    end

    if ~isfield(params, 'show_all_images')
        params.show_all_images = false;
    end

    if ~isfield(params, 'colormap') || isempty(params.colormap)
        params.colormap = parula(256);
    end

    if ~isfield(params, 'frame_rate') || isempty(params.frame_rate)
        params.frame_rate = 5;
    end

    if ~isfield(params, 'title') || isempty(params.title)
        params.title = 'SRS images';
    end

    if ~isnumeric(data) || isempty(data) || ndims(data) < 2
        error('data doit être un tableau numérique contenant au moins Y et X.');
    end

    %% 2. Dimensions

    nY = size(data,1);
    nX = size(data,2);
    nL = size(data,3);
    nZ = size(data,4);
    nT = size(data,5);

    data = reshape(data, [nY nX nL nZ nT]);

    nImages = nL*nZ*nT;

    %% 3. Lecture des métadonnées

    % Les métadonnées peuvent être fournies sous plusieurs formes :
    % params.metadata.Labview_data
    % params.Labview_data
    % params.metadata directement

%     metadata = struct();
% 
%     if isfield(params,'metadata') && isstruct(params.metadata)
% 
%         metadata = params.metadata;
% 
%         if isfield(metadata,'Labview_data') && ...
%                 isstruct(metadata.Labview_data)
%             metadata = metadata.Labview_data;
%         end
% 
%     elseif isfield(params,'Labview_data') && ...
%             isstruct(params.Labview_data)
% 
%         metadata = params.Labview_data;
% 
%     end


    % Taille du pixel en X (µm)
    pixelSizeX = getMetadataScalar(metadata, 'pixel_size_X_um');

    % Champ de vue horizontal (µm)
    FOV_X_um = getMetadataScalar(metadata, 'FOV_X_um');

    % Détection du timelapse à partir de la dimension T
    % Ne pas utiliser metadata.timelapse.
    timelapse = nT > 1;
    
    % Intervalle temporel entre deux images (s)
    deltaT = getMetadataScalar(metadata, 'Delta_t_s');
    
    if timelapse && ~isfinite(deltaT)
        warning(['Plusieurs timepoints détectés, mais Delta_t_s est absent ' ...
                 'ou invalide. Le temps ne sera pas affiché.']);
    end

    %% 4. Image initiale

    iL = 1;
    iT = 1;

    if params.show_all_images
        iZ = 1;
    else
        iZ = ceil(nZ/2);
    end

    %% 5. Détermination de l'échelle d'affichage

    if isfield(params, 'clim') && ~isempty(params.clim)

        clim = params.clim;

    else

        if params.show_all_images
            sample = data;
        else
            sample = data(:,:,1:nL,ceil(nZ/2),1);
        end

        values = sample(isfinite(sample));

        if isempty(values)
            clim = [0 1];
        else
            clim = [min(values) max(values)];

            if clim(1) == clim(2)
                clim = clim + [-1 1]*max(abs(clim(1))*0.01,1e-12);
            end
        end
    end

    %% 6. Création de la figure

    fig = figure( ...
        'Name', params.title, ...
        'Color', 'w', ...
        'NumberTitle', 'off', ...
        'Units', 'normalized', ...
        'Position', [0.2 0.12 0.6 0.78]);

    ax = axes('Parent',fig, ...
              'Units','normalized', ...
              'Position',[0.10 0.32 0.80 0.63]);
    

    I = data(:,:,iL,iZ,iT);

    hImg = imagesc(ax,I);

    axis(ax,'image');
    axis(ax,'tight');

    set(ax, 'YDir', 'normal');

    colormap(ax,params.colormap);
    caxis(ax,clim);
    colorbar(ax);

    xlabel(ax,'X (pixel)');
    ylabel(ax,'Y (pixel)');

    hTitle = title(ax,'');
    %% Annotation temporelle

    hTime = [];
    
    if timelapse && isfinite(deltaT) && deltaT >= 0
    
        hTime = text(ax, 0.02, 0.98, '', ...
            'Units', 'normalized', ...
            'Color', 'w', ...
            'FontSize', 9, ...
            'FontWeight', 'normal', ...
            'HorizontalAlignment', 'left', ...
            'VerticalAlignment', 'top', ...
            'BackgroundColor', 'k', ...
            'Margin', 2, ...
            'Clipping', 'on');
    
    end

    %% 7. Barre d'échelle

    % La barre représente 1/10 du FOV horizontal.
    % FOV_X = pixel_size_X_um * nX
    % Longueur barre = FOV_X / 10
    
    hScale = [];
    
    if isfinite(pixelSizeX) && pixelSizeX > 0
    
        hScale = addScaleBar(ax, pixelSizeX, FOV_X_um, ...
            'Color', 'w', ...
            'LineWidth', 3, ...
            'FontSize', 9, ...
            'MarginX', 0.04, ...
            'MarginY', 0.05);
    
    else
        warning(['pixel_size_X_um absent ou invalide : ' ...
                 'barre d''échelle non affichée.']);
    end

    %% 8. Contrôles de navigation indépendants

    % Les trois curseurs sont indépendants.
    % Ils ne sont créés que si la dimension correspondante > 1.

    hDimSlider = cell(1,3);
    hDimValue = cell(1,3);

    dimNames = {'L','Z','T'};
    dimSizes = [nL nZ nT];
    dimValues = [iL iZ iT];

    % Positions verticales des trois lignes de contrôle
    yPositions = [0.235 0.165 0.095];

    for d = 1:3

        if dimSizes(d) <= 1
            continue;
        end

        % Label
        uicontrol(fig, ...
            'Style','text', ...
            'Units','normalized', ...
            'Position',[0.04 yPositions(d) 0.10 0.035], ...
            'String',dimNames{d}, ...
            'BackgroundColor','w', ...
            'FontSize',10, ...
            'FontWeight','bold', ...
            'HorizontalAlignment','left');

        % Curseur
        hDimSlider{d} = uicontrol(fig, ...
            'Style','slider', ...
            'Units','normalized', ...
            'Position',[0.15 yPositions(d) 0.70 0.035], ...
            'Min',1, ...
            'Max',dimSizes(d), ...
            'Value',dimValues(d), ...
            'SliderStep',[1/(dimSizes(d)-1), ...
                          min(10/(dimSizes(d)-1),1)], ...
            'Callback',@(src,evt) dimensionSliderCallback(src,d));

        % Valeur actuelle
        hDimValue{d} = uicontrol(fig, ...
            'Style','text', ...
            'Units','normalized', ...
            'Position',[0.87 yPositions(d) 0.10 0.035], ...
            'String',sprintf('%d/%d',dimValues(d),dimSizes(d)), ...
            'BackgroundColor','w', ...
            'FontSize',10, ...
            'HorizontalAlignment','center');

    end

    %% 9. Bouton Play / Pause

    hPlay = uicontrol(fig, ...
        'Style','togglebutton', ...
        'Units','normalized', ...
        'Position',[0.04 0.025 0.10 0.045], ...
        'String','Play', ...
        'Callback',@playCallback);

    hCounter = uicontrol(fig, ...
        'Style','text', ...
        'Units','normalized', ...
        'Position',[0.16 0.025 0.20 0.045], ...
        'String','', ...
        'BackgroundColor','w', ...
        'FontSize',10, ...
        'HorizontalAlignment','left');

    % Etat de lecture
    isPlaying = false;
    timerObj = [];

    %% 10. Affichage initial

    updateImage();

    %% 11. Callbacks

    function dimensionSliderCallback(src,dim)

        stopPlayback();

        value = round(get(src,'Value'));

        switch dim
            case 1
                iL = value;
            case 2
                iZ = value;
            case 3
                iT = value;
        end

        updateImage();

    end

    function updateImage()

        % Sécurisation des indices
        iL = max(1,min(nL,round(iL)));
        iZ = max(1,min(nZ,round(iZ)));
        iT = max(1,min(nT,round(iT)));

        I = data(:,:,iL,iZ,iT);

        set(hImg,'CData',I);

        % Titre
        
        str = sprintf('%s | L = %d/%d | Z = %d/%d | T = %d/%d', ...
            params.title, iL, nL, iZ, nZ, iT, nT);
        
        set(hTitle, 'String', str);
        
        % Temps écoulé (annotation discrète en haut à gauche)
        
        if ~isempty(hTime) && isgraphics(hTime)
        
            elapsedTime = (iT-1)*deltaT;
        
            timeString = formatElapsedTime(elapsedTime);
        
            set(hTime, 'String', timeString);
        
        end

        % Mise à jour des curseurs et de leurs valeurs
        currentValues = [iL iZ iT];

        for d = 1:3

            if ~isempty(hDimSlider{d}) && isgraphics(hDimSlider{d})

                set(hDimSlider{d},'Value',currentValues(d));

                set(hDimValue{d}, ...
                    'String',sprintf('%d/%d', ...
                    currentValues(d),dimSizes(d)));

            end

        end

        % Indice linéaire dans l'ordre L, Z, T
        idx = sub2ind([nL nZ nT],iL,iZ,iT);

        set(hCounter,'String',sprintf('%d / %d',idx,nImages));

        drawnow limitrate;

    end

    %% 12. Lecture vidéo

    function playCallback(src,~)

        if get(src,'Value') == 1

            if nImages <= 1
                set(src,'Value',0);
                return;
            end

            isPlaying = true;
            set(src,'String','Pause');

            timerObj = timer( ...
                'ExecutionMode','fixedRate', ...
                'Period',1/max(params.frame_rate,0.1), ...
                'TimerFcn',@timerCallback);

            start(timerObj);

        else

            stopPlayback();

        end

    end

    function timerCallback(~,~)

        if ~isgraphics(fig)
            stopPlayback();
            return;
        end

        % Passage à l'image suivante.
        % L varie en premier, puis Z, puis T.

        idx = sub2ind([nL nZ nT],iL,iZ,iT);

        idx = idx+1;

        if idx > nImages
            idx = 1;
        end

        [iL,iZ,iT] = ind2sub([nL nZ nT],idx);

        updateImage();

    end

    function stopPlayback()

        isPlaying = false;

        if ~isempty(timerObj) && isvalid(timerObj)
            stop(timerObj);
            delete(timerObj);
            timerObj = [];
        end

        if isgraphics(hPlay)
            set(hPlay,'Value',0);
            set(hPlay,'String','Play');
        end

    end

    %% 13. Nettoyage à la fermeture

    set(fig,'CloseRequestFcn',@closeFigure);

    function closeFigure(~,~)

        stopPlayback();

        if isgraphics(fig)
            delete(fig);
        end

    end

end


%% ============================================================
% FONCTIONS LOCALES
% ============================================================

function value = getMetadataScalar(metadata,fieldName)
% Recherche un champ numérique dans les métadonnées.

    value = NaN;

    if ~isstruct(metadata)
        return;
    end

    names = fieldnames(metadata);

    idx = find(strcmpi(names,fieldName),1);

    if isempty(idx)
        return;
    end

    raw = metadata.(names{idx});

    if isnumeric(raw) && isscalar(raw)

        value = double(raw);

    elseif islogical(raw) && isscalar(raw)

        value = double(raw);

    elseif ischar(raw) || isstring(raw)

        value = str2double(raw);

    end

    if ~isscalar(value) || ~isfinite(value)
        value = NaN;
    end

end


function value = getMetadataLogical(metadata,fieldName)
% Recherche un champ logique dans les métadonnées.
% Un champ absent est considéré comme false.

    value = false;

    if ~isstruct(metadata)
        return;
    end

    names = fieldnames(metadata);

    idx = find(strcmpi(names,fieldName),1);

    if isempty(idx)
        return;
    end

    raw = metadata.(names{idx});

    if islogical(raw) || isnumeric(raw)

        if isscalar(raw) && isfinite(double(raw))
            value = logical(raw);
        end

    elseif ischar(raw) || isstring(raw)

        str = lower(strtrim(char(raw)));

        value = any(strcmp(str,{'true','1','yes','oui'}));

    end

end


function str = formatElapsedTime(timeSeconds)
% Convertit un temps en secondes au format XH XM XS.

    totalSeconds = round(timeSeconds);

    hours = floor(totalSeconds/3600);
    minutes = floor(mod(totalSeconds,3600)/60);
    seconds = mod(totalSeconds,60);

    str = sprintf('%dH %dM %dS',hours,minutes,seconds);

end

