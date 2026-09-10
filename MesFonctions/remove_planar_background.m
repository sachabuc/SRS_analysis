function [I_corr, SNR, sigma_spec, plane_stack] = ...
    remove_planar_background(imgs, ROI_lines, ROI_cols, display_fig,display_lambda)

%--------------------------------------------------------------------------
% CHATGPT generated 

% Remove planar background from a hyperspectral image stack
%
% INPUTS
% imgs         : Nx x Ny x Nlambda image stack
% ROI_lines    : vector of row indices used as background
% ROI_cols     : vector of column indices used as background
% display_fig  : true/false
%
% OUTPUTS
% I_corr       : corrected stack
% sigma_map    : local noise map
% sigma_spec   : estimated noise for each wavelength
% plane_stack  : fitted background plane
%
% Example
%
% [I_corr,sigma_map,sigma_spec] = ...
%      remove_planar_background(imgs,30:40,50:60,true);
%
%--------------------------------------------------------------------------

if nargin<4
    display_fig=false;
end

I_raw = squeeze(imgs);

[Nx,Ny,Nlambda] = size(I_raw);

I_corr     = zeros(size(I_raw));
plane_stack= zeros(size(I_raw));
SNR  = zeros(size(I_raw));
sigma_spec = zeros(Nlambda,1);

%% coordinates

[X,Y] = meshgrid(1:Ny,1:Nx);

%% ROI coordinates

XR = X(ROI_lines,ROI_cols);
YR = Y(ROI_lines,ROI_cols);

for ii=1:Nlambda

    img = I_raw(:,:,ii);

    %% -------- Fit plane z=ax+by+c -----------------------------

    ZR = img(ROI_lines,ROI_cols);

    A = [XR(:) YR(:) ones(numel(XR),1)];

    coef = A\ZR(:);

    plane = coef(1)*X + coef(2)*Y + coef(3);

    plane_stack(:,:,ii)=plane;

    %% -------- Background subtraction --------------------------

    corr = img-plane;

    I_corr(:,:,ii)=corr;

    %% -------- Noise estimation -------------------------------

    residual = corr(ROI_lines,ROI_cols);

    sigma_spec(ii)=std(residual(:));

    %% -------- Local noise map --------------------------------

    SNR(:,:,ii)=corr/sigma_spec(ii);
end

fprintf('le bruit suit z = %d*x + %d*y + %d\n', coef(1), coef(2), coef(3));

%% ---------- Display ------------------------------------------

if display_fig

    lambda = display_lambda;

    % Choix d'une ligne et colonne au centre de la ROI bruit
    row0 = round(mean(ROI_lines));
    col0 = round(mean(ROI_cols));
    
    % Profils mesurés
    profile_row = I_raw(row0,:,lambda);
    profile_col = I_raw(:,col0,lambda);
    
    % Profil prédit par le plan déjà calculé
    fit_row = coef(1)*(1:Ny) + coef(2)*row0 + coef(3);
    fit_col = coef(1)*col0 + coef(2)*(1:Nx)' + coef(3);

    figure

    subplot(2,2,1)
    imagesc(I_raw(:,:,lambda))
    axis image
    colorbar
    title('Raw image')
    hold on
    
    % Contour de la ROI de fond
    rectangle('Position',...
        [ROI_cols(1)-0.5,...
         ROI_lines(1)-0.5,...
         length(ROI_cols),...
         length(ROI_lines)],...
         'EdgeColor','r',...
         'LineWidth',2)

    subplot(2,2,2)
    imagesc(plane_stack(:,:,lambda))
    axis image
    colorbar
    title('Estimated background')

    subplot(2,2,3)
    imagesc(I_corr(:,:,lambda))
    axis image
    colorbar
    title('Corrected')
    
    subplot(2,2,4)
    hold on
    
    % Ligne
    plot(1:Ny, profile_row, 'b', 'LineWidth',1.5)
    plot(1:Ny, fit_row, '--b', 'LineWidth',2)
    
    % Colonne
    plot(1:Nx, profile_col, 'r', 'LineWidth',1.5)
    plot(1:Nx, fit_col, '--r', 'LineWidth',2)
    
    
    xlabel('Pixel')
    ylabel('Intensity (a.u.)')
    
    legend('Measured row',...
           'Plane fit row',...
           'Measured column',...
           'Plane fit column',...
           'Location','best')
    
    title(sprintf('Plan verification : a=%.3g, b=%.3g, c=%.3g',...
        coef(1),coef(2),coef(3)))
    
    grid on

end

end