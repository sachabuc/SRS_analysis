function mask = create_rectangle_mask(image_size, x1, x2, y1, y2)
%CREATE_RECTANGLE_MASK Crée un masque rectangulaire
%
% image_size : taille de l'image [n_y, n_x]
% x1, x2     : limites en x (colonnes)
% y1, y2     : limites en y (lignes)
%
% mask       : masque logique [n_y x n_x]

n_y = image_size(1);
n_x = image_size(2);

mask = false(n_y, n_x);

mask(y1:y2, x1:x2) = true;

end