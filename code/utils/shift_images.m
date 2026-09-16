function I_raw_shifted = shift_images (I_raw,I_ref,dx,dy)


%% ================================================================
% Determination de la zone commune (sur les images ORIGINALES, pas
% pretraitees)
    [nrows, ncols] = size(I_ref);
    x_ref_start = max(1, 1-dx);
    x_ref_end   = min(ncols, ncols-dx);
    y_ref_start = max(1, 1-dy);
    y_ref_end   = min(nrows, nrows-dy);
     
    x_I_start = max(1, 1+dx);
    x_I_end   = min(ncols, ncols+dx);
    y_I_start = max(1, 1+dy);
    y_I_end   = min(nrows, nrows+dy);
     
    I_ref_crop = I_ref(y_ref_start:y_ref_end, x_ref_start:x_ref_end);
    I_raw_shifted     = I_raw(y_I_start:y_I_end, x_I_start:x_I_end);

%% ================================================================
% Soustraction
 
    I_diff = I_raw_shifted - I_ref_crop;

%% ================================================================
% Normalisation pour affichage
 
    I_ref_disp = (I_ref_crop - min(I_ref_crop(:))) / ...
                 (max(I_ref_crop(:)) - min(I_ref_crop(:)));
    I_disp = (I_raw_shifted - min(I_raw_shifted(:))) / ...
             (max(I_raw_shifted(:)) - min(I_raw_shifted(:)));
     
    m = max(abs(I_diff(:)));
    I_diff_disp = I_diff / m;

%% ================================================================
% Affichage
 
    figure
    subplot(1,3,1)
    imagesc(I_ref_disp,[0 1]); axis image; colorbar;
    title('Image de reference'); colormap(gca,parula);
     
    subplot(1,3,2)
    imagesc(I_disp,[0 1]); axis image; colorbar;
    title(sprintf('Image recalee (dx=%d, dy=%d)',dx,dy)); colormap(gca,parula);
     
    subplot(1,3,3)
    imagesc(I_diff_disp,[-1 1]); axis image; colorbar;
    title('Difference'); colormap(gca,parula);

% Si le recalage est bon, cette carte doit ressembler a du bruit sans
% structure -- des contours/formes encore visibles indiquent un
% decalage incorrect ou incomplet.

 