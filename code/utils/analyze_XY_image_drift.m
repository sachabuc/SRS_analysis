


function results = analyze_XY_image_drift(images, varargin)
% ANALYZE_XY_IMAGE_DRIFT
%
% Analyse la reproductibilite geometrique d'une serie d'images XY.
%
% ENTREES :
% images : stack de dimensions [X x Y x L x Z x T]
%          L = 1 et Z = 1
%          T = nombre d'images a analyser.
%
% Les images sont extraites suivant :
% images(:,:,1,1,t)
%
% OPTIONS :
% 'show'          : affichage des resultats (true)
% 'iterations'    : iterations imregdemons ([500 300 100])
% 'pyramidLevels' : niveaux de pyramide (3)
% 'smoothing'     : lissage du champ de deformation (1.3)
% 'pixelSize'     : taille d'un pixel en um (NaN)
% 'normalize'     : normalisation pour le recalage (true)
%
% SORTIE :
% results : structure contenant :
%   - images originales
%   - images recalees
%   - translations globales
%   - cartes de deformation locale
%   - statistiques de deformation
%
% Necessite Image Processing Toolbox.

%% ------------------------------------------------------------
% 1. OPTIONS
% -------------------------------------------------------------

p = inputParser;

addParameter(p, 'show', true);
addParameter(p, 'iterations', [500 300 100]);
addParameter(p, 'pyramidLevels', 3);
addParameter(p, 'smoothing', 1.3);
addParameter(p, 'pixelSize', NaN);
addParameter(p, 'normalize', true);

parse(p, varargin{:});

showResults = p.Results.show;
iterations = p.Results.iterations;
pyramidLevels = p.Results.pyramidLevels;
smoothing = p.Results.smoothing;
pixelSize = p.Results.pixelSize;
normalize = p.Results.normalize;

%% ------------------------------------------------------------
% 2. VERIFICATION DU STACK 5D
% -------------------------------------------------------------

if ~isnumeric(images) || ~isreal(images)
    error('images doit etre un tableau numerique reel.');
end

if size(images,3) ~= 1 || size(images,4) ~= 1
    error(['Les dimensions L et Z doivent etre egales a 1. ' ...
           'Dimensions recues : L=%d, Z=%d.'], ...
           size(images,3), size(images,4));
end

nx = size(images,1);
ny = size(images,2);
N = size(images,5);

if N < 2
    error('Il faut au moins deux images dans la dimension T.');
end

if any(~isfinite(images(:)))
    error('Les images contiennent des valeurs NaN ou Inf.');
end

fprintf('\n--- Dimensions du stack ---\n');
fprintf('X = %d pixels\n',nx);
fprintf('Y = %d pixels\n',ny);
fprintf('L = %d\n',size(images,3));
fprintf('Z = %d\n',size(images,4));
fprintf('T = %d images\n',N);

%% ------------------------------------------------------------
% 3. EXTRACTION DES IMAGES XY
% -------------------------------------------------------------

% Les donnees sont stockees sous la forme [X x Y x L x Z x T].
%
% Pour les fonctions de traitement d'image MATLAB :
% lignes   = Y
% colonnes = X
%
% On convertit donc le stack en [Y x X x T].

stack = permute(reshape(images,nx,ny,N),[2 1 3]);

[ny,nx,N] = size(stack);

reference = stack(:,:,1);

% Image de reference pour le recalage
refReg = mat2gray(reference);

%% ------------------------------------------------------------
% 4. RECALAGE PAR TRANSLATION
% -------------------------------------------------------------

fprintf('\n--- Recalage par translation ---\n');

registeredFull = zeros(ny,nx,N);
validMasks = false(ny,nx,N);

dx = zeros(N,1);
dy = zeros(N,1);
translationNorm = zeros(N,1);

Rfixed = imref2d([ny nx]);

registeredFull(:,:,1) = reference;
validMasks(:,:,1) = true(ny,nx);

for k = 2:N

    fprintf('Recalage image %d / %d\n',k,N);

    moving = stack(:,:,k);

    if normalize
        movingReg = mat2gray(moving);
    else
        movingReg = mat2gray(moving);
    end

    % Estimation de la translation necessaire pour aligner
    % l'image mobile sur la premiere image.

    tform = imregcorr(movingReg,refReg,'translation');

    % Translation appliquee a l'image mobile
    dx(k) = tform.T(3,1);
    dy(k) = tform.T(3,2);

    translationNorm(k) = hypot(dx(k),dy(k));

    % Application a l'image originale
    registeredFull(:,:,k) = imwarp( ...
        moving,tform, ...
        'OutputView',Rfixed, ...
        'InterpolationMethod','linear');

    % Masque des pixels valides apres translation
    validMasks(:,:,k) = imwarp( ...
        true(ny,nx),tform, ...
        'OutputView',Rfixed, ...
        'InterpolationMethod','nearest');

end

%% ------------------------------------------------------------
% 5. DETERMINATION DE LA ZONE COMMUNE
% -------------------------------------------------------------

commonMask = all(validMasks,3);

% Recherche du plus grand rectangle entierement valide
% a partir du masque commun.

heights = false(ny,nx);
bestArea = 0;

bestRect = [];

for r1 = 1:ny

    heights(r1,:) = commonMask(r1,:);

    if r1 > 1
        heights(r1,:) = heights(r1,:) .* ...
                        (heights(r1-1,:) + commonMask(r1,:));
    end

end

% Recherche du plus grand rectangle valide par histogramme
% de hauteurs.

for r2 = 1:ny

    h = zeros(1,nx);

    for r1 = r2:-1:1

        h = h + double(commonMask(r1,:));

        % Les colonnes doivent etre valides sur toute la hauteur
        if r1 < r2
            h = min(h,double(commonMask(r1,:)));
        end

        % Recherche du plus grand rectangle dans cette bande
        validCols = commonMask(r1:r2,:);
        validCols = all(validCols,1);

        edges = diff([false validCols false]);
        starts = find(edges == 1);
        ends = find(edges == -1)-1;

        for j = 1:numel(starts)

            width = ends(j)-starts(j)+1;
            height = r2-r1+1;
            area = width*height;

            if area > bestArea
                bestArea = area;
                bestRect = [starts(j),ends(j),r1,r2];
            end

        end

    end

end

if isempty(bestRect)
    error('Impossible de trouver une zone commune valide.');
end

cMin = bestRect(1);
cMax = bestRect(2);
rMin = bestRect(3);
rMax = bestRect(4);

cropRect = [cMin cMax rMin rMax];

% Recadrage identique pour toutes les images
registered = registeredFull(rMin:rMax,cMin:cMax,:);

[nyCrop,nxCrop,~] = size(registered);

fprintf('\nZone initiale : %d x %d pixels\n',nx,ny);
fprintf('Zone recadree : %d x %d pixels\n',nxCrop,nyCrop);

%% ------------------------------------------------------------
% 6. ANALYSE DES DEFORMATIONS LOCALES
% -------------------------------------------------------------

fprintf('\n--- Analyse des deformations locales ---\n');

fixed = registered(:,:,1);
fixedReg = mat2gray(fixed);

deformationX = zeros(nyCrop,nxCrop,N);
deformationY = zeros(nyCrop,nxCrop,N);
deformationMagnitude = zeros(nyCrop,nxCrop,N);

strainMagnitude = zeros(nyCrop,nxCrop,N);

medianDeformation = zeros(N,1);
rmsDeformation = zeros(N,1);
maxDeformation = zeros(N,1);

medianStrain = zeros(N,1);
rmsStrain = zeros(N,1);

for k = 2:N

    fprintf('Deformation image %d / %d\n',k,N);

    moving = registered(:,:,k);
    movingReg = mat2gray(moving);

    % Estimation du champ de deplacement non rigide
    [D,~] = imregdemons( ...
        movingReg,fixedReg,iterations, ...
        'PyramidLevels',pyramidLevels, ...
        'AccumulatedFieldSmoothing',smoothing);

    % D(:,:,1) : deplacement X
    % D(:,:,2) : deplacement Y

    u = D(:,:,1);
    v = D(:,:,2);

    deformationX(:,:,k) = u;
    deformationY(:,:,k) = v;

    magnitude = hypot(u,v);

    deformationMagnitude(:,:,k) = magnitude;

    % Derivees spatiales du champ de deplacement
    [du_dy,du_dx] = gradient(u);
    [dv_dy,dv_dx] = gradient(v);

    % Tenseur de petites deformations
    exx = du_dx;
    eyy = dv_dy;
    exy = 0.5*(du_dy+dv_dx);

    strain = sqrt(exx.^2+eyy.^2+2*exy.^2);

    strainMagnitude(:,:,k) = strain;

    % Statistiques
    medianDeformation(k) = median(magnitude(:));
    rmsDeformation(k) = sqrt(mean(magnitude(:).^2));
    maxDeformation(k) = max(magnitude(:));

    medianStrain(k) = median(strain(:));
    rmsStrain(k) = sqrt(mean(strain(:).^2));

end

%% ------------------------------------------------------------
% 7. CONVERSION EN MICROMETRES
% -------------------------------------------------------------

if isfinite(pixelSize)

    dxPhysical = dx*pixelSize;
    dyPhysical = dy*pixelSize;
    translationPhysical = translationNorm*pixelSize;

    deformationMagnitudePhysical = ...
        deformationMagnitude*pixelSize;

else

    dxPhysical = [];
    dyPhysical = [];
    translationPhysical = [];

    deformationMagnitudePhysical = [];

end

%% ------------------------------------------------------------
% 8. STRUCTURE DE RESULTATS
% -------------------------------------------------------------

results = struct();

results.original = stack;
results.reference = reference;

results.registeredFull = registeredFull;
results.registered = registered;

results.dx = dx;
results.dy = dy;
results.translationNorm = translationNorm;

results.dxPhysical = dxPhysical;
results.dyPhysical = dyPhysical;
results.translationPhysical = translationPhysical;

results.cropRect = cropRect;
results.commonSize = [nyCrop nxCrop];

results.deformationX = deformationX;
results.deformationY = deformationY;
results.deformationMagnitude = deformationMagnitude;

results.deformationMagnitudePhysical = ...
    deformationMagnitudePhysical;

results.strainMagnitude = strainMagnitude;

results.medianDeformation = medianDeformation;
results.rmsDeformation = rmsDeformation;
results.maxDeformation = maxDeformation;

results.medianStrain = medianStrain;
results.rmsStrain = rmsStrain;

results.pixelSize = pixelSize;

%% ------------------------------------------------------------
% 9. TABLEAU RECAPITULATIF
% -------------------------------------------------------------

results.table = table( ...
    (1:N)',dx,dy,translationNorm, ...
    medianDeformation,rmsDeformation, ...
    medianStrain,rmsStrain, ...
    'VariableNames',{ ...
    'Image','DeltaX_px','DeltaY_px','Translation_px', ...
    'MedianDeformation_px','RMSDeformation_px', ...
    'MedianStrain','RMSStrain'});

fprintf('\n--- Tableau recapitulatif ---\n');
disp(results.table);

%% ------------------------------------------------------------
% 10. AFFICHAGE
% -------------------------------------------------------------


    %% Images recalees : visualiseur interactif

    figViewer = figure( ...
        'Name','Visualisation des images recalees', ...
        'Color','w', ...
        'NumberTitle','off', ...
        'Position',[300 150 900 700], ...
        'CloseRequestFcn',@closeImageViewer);

    ax = axes('Parent',figViewer, ...
        'Units','normalized', ...
        'Position',[0.10 0.16 0.80 0.76]);

    % Affichage initial
    hImage = imagesc(ax,registered(:,:,1));
    axis(ax,'image');
    colormap(ax,gray);
    colorbar(ax);

    xlabel(ax,'X (pixels)');
    ylabel(ax,'Y (pixels)');

    title(ax,sprintf('Image 1 / %d',N));

    % Menu deroulant
    imageNames = arrayfun(@(k)sprintf('Image %d',k), ...
        1:N,'UniformOutput',false);

    hPopup = uicontrol(figViewer, ...
        'Style','popupmenu', ...
        'Units','normalized', ...
        'Position',[0.10 0.055 0.22 0.055], ...
        'String',imageNames, ...
        'Value',1, ...
        'FontSize',11, ...
        'Callback',@selectViewerImage);

    % Bouton Play / Pause
    hPlay = uicontrol(figViewer, ...
        'Style','togglebutton', ...
        'Units','normalized', ...
        'Position',[0.37 0.055 0.16 0.055], ...
        'String','Play', ...
        'FontSize',11, ...
        'Callback',@toggleImagePlayback);

    % Intervalle entre images
    uicontrol(figViewer, ...
        'Style','text', ...
        'Units','normalized', ...
        'Position',[0.57 0.055 0.13 0.055], ...
        'String','Intervalle (s)', ...
        'BackgroundColor','w', ...
        'FontSize',10);

    hInterval = uicontrol(figViewer, ...
        'Style','edit', ...
        'Units','normalized', ...
        'Position',[0.71 0.055 0.12 0.055], ...
        'String','0.5', ...
        'FontSize',11, ...
        'Callback',@updateViewerInterval);

    % Etat du visualiseur
    viewerData.images = registered;
    viewerData.N = N;
    viewerData.currentImage = 1;
    viewerData.hImage = hImage;
    viewerData.hPopup = hPopup;
    viewerData.hPlay = hPlay;
    viewerData.hInterval = hInterval;
    viewerData.ax = ax;
    viewerData.timer = [];

    guidata(figViewer,viewerData);


if showResults

    % Translations
    figure('Name','Translations globales','Color','w');

    tiledlayout(2,1);

    nexttile;
    plot(1:N,dx,'o-','LineWidth',1.5);
    grid on;
    xlabel('Image');
    ylabel('\Delta X (pixels)');
    title('Translation X');

    nexttile;
    plot(1:N,dy,'o-','LineWidth',1.5);
    grid on;
    xlabel('Image');
    ylabel('\Delta Y (pixels)');
    title('Translation Y');

    % Norme de translation
    figure('Name','Deplacement global','Color','w');

    plot(1:N,translationNorm,'o-','LineWidth',1.5);
    grid on;
    xlabel('Image');
    ylabel('Deplacement (pixels)');
    title('Deplacement global');

    % Images recalees
    figure('Name','Images recalees et recadrees','Color','w');

    nCols = ceil(sqrt(N));
    nRows = ceil(N/nCols);

    tiledlayout(nRows,nCols,'TileSpacing','compact');

    for k = 1:N

        nexttile;
        imagesc(registered(:,:,k));
        axis image;
        colormap(gca,gray);
        title(sprintf('Image %d',k));
        xlabel('X (pixels)');
        ylabel('Y (pixels)');

    end

    % Evolution des deformations
    figure('Name','Deformation residuelle','Color','w');

    tiledlayout(2,1);

    nexttile;
    plot(1:N,medianDeformation,'o-','LineWidth',1.5);
    hold on;
    plot(1:N,rmsDeformation,'s-','LineWidth',1.5);
    grid on;
    xlabel('Image');
    ylabel('Deplacement (pixels)');
    legend('Mediane','RMS','Location','best');
    title('Deplacement local residuel');

    nexttile;
    plot(1:N,medianStrain,'o-','LineWidth',1.5);
    hold on;
    plot(1:N,rmsStrain,'s-','LineWidth',1.5);
    grid on;
    xlabel('Image');
    ylabel('Deformation relative');
    legend('Mediane','RMS','Location','best');
    title('Deformation geometrique');

    % Cartes de deformation
    for k = 2:N

        figure('Name',sprintf('Deformation image %d',k), ...
            'Color','w');

        tiledlayout(2,2,'TileSpacing','compact');

        nexttile;
        imagesc(deformationX(:,:,k));
        axis image;
        colorbar;
        title('Deplacement X (pixels)');

        nexttile;
        imagesc(deformationY(:,:,k));
        axis image;
        colorbar;
        title('Deplacement Y (pixels)');

        nexttile;
        imagesc(deformationMagnitude(:,:,k));
        axis image;
        colorbar;
        title('Norme du deplacement (pixels)');

        nexttile;
        imagesc(strainMagnitude(:,:,k));
        axis image;
        colorbar;
        title('Deformation locale');

    end

end

fprintf('\nAnalyse terminee.\n');

end


function selectViewerImage(src,~)

    fig = ancestor(src,'figure');
    data = guidata(fig);

    k = src.Value;

    data.currentImage = k;

    updateViewerDisplay(fig,data);

end


function toggleImagePlayback(src,~)

    fig = ancestor(src,'figure');
    data = guidata(fig);

    if src.Value == 1

        % Demarrage de la lecture
        src.String = 'Pause';

        interval = str2double(data.hInterval.String);

        if ~isfinite(interval) || interval <= 0
            interval = 0.5;
            data.hInterval.String = '0.5';
        end

        % Arret d'un ancien timer eventuel
        if ~isempty(data.timer) && isvalid(data.timer)
            stop(data.timer);
            delete(data.timer);
        end

        data.timer = timer( ...
            'ExecutionMode','fixedSpacing', ...
            'Period',interval, ...
            'TimerFcn',@(~,~)advanceViewerImage(fig));

        guidata(fig,data);

        start(data.timer);

    else

        % Pause
        src.String = 'Play';

        if ~isempty(data.timer) && isvalid(data.timer)
            stop(data.timer);
        end

        guidata(fig,data);

    end

end


function advanceViewerImage(fig)

    if ~isvalid(fig)
        return;
    end

    data = guidata(fig);

    data.currentImage = data.currentImage + 1;

    % Lecture en boucle
    if data.currentImage > data.N
        data.currentImage = 1;
    end

    data.hPopup.Value = data.currentImage;

    updateViewerDisplay(fig,data);

end


function updateViewerInterval(src,~)

    fig = ancestor(src,'figure');
    data = guidata(fig);

    interval = str2double(src.String);

    if ~isfinite(interval) || interval <= 0

        interval = 0.5;
        src.String = '0.5';

    end

    % Modification de la vitesse si le timer tourne
    if ~isempty(data.timer) && isvalid(data.timer)

        if strcmp(data.timer.Running,'on')
            stop(data.timer);
            data.timer.Period = interval;
            start(data.timer);
        else
            data.timer.Period = interval;
        end

    end

    guidata(fig,data);

end


function updateViewerDisplay(fig,data)

    if ~isvalid(fig)
        return;
    end

    data.hImage.CData = data.images(:,:,data.currentImage);

    title(data.ax,sprintf('Image %d / %d', ...
        data.currentImage,data.N));

    drawnow limitrate;

    guidata(fig,data);

end


function closeImageViewer(src,~)

    data = guidata(src);

    if ~isempty(data.timer) && isvalid(data.timer)

        stop(data.timer);
        delete(data.timer);

    end

    delete(src);

end

