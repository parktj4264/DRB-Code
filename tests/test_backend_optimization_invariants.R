# Backend invariants: optimized paths must preserve public values and defaults.
source("src/bootstrap/libs.R", local = environment())
source("src/bootstrap/utils.R", local = environment())
source("src/02_calc_stats.R", local = environment())
source("src/bootstrap/runtime_config.R", local = environment())
source("src/03_create_ppt.R", local = environment())

ppt_defaults <- build_ppt_defaults()
runtime_defaults <- build_ppt_defaults(order = "runtime")
stopifnot(identical(PPT_CONFIG_DEFAULTS, runtime_defaults))
stopifnot(setequal(names(ppt_defaults), names(runtime_defaults)))
stopifnot(identical(ppt_defaults, runtime_defaults[names(ppt_defaults)]))
stopifnot(identical(ppt_defaults$slide_title, "[DM] DRB Statistical Auto Report"))
stopifnot(identical(ppt_defaults$ppt_font_family, "Malgun Gothic"))
stopifnot(identical(ppt_defaults$detail_grid_ncol, 4L))
stopifnot(identical(ppt_defaults$detail_grid_nrow, 2L))
stopifnot(identical(ppt_defaults$summary_table_width, 12.69))
stopifnot(identical(ppt_defaults$wf_map_coordinate_mode, "wafer_grid"))

dt <- data.table::data.table(
  ROOTID = c("R1", "R2", "T1", "T2"),
  GROUP = c("REF", "REF", "TGT", "TGT"),
  META = c("a", "b", "c", "d"),
  M1 = c(1, 2, 3, 4),
  M2 = c(NA_real_, 5, 6, Inf)
)

with_cache <- build_group_stats_and_raw_cache(
  dt,
  msr_cols = c("M1", "M2"),
  group_col = "GROUP",
  batch_size = 1L,
  include_raw_cache = TRUE
)
without_cache <- build_group_stats_and_raw_cache(
  dt,
  msr_cols = c("M1", "M2"),
  group_col = "GROUP",
  batch_size = 1L,
  include_raw_cache = FALSE
)

stopifnot(identical(with_cache$all_stats, without_cache$all_stats))
stopifnot(is.null(without_cache$meta_dt))
stopifnot(length(ls(without_cache$raw_cache_env, all.names = TRUE)) == 0L)
stopifnot(length(ls(with_cache$raw_cache_env, all.names = TRUE)) > 0L)

cat("PASS: test_backend_optimization_invariants.R\n")
