# Regression test: detail-plot acceleration must keep extremes and exact CDF ranks.
source("src/bootstrap/libs.R", local = environment())
source("src/bootstrap/utils.R", local = environment())
source("src/bootstrap/ppt_defaults.R", local = environment())
source("src/03_create_ppt.R", local = environment())

cfg <- build_ppt_defaults()
stopifnot(identical(cfg$composite_bottom_split, c(1.15, 1.85)))
stopifnot(cfg$radius_scatter_max_points_per_side == 2000L)
stopifnot(cfg$cdf_max_points_per_side == 1000L)
stopifnot(cfg$goobae_y_label_font_size == 4.0)
stopifnot(cfg$goobae_y_label_font_face == "bold")
stopifnot(cfg$goobae_y_label_dpi == 600L)
stopifnot(is.na(cfg$wf_map_outline_color))
stopifnot(is.na(cfg$wf_map_missing_fill))

row_count <- 10000L
ref_values <- seq_len(row_count)
ref_values[[row_count %/% 2L]] <- -1e9
ref_values[[row_count]] <- 1e9
scatter_dt <- data.table::data.table(
  Side = factor(
    rep(c("REF", "TARGET"), each = row_count),
    levels = c("REF", "TARGET")
  ),
  Radius = rep(seq_len(row_count), 2L),
  value = c(ref_values, rev(ref_values))
)

thinned_a <- thin_radius_scatter_rows(scatter_dt, 2000L)
thinned_b <- thin_radius_scatter_rows(scatter_dt, 2000L)
set.seed(20260729)
thinned_shuffled <- thin_radius_scatter_rows(scatter_dt[sample(.N)], 2000L)
stopifnot(identical(thinned_a, thinned_b))
stopifnot(identical(thinned_a, thinned_shuffled))
stopifnot(all(thinned_a[, .N, by = Side]$N == 2000L))
stopifnot(min(thinned_a[Side == "REF", value]) == -1e9)
stopifnot(max(thinned_a[Side == "REF", value]) == 1e9)
stopifnot(min(thinned_a[Side == "REF", Radius]) == 1)
stopifnot(max(thinned_a[Side == "REF", Radius]) == row_count)

cdf_dt <- build_cdf_curve_data(scatter_dt, 1000L)
stopifnot(all(cdf_dt[, .N, by = Side]$N <= 1001L))
stopifnot(all(cdf_dt[, min(cdf), by = Side]$V1 == 0))
stopifnot(all(cdf_dt[, max(cdf), by = Side]$V1 == 1))
stopifnot(min(cdf_dt[Side == "REF", value]) == -1e9)
stopifnot(max(cdf_dt[Side == "REF", value]) == 1e9)

mass_values <- c(0:249, rep(250, 100000L), 251:1001)
mass_cdf <- build_cdf_curve_data(
  data.table::data.table(Side = "REF", value = mass_values),
  1000L
)
expected_mass_cdf <- (250 + 100000) / length(mass_values)
stopifnot(250 %in% mass_cdf$value)
stopifnot(abs(mass_cdf[value == 250, max(cdf)] - expected_mass_cdf) < 1e-12)

plot_input <- data.table::data.table(
  GROUP = rep(c("A", "B"), each = row_count),
  Radius = rep(seq_len(row_count), 2L),
  M1 = c(ref_values, rev(ref_values))
)
radius_plot <- build_radius_scatter_combined_plot(
  plot_input,
  "M1",
  "A",
  "B",
  cfg
)
stopifnot(nrow(radius_plot$data) == 4000L)
stopifnot(min(radius_plot$data$value) == -1e9)
stopifnot(max(radius_plot$data$value) == 1e9)

cdf_plot <- build_cdf_plot(plot_input, "M1", "A", "B", cfg)
stopifnot(inherits(cdf_plot$layers[[1L]]$geom, "GeomStep"))
stopifnot(nrow(cdf_plot$data) <= 2002L)
stopifnot(all(range(cdf_plot$data$cdf) == c(0, 1)))

copy_dir <- tempfile("ppt_atomic_copy_")
dir.create(copy_dir)
copy_source <- file.path(copy_dir, "archive.pptx")
copy_target <- file.path(copy_dir, "latest.pptx")
writeBin(as.raw(c(1, 2, 3, 4, 5)), copy_source)
writeBin(as.raw(c(9, 9, 9)), copy_target)
atomic_copy_file(copy_source, copy_target)
stopifnot(identical(
  readBin(copy_target, what = "raw", n = file.info(copy_target)$size),
  as.raw(c(1, 2, 3, 4, 5))
))
stopifnot(length(list.files(copy_dir, pattern = "\\.(tmp|bak)$")) == 0L)
unlink(copy_dir, recursive = TRUE, force = TRUE)

cat("PASS: test_ppt_render_optimization.R\n")
