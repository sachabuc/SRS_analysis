function attenuation_factor(imgs,n2)
    img = squeeze(imgs);

    alpha = linspace(0,2,300);
    Nalpha = length(alpha);
    
    [Nx, Ny, Nlambda] = size(img);
    
    metric = zeros(Nalpha, Nlambda);
    
    labels = {'calcite', 'fluo', 'ACC', 'ACChira', 'fluo2'};
    
    figure(); hold on;
    
    legend_entries = cell(1, Nlambda);
    
    for tt = 1:Nlambda
        
        I = double(img(:,:,tt));
        Ifluo = double(img(:,:,n2));
        
        for k = 1:Nalpha
            dI = I - alpha(k)*Ifluo;
            metric(k,tt) = sum(abs(dI(:)));
        end
        
        % Trouver le minimum
        [val_min, idx_min] = min(metric(:,tt));
        alpha_min = alpha(idx_min);
        
    
        % Plot courbe
        plot(alpha, metric(:,tt), 'LineWidth', 1.5);
        
        % Marquer le minimum
        % plot(alpha_min, val_min, 'o', 'MarkerSize', 6, 'LineWidth', 1.5);
        
        % Légende avec info physique + alpha optimal
        legend_entries{tt} = sprintf('%s (\\alpha_{opt}=%.2f)', ...
            labels{tt}, alpha_min);
    end
    
    xlabel('coefficient d''atténuation \alpha', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('|I_i - \alpha I_{fluo}| (a.u.)', 'FontSize', 12, 'FontWeight', 'bold');
    title('Recherche du \alpha optimal', 'FontSize', 14, 'FontWeight', 'bold');
    grid on;
    set(gca, 'FontSize', 10);
    
    legend(legend_entries, 'Location', 'best');
    
    hold off;
end