function drawROI(roi, color, label_text)
    row_start = roi(1); row_end = roi(2);
    col_start = roi(3); col_end = roi(4);
    rectangle('Position', [col_start, row_start, col_end-col_start, row_end-row_start], ...
              'EdgeColor', color, 'LineWidth', 2.5, 'LineStyle', '-');
    plot(NaN, NaN, '-', 'Color', color, 'LineWidth', 2.5, 'DisplayName', label_text);
end