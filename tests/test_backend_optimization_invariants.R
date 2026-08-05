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
stopifnot(isTRUE(ppt_defaults$wf_map_force_square_display))
stopifnot(isTRUE(ppt_defaults$wf_map_fill_available_space))
stopifnot(identical(ppt_defaults$detail_progress_log_every, 0L))
runtime_context <- new.env(parent = globalenv())
runtime_context_names <- initialize_runtime_context(runtime_context)
stopifnot(isTRUE(runtime_context$GENERATE_PPT))
stopifnot(isTRUE(runtime_context$GENERATE_SPOTFIRE))
stopifnot(!runtime_context$OPEN_SPOTFIRE)

ppt_ui_context <- new.env(parent = globalenv())
ppt_ui_context$PPT_LAYOUT_MODE <- "dev"
ppt_ui_context$PPT_SLIDE_TITLE <- "UI Title"
ppt_ui_context$PPT_AFFILIATION <- "UI Team"
ppt_ui_context$PPT_SCATTER_TRIM_IQR <- FALSE
ppt_ui_context$PPT_SCATTER_SHOW_MEAN <- TRUE
ppt_ui_context$PPT_CATEGORY_SCOPE <- list(Category2 = c("WTC", "WLS"))
ppt_ui_context$PPT_CATEGORY_ORDER_FILE <- NULL
ppt_ui_initial_names <- initialize_runtime_context(ppt_ui_context)
ppt_ui_overrides <- collect_ppt_ui_overrides(
  ppt_ui_initial_names,
  main_env = ppt_ui_context
)
stopifnot(identical(
  ppt_ui_overrides,
  list(
    ppt_layout_mode = "dev",
    slide_title = "UI Title",
    slide_affiliation = "UI Team",
    radius_scatter_trim_iqr = FALSE,
    radius_scatter_show_mean = TRUE,
    ppt_category_scope = list(Category2 = c("WTC", "WLS")),
    ppt_category_order_file = NULL
  )
))

ppt_runtime_env <- new.env(parent = globalenv())
sys.source("src/bootstrap/runtime_config.R", envir = ppt_runtime_env)
ppt_runtime_env$PPT_LAYOUT_MODE <- "dev"
ppt_runtime_env$PPT_SLIDE_TITLE <- "Mapped Title"
ppt_runtime_env$PPT_AFFILIATION <- "Mapped Team"
ppt_runtime_env$PPT_SCATTER_TRIM_IQR <- 7
ppt_runtime_env$PPT_SCATTER_SHOW_MEAN <- FALSE
ppt_runtime_env$PPT_CATEGORY_SCOPE <- NULL
ppt_runtime_env$PPT_CATEGORY_ORDER_FILE <- NULL
ppt_runtime_initial <- ppt_runtime_env$initialize_runtime_context(ppt_runtime_env)
ppt_runtime_stage <- ppt_runtime_env$run_stage_runtime_config(
  ppt_runtime_initial,
  main_env = ppt_runtime_env
)
stopifnot(ppt_runtime_stage$ppt_config_resolved$ppt_layout_mode == "dev")
stopifnot(ppt_runtime_stage$ppt_config_resolved$slide_title == "Mapped Title")
stopifnot(ppt_runtime_stage$ppt_config_resolved$slide_affiliation == "Mapped Team")
stopifnot(ppt_runtime_stage$ppt_config_resolved$radius_scatter_trim_iqr == 7)
stopifnot(!ppt_runtime_stage$ppt_config_resolved$radius_scatter_show_mean)
stopifnot(is.null(ppt_runtime_stage$ppt_config_resolved$ppt_category_scope))
stopifnot(is.null(ppt_runtime_stage$ppt_config_resolved$ppt_category_order_file))

run_lines <- readLines("run.R", warn = FALSE, encoding = "UTF-8")
stopifnot(!any(grepl("^PPT_LAYOUT_MODE\\s*<-", run_lines)))
stopifnot(any(grepl("^# 1\\. DRB Analysis$", run_lines)))
stopifnot(any(grepl("^# 2\\. Output Controls$", run_lines)))
stopifnot(any(grepl("^# 3\\. PPT Presentation$", run_lines)))

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
