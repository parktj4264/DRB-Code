# Regression test: WFMAP logical-grid mode must stay large across offsets,
# scale changes, floating jitter, and isolated coordinates.
source("src/bootstrap/libs.R", local = environment())
source("src/bootstrap/utils.R", local = environment())
source("src/03_create_ppt.R", local = environment())

cfg <- resolve_ppt_config(list(
  wf_map_coordinate_mode = "wafer_grid",
  wf_map_panel_arrangement = "auto",
  wf_map_force_square_display = TRUE,
  wf_map_show_axes = FALSE
))

base_grid <- data.table::CJ(X0 = 0:4, Y0 = 0:2)
ref_dt <- base_grid[, .(
  GROUP = "REF",
  ROOTID = "R1",
  X = X0,
  Y = Y0,
  M1 = X0 + Y0
)]
tgt_dt <- base_grid[, .(
  GROUP = "TGT",
  ROOTID = "T1",
  X = 10000 + (X0 * 1000),
  Y = -500 + (Y0 * 0.25),
  M1 = X0 + Y0 + 1
)]
offset_dt <- data.table::rbindlist(list(ref_dt, tgt_dt))

prepared <- prepare_wf_map_data(offset_dt, "M1", "REF", "TGT", cfg)
stopifnot(nrow(prepared$side_meta) == 2L)
stopifnot(all(abs(prepared$side_meta$width_units - 5) < 1e-12))
stopifnot(all(abs(prepared$side_meta$height_units - 3) < 1e-12))
coordinate_context <- prepare_wf_map_coordinate_context(offset_dt, "REF", "TGT", cfg)
cached_prepared <- prepare_wf_map_data(
  offset_dt,
  "M1",
  "REF",
  "TGT",
  cfg,
  coordinate_context = coordinate_context
)
stopifnot(isTRUE(all.equal(prepared$data, cached_prepared$data)))
stopifnot(isTRUE(all.equal(prepared$side_meta, cached_prepared$side_meta)))
value_cache <- prepare_wf_map_value_cache(
  offset_dt,
  "M1",
  coordinate_context,
  cfg
)
value_cached_prepared <- prepare_wf_map_data(
  offset_dt,
  "M1",
  "REF",
  "TGT",
  cfg,
  coordinate_context = coordinate_context,
  value_cache = value_cache
)
stopifnot(isTRUE(all.equal(prepared$data, value_cached_prepared$data)))

outlier_dt <- data.table::rbindlist(list(
  offset_dt,
  data.table::data.table(
    GROUP = "TGT",
    ROOTID = "T1",
    X = 1e9,
    Y = -500,
    M1 = 99
  )
))
outlier_prepared <- prepare_wf_map_data(outlier_dt, "M1", "REF", "TGT", cfg)
tgt_meta <- outlier_prepared$side_meta[as.character(Side) == "TARGET"]
stopifnot(tgt_meta$width_units < 10)

set.seed(20260729)
jitter_grid <- data.table::CJ(X0 = 0:9, Y0 = 0:9)
jitter_dt <- jitter_grid[, .(
  GROUP = "REF",
  ROOTID = "RJ",
  X = X0 + stats::rnorm(.N, sd = 1e-6),
  Y = Y0 + stats::rnorm(.N, sd = 1e-6),
  M1 = X0 - Y0
)]
jitter_prepared <- prepare_wf_map_data(jitter_dt, "M1", "REF", "TGT", cfg)
stopifnot(jitter_prepared$side_meta$width_units <= 20)
stopifnot(jitter_prepared$side_meta$height_units <= 20)

set.seed(20260730)
one_axis_jitter_dt <- jitter_grid[, .(
  GROUP = "REF",
  ROOTID = "RX",
  X = X0 + stats::rnorm(.N, sd = 1e-6),
  Y = Y0,
  M1 = X0 + Y0
)]
one_axis_jitter <- prepare_wf_map_data(one_axis_jitter_dt, "M1", "REF", "TGT", cfg)
stopifnot(one_axis_jitter$side_meta$width_units == 10)
stopifnot(one_axis_jitter$side_meta$height_units == 10)

edge_w1 <- data.table::CJ(X0 = 0:2, Y0 = 0:1)[, .(
  GROUP = "REF",
  ROOTID = "W1",
  X = X0,
  Y = Y0,
  M1 = X0 + Y0
)]
edge_w2 <- data.table::CJ(X0 = 1:2, Y0 = 0:1)[, .(
  GROUP = "REF",
  ROOTID = "W2",
  X = X0,
  Y = Y0,
  M1 = X0 + Y0
)]
edge_prepared <- prepare_wf_map_data(
  data.table::rbindlist(list(edge_w1, edge_w2)),
  "M1",
  "REF",
  "TGT",
  cfg
)
stopifnot(edge_prepared$side_meta$width_units == 3)
stopifnot(data.table::uniqueN(edge_prepared$data$plot_x) == 3L)
stopifnot(sum(edge_prepared$data$chip_n == 1L) == 2L)
stopifnot(sum(edge_prepared$data$chip_n == 2L) == 4L)

internal_gap_w1 <- data.table::CJ(X = c(0, 1, 3), Y = 0:1)[, .(
  GROUP = "REF",
  ROOTID = "G1",
  X,
  Y,
  M1 = X
)]
internal_gap_w2 <- data.table::CJ(X = c(0, 2, 3), Y = 0:1)[, .(
  GROUP = "REF",
  ROOTID = "G2",
  X,
  Y,
  M1 = X
)]
internal_gap <- prepare_wf_map_data(
  data.table::rbindlist(list(internal_gap_w1, internal_gap_w2)),
  "M1",
  "REF",
  "TGT",
  cfg
)
stopifnot(internal_gap$side_meta$width_units == 4)
stopifnot(data.table::uniqueN(internal_gap$data$plot_x) == 4L)
stopifnot(!any(internal_gap$data$chip_avg == 1.5))

shifted_origin <- data.table::rbindlist(list(
  data.table::CJ(X0 = 0:4, Y0 = 0:2)[, .(
    GROUP = "REF",
    ROOTID = "O1",
    X = X0,
    Y = Y0,
    M1 = X0 + Y0
  )],
  data.table::CJ(X0 = 0:4, Y0 = 0:2)[, .(
    GROUP = "REF",
    ROOTID = "O2",
    X = 100 + X0,
    Y = -50 + Y0,
    M1 = X0 + Y0
  )]
))
shifted_origin_prepared <- prepare_wf_map_data(
  shifted_origin,
  "M1",
  "REF",
  "TGT",
  cfg
)
stopifnot(shifted_origin_prepared$side_meta$width_units == 5)
stopifnot(shifted_origin_prepared$side_meta$height_units == 3)

scaled_frame <- data.table::rbindlist(list(
  data.table::CJ(X0 = 0:9, Y0 = 0:2)[, .(
    GROUP = "REF",
    ROOTID = "S1",
    X = X0,
    Y = Y0,
    M1 = X0 + Y0
  )],
  data.table::CJ(X0 = 0:9, Y0 = 0:2)[, .(
    GROUP = "REF",
    ROOTID = "S2",
    X = X0 * 1.2,
    Y = Y0,
    M1 = X0 + Y0
  )]
))
scaled_frame_prepared <- prepare_wf_map_data(
  scaled_frame,
  "M1",
  "REF",
  "TGT",
  cfg
)
stopifnot(scaled_frame_prepared$side_meta$width_units == 10)

half_shift_frame <- data.table::copy(scaled_frame)
half_shift_frame[ROOTID == "S2", X := (X / 1.2) + 0.5]
half_shift_prepared <- prepare_wf_map_data(
  half_shift_frame,
  "M1",
  "REF",
  "TGT",
  cfg
)
stopifnot(half_shift_prepared$side_meta$width_units == 10)

close_real_coordinates <- data.table::CJ(
  X = c(0, 0.1, 1, 2),
  Y = 0:1
)[, .(
  GROUP = "REF",
  ROOTID = "CLOSE",
  X,
  Y,
  M1 = X
)]
close_real_prepared <- prepare_wf_map_data(
  close_real_coordinates,
  "M1",
  "REF",
  "TGT",
  cfg
)
stopifnot(close_real_prepared$side_meta$width_units == 4)
stopifnot(!any(close_real_prepared$data$chip_avg == 0.05))
close_real_pair <- data.table::rbindlist(list(
  close_real_coordinates,
  data.table::copy(close_real_coordinates)[, ROOTID := "CLOSE_2"]
))
close_real_pair_prepared <- prepare_wf_map_data(
  close_real_pair,
  "M1",
  "REF",
  "TGT",
  cfg
)
stopifnot(close_real_pair_prepared$side_meta$width_units == 4)
stopifnot(all(close_real_pair_prepared$data$chip_n == 2L))

order_invariant_sets <- list(
  c(0, 1, 3, 4),
  c(0, 1, 2, 6),
  c(0, 3, 4, 5, 6)
)
build_order_invariant_dt <- function(root_ids) {
  data.table::rbindlist(Map(function(x_values, root_id) {
    data.table::CJ(X = x_values, Y = 0:1)[, .(
      GROUP = "REF",
      ROOTID = root_id,
      X,
      Y,
      M1 = X
    )]
  }, order_invariant_sets, root_ids))
}
order_prepared_a <- prepare_wf_map_data(
  build_order_invariant_dt(c("A", "B", "C")),
  "M1",
  "REF",
  "TGT",
  cfg
)
order_prepared_b <- prepare_wf_map_data(
  build_order_invariant_dt(c("C", "A", "B")),
  "M1",
  "REF",
  "TGT",
  cfg
)
order_data_a <- data.table::copy(order_prepared_a$data)
order_data_b <- data.table::copy(order_prepared_b$data)
order_data_a[, Side := as.character(Side)]
order_data_b[, Side := as.character(Side)]
data.table::setorderv(order_data_a, c("Side", "plot_y", "plot_x"))
data.table::setorderv(order_data_b, c("Side", "plot_y", "plot_x"))
stopifnot(isTRUE(all.equal(order_prepared_a$side_meta, order_prepared_b$side_meta)))
stopifnot(isTRUE(all.equal(order_data_a, order_data_b)))
stopifnot(order_prepared_a$side_meta$width_units == 7)
stopifnot(identical(sort(unique(order_data_a$chip_avg)), as.numeric(0:6)))

sparse_dt <- data.table::data.table(
  GROUP = "REF",
  ROOTID = "SPARSE",
  X = 0:99,
  Y = 0:99,
  M1 = 0:99
)
sparse_prepared <- prepare_wf_map_data(sparse_dt, "M1", "REF", "TGT", cfg)
stopifnot(nrow(sparse_prepared$data) == 100L)
stopifnot(sparse_prepared$side_meta$width_units == 100)
stopifnot(sparse_prepared$side_meta$height_units == 100)

legacy_cfg <- resolve_ppt_config(list(
  wf_map_color_mode = "legacy_gradient",
  wf_map_midpoint = 0
))
shared_scale <- build_wf_map_fill_scale(
  data.table::data.table(chip_avg = c(-100, 0, 1)),
  legacy_cfg
)
stopifnot(isTRUE(all.equal(shared_scale$limits, c(-100, 1))))
transparent_scale <- build_wf_map_fill_scale(
  data.table::data.table(chip_avg = c(NA_real_, 0, 1)),
  cfg
)
stopifnot(identical(transparent_scale$na.value, "transparent"))

bundle <- build_wf_map_plot(offset_dt, "M1", "REF", "TGT", cfg)
stopifnot(inherits(bundle, "wf_map_bundle"))
stopifnot(length(bundle$plots) == 2L)
stopifnot(choose_wf_map_panel_arrangement(bundle, width_in = 2.25, height_in = 0.95) == "horizontal")
stopifnot(inherits(bundle$plots[[1L]]$layers[[1L]]$geom, "GeomRaster"))
stopifnot(inherits(bundle$plots[[1L]]$theme$panel.border, "element_blank"))
stopifnot(identical(bundle$plots[[1L]]$theme$aspect.ratio, 1))

display_panel <- prepare_wf_map_display_panel(
  prepared,
  "REF",
  cfg
)
stopifnot(abs(display_panel$meta$width_units - 5) < 1e-12)
stopifnot(abs(display_panel$meta$height_units - 5) < 1e-12)
stopifnot(isTRUE(display_panel$force_square))

built <- ggplot2::ggplot_build(bundle$plots[[1L]])
tile_data <- built$data[[1L]]
stopifnot(all(abs((tile_data$xmax - tile_data$xmin) - 1) < 1e-12))
stopifnot(all(abs((tile_data$ymax - tile_data$ymin) - (5 / 3)) < 1e-12))
stopifnot(abs(
  (max(tile_data$xmax) - min(tile_data$xmin)) -
    (max(tile_data$ymax) - min(tile_data$ymin))
) < 1e-12)

panel_boxes <- calculate_wf_map_panel_boxes(
  bundle,
  width_in = 1.90,
  height_in = 1.02
)
stopifnot(nrow(panel_boxes) == 2L)
stopifnot(all(abs(panel_boxes$width_in - panel_boxes$height_in) < 1e-12))
stopifnot(min(panel_boxes$x_in - (panel_boxes$width_in / 2)) >= -1e-12)
stopifnot(max(panel_boxes$x_in + (panel_boxes$width_in / 2)) <= 1.90 + 1e-12)
stopifnot(min(panel_boxes$y_in - (panel_boxes$height_in / 2)) >= -1e-12)
stopifnot(max(panel_boxes$y_in + (panel_boxes$height_in / 2)) <= 1.02 + 1e-12)

natural_cfg <- resolve_ppt_config(list(
  wf_map_coordinate_mode = "wafer_grid",
  wf_map_force_square_display = FALSE
))
natural_display <- prepare_wf_map_display_panel(
  prepared,
  "REF",
  natural_cfg
)
stopifnot(abs(natural_display$meta$width_units - 5) < 1e-12)
stopifnot(abs(natural_display$meta$height_units - 3) < 1e-12)
stopifnot(!isTRUE(natural_display$force_square))

cat("PASS: test_ppt_wf_map.R\n")
