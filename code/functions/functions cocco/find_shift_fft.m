function [dx, dy] = find_shift_fft(I_ref, I)

%% phase correlation 
    % F1 = fft2(I_ref);
    % F2 = fft2(I);
    % 
    % R = F1 .* conj(F2);
    % Rnorm = R ./ abs(R + eps); % normalisation
    % 
    % 
    % r = ifft2(Rnorm);
    % 
    % [val_max, idx] = max(r(:));
    % [ypeak, xpeak] = ind2sub(size(r), idx);
    % 
    % figure
    % plot(r(:))
    % title('Cross-Correlation')
    % hold on
    % plot(idx,val_max,'or')
    % hold off
    % text(idx*1.05,val_max,'Maximum')
    % 
    % [Nx, Ny] = size(I_ref);
    % 
    % dx = xpeak - Ny;
    % dy = ypeak - Nx;

%% amplitude correlation 
    x1_s=62;
    x1_e=85;
    x2_s=81;
    x2_e=100;
    
    C = xcorr2(I(x1_s:x1_e,x2_s:x2_e), I_ref(x1_s:x1_e,x2_s:x2_e));  % corrélation croisée

    
    % Trouver le maximum
    [val_max, idx] = max(C(:));
    [ypeak, xpeak] = ind2sub(size(C), idx);

    figure
    plot(C(:))
    title('Cross-Correlation')
    hold on
    plot(idx,val_max,'or')
    hold off
    text(idx*1.05,val_max,'Maximum')

    % Calcul du shift
    dx = xpeak - size(I_ref,2);
    dy = ypeak - size(I_ref,1);
    
end