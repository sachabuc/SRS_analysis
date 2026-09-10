function [fit_params, mean_noise] = noise_study(img, wavenumber, background_spectrum, idl, idc, wi, x1_s, x1_e, x2_s, x2_e)
    imgs = squeeze(img);
    nk = size(imgs, 3);

    [wavenumber, sort_idx] = sort(wavenumber(:).');


    % Vérifier que wi est valide
    if wi < 1 || wi > nk
        error('wi doit être compris entre 1 et %d', nk);
    end

    % Extraire uniquement l'image associée à wi
    img_wi = imgs(:, :, wi);

    % Extraire la portion de la ligne idl entre x2_s et x2_e
    line_profile = img_wi(idl, x2_s:x2_e);

    % Extraire la portion de la colonne idc entre x1_s et x1_e
    column_profile = img_wi(x1_s:x1_e, idc);

    % Affichage des profils extraits
    figure();

    % Profils de ligne
    subplot(1, 3, 1);
    plot(wavenumber, background_spectrum, 'r-', 'DisplayName', sprintf('Line Profile (wi=%d)', wi));
    xlabel('wavenumber');
    ylabel('Intensité');
    title('Profil spectral - background soustrait');
    grid on;


    subplot(1, 3, 2);
    plot(x2_s:x2_e, line_profile, 'g-', 'DisplayName', sprintf('Line Profile (wi=%d)', wi));
    xlabel('Pixel (x2)');
    ylabel('Intensité');
    title('Profil de ligne (portion)');
    grid on;
    legend show;

    % Profils de colonne
    subplot(1, 3, 3);
    plot(x1_s:x1_e, column_profile, 'b-', 'DisplayName', sprintf('Column Profile (wi=%d)', wi));
    xlabel('Pixel (x1)');
    ylabel('Intensité');
    title('Profil de colonne (portion)');
    grid on;
    legend show;

    % Fit linéaire sur la ligne
    x_line = x2_s:x2_e;
    p_line = polyfit(x_line, line_profile, 1); % Fit linéaire (degré 1)
    fit_line = polyval(p_line, x_line);
    residuals_line = line_profile - fit_line;
    mean_noise_line = std(residuals_line); % Bruit = écart-type des résidus

    % Fit linéaire sur la colonne
    x_column = x1_s:x1_e;
    p_column = polyfit(x_column, column_profile, 1);
    fit_column = polyval(p_column, x_column);
    residuals_column = column_profile - fit_column;
    mean_noise_column = std(residuals_column);

    % Afficher les fits
    subplot(1, 3, 2);
    hold on;
    plot(x_line, fit_line, 'r--', 'DisplayName', 'Fit linéaire');
    hold off;

    subplot(1, 3, 3);
    hold on;
    plot(x_column, fit_column, 'r--', 'DisplayName', 'Fit linéaire');
    hold off;

    % Retourner les paramètres du fit et le bruit moyen
    fit_params.line = p_line; % [pente, ordonnée à l'origine]
    fit_params.column = p_column;
    mean_noise.line = mean_noise_line;
    mean_noise.column = mean_noise_column;
end