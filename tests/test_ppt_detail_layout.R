# Test PPT detail plot layout stays inside the expanded detail content box.
source("src/03_create_ppt.R", local = environment())

tol <- 1e-8
cfg <- build_ppt_defaults()
layout <- calculate_detail_plot_layout(cfg, grid_ncol = 4L, grid_nrow = 2L)

stopifnot(abs(layout$left - 0.32) < tol)
stopifnot(abs(layout$top - 1.68) < tol)
stopifnot(abs(layout$right - 13.01) < tol)
stopifnot(abs(layout$bottom - 7.00) < tol)
stopifnot(abs(layout$width - 12.69) < tol)
stopifnot(abs(layout$height - 5.32) < tol)
stopifnot(layout$table_nrow == 5L)
stopifnot(abs(layout$cell_w - 3.1725) < tol)
stopifnot(abs(layout$cell_h - 2.50) < tol)
stopifnot(abs(layout$cell_padding - 0.04) < tol)
stopifnot(abs(layout$label_height - 0.25) < tol)
stopifnot(abs(layout$label_plot_gap - 0.03) < tol)
stopifnot(abs(layout$header_row_h - 0.32) < tol)
stopifnot(abs(layout$body_top - 2.00) < tol)
stopifnot(abs(layout$body_h - 5.00) < tol)
stopifnot(abs(layout$label_row_h - 0.32) < tol)
stopifnot(abs(layout$plot_row_h - 2.18) < tol)
stopifnot(abs(layout$plot_w - 3.0925) < tol)
stopifnot(abs(layout$plot_h - 2.14) < tol)

positions <- lapply(seq_len(8L), function(index) {
  detail_layout_for_index(layout, index)
})

cell_right_edge <- max(vapply(positions, function(pos) pos$cell_left + layout$cell_w, numeric(1)))
cell_bottom_edge <- max(vapply(positions, function(pos) pos$cell_top + layout$cell_h, numeric(1)))
stopifnot(abs(cell_right_edge - layout$right) < tol)
stopifnot(abs(cell_bottom_edge - layout$bottom) < tol)

plot_right_edge <- max(vapply(positions, function(pos) pos$plot_left + pos$plot_w, numeric(1)))
plot_bottom_edge <- max(vapply(positions, function(pos) pos$plot_top + pos$plot_h, numeric(1)))
stopifnot(plot_right_edge <= layout$right + tol)
stopifnot(plot_bottom_edge <= layout$bottom + tol)

stopifnot(abs(positions[[1L]]$label_row_top - layout$body_top) < tol)
stopifnot(abs(positions[[1L]]$plot_row_top - (layout$body_top + layout$label_row_h)) < tol)
stopifnot(abs(positions[[1L]]$label_top - (layout$body_top + ((layout$label_row_h - layout$label_height) / 2))) < tol)
stopifnot(abs(positions[[1L]]$plot_top - positions[[1L]]$plot_row_top) < tol)

stopifnot(build_detail_label_text("ML_MSR_004", "Peri_PB_004", TRUE) == "\u2B24 (ML_MSR_004) Peri_PB_004")
stopifnot(build_detail_label_text("ML_MSR_004", "Peri_PB_004", FALSE) == "\u2B24 Peri_PB_004")
stopifnot(build_detail_label_text("ML_MSR_004", "", TRUE) == "\u2B24 (ML_MSR_004) ML_MSR_004")
stopifnot(resolve_detail_marker_color("Up", cfg) == "#D62728")
stopifnot(resolve_detail_marker_color("Down", cfg) == "#2CA02C")
stopifnot(resolve_detail_marker_color("Stable", cfg) == "#8C8C8C")

cat("PASS: test_ppt_detail_layout.R\n")
