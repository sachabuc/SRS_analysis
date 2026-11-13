
function [I_binned, fig] = bin_pixels_ND(I, N, varargin)
%BIN_PIXELS_ND Regroupe les pixels XY par blocs N-by-N dans une image N-D.
%
%   [I_binned, fig] = bin_pixels_ND(I, N, ...)
%
%   Dimensions :
%       1-2 : XY
%       3:end : dimensions supplementaires (L, Z, T...)
%
%   Options :
%       'show_image'  : true/false (defaut true)
%       'method'      : 'sum' ou 'mean' (defaut 'sum')
%       'color_limits': [] ou [min max]
%       'wavenumber'  : vecteur des nombres d'onde (cm-1)
%       'spectral_dim': dimension spectrale (defaut 3)
%
%   Si wavenumber est fourni, les images sont triees par nombre
%   d'onde croissant et le nombre d'onde est affiche dans le titre.
%
%   Les pixels excedentaires sont supprimes en bas et a droite.

    %% Verification des entrees

    validateattributes(I, {'numeric','logical'}, {'nonempty'}, mfilename, 'I', 1);
    validateattributes(N, {'numeric'}, {'scalar','integer','positive'}, mfilename, 'N', 2);

    ip = inputParser;
    addParameter(ip, 'show_image', true, @(x) islogical(x) && isscalar(x));
    addParameter(ip, 'method', 'sum', @(x) ischar(x) || (isstring(x) && isscalar(x)));
    addParameter(ip, 'color_limits', [], @(x) isempty(x) || ...
        (isnumeric(x) && numel(x) == 2 && all(isfinite(x))));
    addParameter(ip, 'wavenumber', [], @(x) isempty(x) || isnumeric(x));
    addParameter(ip, 'spectral_dim', 3, @(x) isnumeric(x) && isscalar(x) && ...
        isinteger(x) || (isnumeric(x) && isscalar(x) && x == round(x) && x >= 3));

    parse(ip, varargin{:});

    show_image = ip.Results.show_image;
    method = lower(char(ip.Results.method));
    color_limits = ip.Results.color_limits;
    wavenumber = ip.Results.wavenumber;
    spectral_dim = ip.Results.spectral_dim;

    if ~ismember(method, {'sum','mean'})
        error('method doit etre ''sum'' ou ''mean''.');
    end

    sz = size(I);

    if numel(sz) < 2
        error('I doit posseder au moins deux dimensions (XY).');
    end

    %% Binning spatial XY

    ny_crop = floor(sz(1) / N) * N;
    nx_crop = floor(sz(2) / N) * N;

    if ny_crop == 0 || nx_crop == 0
        error('N=%d est trop grand pour une image de taille %d x %d.', ...
            N, sz(1), sz(2));
    end

    % Suppression des pixels excedentaires
    subs_crop = repmat({':'}, 1, numel(sz));
    subs_crop{1} = 1:ny_crop;
    subs_crop{2} = 1:nx_crop;

    I_crop = double(I(subs_crop{:}));

    ny_out = ny_crop / N;
    nx_out = nx_crop / N;

    trailing_sz = sz(3:end);

    if isempty(trailing_sz)
        trailing_sz = 1;
    end

    % Regroupement des pixels par blocs N x N
    I_tmp = reshape(I_crop, [N, ny_out, N, nx_out, trailing_sz]);
    I_tmp = sum(I_tmp, 1);
    I_tmp = sum(I_tmp, 3);

    I_binned = reshape(I_tmp, [ny_out, nx_out, trailing_sz]);

    if strcmp(method, 'mean')
        I_binned = I_binned ./ N^2;
    end

    if numel(sz) == 2
        I_binned = reshape(I_binned, ny_out, nx_out);
    end

    %% Tri par nombre d'onde croissant

    if ~isempty(wavenumber)

        if spectral_dim > ndims(I_binned)
            error('spectral_dim=%d depasse le nombre de dimensions de I_binned.', ...
                spectral_dim);
        end

        if numel(wavenumber) ~= size(I_binned, spectral_dim)
            error(['Le nombre de valeurs de wavenumber (%d) ne correspond ' ...
                'pas a la taille de la dimension spectrale (%d).'], ...
                numel(wavenumber), size(I_binned, spectral_dim));
        end

        if any(~isfinite(wavenumber(:)))
            error('Le vecteur wavenumber contient des valeurs non finies.');
        end

        % Tri croissant
        [wavenumber, sort_idx] = sort(wavenumber(:), 'ascend');

        % Reorganisation de la dimension spectrale
        subs_sort = repmat({':'}, 1, max(ndims(I_binned), spectral_dim));
        subs_sort{spectral_dim} = sort_idx;

        I_binned = I_binned(subs_sort{:});

    end

    fig = [];

    if ~show_image
        return;
    end

    %% Interface graphique

    out_sz = size(I_binned);
    n_extra = max(0, numel(out_sz) - 2);

    fig = uifigure( ...
        'Name', sprintf('Binning XY : N = %d (%s)', N, method), ...
        'Color', 'white', ...
        'Position', [100 100 900 680]);

    ax = uiaxes(fig, 'Position', [70 65 760 500]);

    ax.YDir = 'reverse';
    colormap(ax, parula);

    xlabel(ax, 'X (pixel bin)');
    ylabel(ax, 'Y (pixel bin)');

    cb = colorbar(ax);
    cb.Label.String = 'Intensite';

    %% Commandes de navigation par fleches

    current_indices = ones(1, n_extra);

    indexLabels = gobjects(1, n_extra);
    leftButtons = gobjects(1, n_extra);
    rightButtons = gobjects(1, n_extra);

    n_per_row = 4;
    control_width = 205;
    control_gap = 15;

    for d = 1:n_extra

        dim_number = d + 2;
        dim_size = out_sz(dim_number);

        row = floor((d-1) / n_per_row);
        col = mod(d-1, n_per_row);

        x0 = 20 + col * (control_width + control_gap);
        y0 = 640 - row * 55;

        % Nom de la dimension
        dim_name = sprintf('Dimension %d', dim_number);

        if ~isempty(wavenumber) && dim_number == spectral_dim
            dim_name = 'Nombre d''onde';
        end

        uilabel(fig, ...
            'Position', [x0 y0 control_width 18], ...
            'Text', dim_name, ...
            'FontWeight', 'bold');

        % Fleche gauche
        leftButtons(d) = uibutton(fig, 'push', ...
            'Position', [x0 y0-30 35 26], ...
            'Text', char(8592), ...
            'FontSize', 16, ...
            'Enable', 'off', ...
            'ButtonPushedFcn', @(src,event) changeIndex(d, -1));

        % Indice courant
        if ~isempty(wavenumber) && dim_number == spectral_dim
            label_text = sprintf('%.2f cm^{-1}', wavenumber(1));
        else
            label_text = sprintf('1 / %d', dim_size);
        end

        indexLabels(d) = uilabel(fig, ...
            'Position', [x0+42 y0-30 85 26], ...
            'Text', label_text, ...
            'HorizontalAlignment', 'center', ...
            'FontSize', 12);

        % Fleche droite
        rightButtons(d) = uibutton(fig, 'push', ...
            'Position', [x0+135 y0-30 35 26], ...
            'Text', char(8594), ...
            'FontSize', 16, ...
            'ButtonPushedFcn', @(src,event) changeIndex(d, 1));

        if dim_size == 1
            rightButtons(d).Enable = 'off';
        end

    end

    updateImage();


    %% Modification de l'indice

    function changeIndex(dim, increment)

        dim_size = out_sz(dim+2);

        current_indices(dim) = current_indices(dim) + increment;

        current_indices(dim) = max(1, min(dim_size, current_indices(dim)));

        % Mise a jour de l'affichage de l'indice
        if ~isempty(wavenumber) && (dim+2) == spectral_dim

            indexLabels(dim).Text = sprintf('%.2f cm^{-1}', ...
                wavenumber(current_indices(dim)));

        else

            indexLabels(dim).Text = sprintf('%d / %d', ...
                current_indices(dim), dim_size);

        end

        % Activation/desactivation des fleches
        leftButtons(dim).Enable = 'on';
        rightButtons(dim).Enable = 'on';

        if current_indices(dim) == 1
            leftButtons(dim).Enable = 'off';
        end

        if current_indices(dim) == dim_size
            rightButtons(dim).Enable = 'off';
        end

        updateImage();

    end


    %% Actualisation de l'image

    function updateImage()

        sz_bin = size(I_binned);
        n_extra_local = numel(sz_bin) - 2;

        if n_extra_local > 0

            % Conversion des indices multidimensionnels en indice lineaire
            extra_dims = sz_bin(3:end);

            linear_idx = 1;
            multiplier = 1;

            for dd = 1:n_extra_local

                linear_idx = linear_idx + ...
                    (current_indices(dd)-1) * multiplier;

                multiplier = multiplier * extra_dims(dd);

            end

            I_3D = reshape(I_binned, sz_bin(1), sz_bin(2), []);

            img = I_3D(:,:,linear_idx);

        else

            img = reshape(I_binned, sz_bin(1), sz_bin(2));

        end

        % Affichage
        imagesc(ax, img);

        ax.YDir = 'reverse';
        axis(ax, 'image');
        colormap(ax, parula);

        % Limites d'intensite
        if isempty(color_limits)

            vals = img(isfinite(img));

            if ~isempty(vals)

                lo = min(vals);
                hi = max(vals);

                if lo == hi
                    hi = lo + eps(max(1, abs(lo)));
                end

                caxis(ax, [lo hi]);

            end

        else

            caxis(ax, color_limits);

        end

        % Titre
        if ~isempty(wavenumber)

            spectral_idx = current_indices(spectral_dim-2);

            title(ax, sprintf('%.2f cm^{-1}', ...
                wavenumber(spectral_idx)));

        else

            indices_txt = '';

            for dd = 1:n_extra_local

                indices_txt = [indices_txt, sprintf( ...
                    ' | dim %d = %d', ...
                    dd+2, current_indices(dd))];

            end

            title(ax, sprintf('Image XY — N = %d, %s%s', ...
                N, method, indices_txt));

        end

        drawnow limitrate;

    end

end
