# Test PPT detail plot layout stays inside the corporate safe content box.
source("src/03_create_ppt.R", local = environment())

tol <- 1e-8
cfg <- build_ppt_defaults()
layout <- calculate_detail_plot_layout(cfg, grid_ncol = 4L, grid_nrow = 2L)

stopifnot(abs(layout$left - 0.95) < tol)
stopifnot(abs(layout$top - 2.45) < tol)
stopifnot(abs(layout$right - 12.38) < tol)
stopifnot(abs(layout$bottom - 6.85) < tol)
stopifnot(abs(layout$width - 11.43) < tol)
stopifnot(abs(layout$height - 4.40) < tol)
stopifnot(abs(layout$plot_gap - 0.08) < tol)
stopifnot(abs(layout$plot_w - 2.7975) < tol)
stopifnot(abs(layout$plot_h - 2.16) < tol)

positions <- lapply(seq_len(8L), function(index) {
  row_idx <- floor((index - 1L) / 4L)
  col_idx <- (index - 1L) %% 4L
  list(
    left = layout$left + (col_idx * (layout$plot_w + layout$plot_gap)),
    top = layout$top + (row_idx * (layout$plot_h + layout$plot_gap))
  )
})

right_edge <- max(vapply(positions, function(pos) pos$left + layout$plot_w, numeric(1)))
bottom_edge <- max(vapply(positions, function(pos) pos$top + layout$plot_h, numeric(1)))
stopifnot(abs(right_edge - layout$right) < tol)
stopifnot(abs(bottom_edge - layout$bottom) < tol)

horizontal_gap <- positions[[2L]]$left - (positions[[1L]]$left + layout$plot_w)
vertical_gap <- positions[[5L]]$top - (positions[[1L]]$top + layout$plot_h)
stopifnot(abs(horizontal_gap - 0.08) < tol)
stopifnot(abs(vertical_gap - 0.08) < tol)

cat("PASS: test_ppt_detail_layout.R\n")
