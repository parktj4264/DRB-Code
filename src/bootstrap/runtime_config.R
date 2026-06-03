#' @title Runtime Config Helpers
#' @description Runtime config initialization, loading, merge, and logging helpers.

initialize_runtime_context <- function(main_env = parent.frame()) {
  initial_object_names <- ls(envir = main_env, all.names = TRUE)

  if (!exists("METRIC_PARAMS", envir = main_env, inherits = TRUE)) {
    assign("METRIC_PARAMS", NULL, envir = main_env)
  }
  if (!exists("METRIC_PARAMS_FILE", envir = main_env, inherits = TRUE)) {
    assign("METRIC_PARAMS_FILE", here::here("config", "metric_config.R"), envir = main_env)
  }
  if (!exists("GENERAL_CONFIG", envir = main_env, inherits = TRUE)) {
    assign("GENERAL_CONFIG", NULL, envir = main_env)
  }
  if (!exists("GENERAL_CONFIG_FILE", envir = main_env, inherits = TRUE)) {
    assign("GENERAL_CONFIG_FILE", here::here("config", "general_config.R"), envir = main_env)
  }
  if (!exists("PPT_CONFIG", envir = main_env, inherits = TRUE)) {
    assign("PPT_CONFIG", NULL, envir = main_env)
  }
  if (!exists("PPT_CONFIG_FILE", envir = main_env, inherits = TRUE)) {
    assign("PPT_CONFIG_FILE", here::here("config", "ppt_config.R"), envir = main_env)
  }
  if (!exists("NA_POLICY", envir = main_env, inherits = TRUE)) {
    assign("NA_POLICY", NULL, envir = main_env)
  }

  initial_object_names
}

load_metric_params_file <- function(metric_params_file) {
  if (is.null(metric_params_file) || length(metric_params_file) == 0) {
    return(list(
      path = NULL,
      loaded = FALSE,
      params = NULL
    ))
  }

  file_path <- as.character(metric_params_file[[1]])
  if (identical(file_path, "")) {
    return(list(
      path = NULL,
      loaded = FALSE,
      params = NULL
    ))
  }

  if (!file.exists(file_path)) {
    return(list(
      path = file_path,
      loaded = FALSE,
      params = NULL
    ))
  }

  cfg_env <- new.env(parent = baseenv())
  sys.source(file_path, envir = cfg_env)

  if (!exists("METRIC_PARAMS", envir = cfg_env, inherits = FALSE)) {
    stop("METRIC_PARAMS_FILE does not define METRIC_PARAMS: ", file_path)
  }

  list(
    path = file_path,
    loaded = TRUE,
    params = get("METRIC_PARAMS", envir = cfg_env, inherits = FALSE)
  )
}

load_named_list_config_file <- function(config_file, object_name) {
  if (is.null(config_file) || length(config_file) == 0) {
    return(list(
      path = NULL,
      loaded = FALSE,
      value = NULL
    ))
  }

  file_path <- as.character(config_file[[1]])
  if (identical(file_path, "")) {
    return(list(
      path = NULL,
      loaded = FALSE,
      value = NULL
    ))
  }

  if (!file.exists(file_path)) {
    return(list(
      path = file_path,
      loaded = FALSE,
      value = NULL
    ))
  }

  cfg_env <- new.env(parent = baseenv())
  sys.source(file_path, envir = cfg_env)

  if (!exists(object_name, envir = cfg_env, inherits = FALSE)) {
    stop("Configuration file does not define ", object_name, ": ", file_path)
  }

  cfg_value <- get(object_name, envir = cfg_env, inherits = FALSE)
  if (!is.list(cfg_value)) {
    stop(object_name, " must be a named list in ", file_path)
  }

  list(
    path = file_path,
    loaded = TRUE,
    value = cfg_value
  )
}

normalize_named_list <- function(values = NULL, label = "config") {
  if (is.null(values)) {
    return(list())
  }

  if (!is.list(values)) {
    stop(label, " must be a named list or NULL.")
  }

  if (length(values) == 0) {
    return(list())
  }

  if (is.null(names(values))) {
    stop(label, " must use named entries.")
  }

  values[names(values) != ""]
}

merge_flat_config_values <- function(defaults, file_values = NULL, run_values = NULL,
                                     label = "CONFIG") {
  if (!is.list(defaults) || is.null(names(defaults))) {
    stop("defaults must be a named list.")
  }

  merged <- defaults
  known_keys <- names(defaults)

  apply_values <- function(values, source_name) {
    value_list <- normalize_named_list(values, label = paste0(label, " (", source_name, ")"))
    if (length(value_list) == 0) {
      return(invisible(NULL))
    }

    unknown_keys <- setdiff(names(value_list), known_keys)
    if (length(unknown_keys) > 0) {
      log_msg(paste0(
        "[Warning] Unknown ", label, " keys ignored from ", source_name, ": ",
        paste(unknown_keys, collapse = ", ")
      ))
    }

    for (key in intersect(names(value_list), known_keys)) {
      merged[[key]] <<- value_list[[key]]
    }

    invisible(NULL)
  }

  apply_values(file_values, "file")
  apply_values(run_values, "run.R")
  merged
}

merge_metric_params <- function(file_params = NULL, run_params = NULL) {
  merged <- normalize_metric_params(file_params)
  run_norm <- normalize_metric_params(run_params)

  if (length(run_norm) > 0) {
    for (metric_name in names(run_norm)) {
      merged[[metric_name]] <- run_norm[[metric_name]]
    }
  }

  merged
}

build_metric_param_log_lines <- function(metric_param_summary,
                                         metric_params_file_info = NULL,
                                         run_params = NULL) {
  lines <- c(
    "Metric Parameter Configuration:",
    "  Priority: run.R METRIC_PARAMS > METRIC_PARAMS_FILE"
  )

  file_line <- "  METRIC_PARAMS_FILE: (disabled)"
  if (!is.null(metric_params_file_info$path)) {
    if (isTRUE(metric_params_file_info$loaded)) {
      file_line <- paste0("  METRIC_PARAMS_FILE: loaded from ", metric_params_file_info$path)
    } else {
      file_line <- paste0("  METRIC_PARAMS_FILE: not found (", metric_params_file_info$path, ")")
    }
  }
  lines <- c(lines, file_line)

  run_has_override <- FALSE
  if (!is.null(run_params)) {
    run_has_override <- length(normalize_metric_params(run_params)) > 0
  }
  lines <- c(lines, paste0("  run.R METRIC_PARAMS override: ", if (run_has_override) "yes" else "no"))

  if (is.null(metric_param_summary) || nrow(metric_param_summary) == 0) {
    return(c(lines, "Metric Parameters Used: (no tunable metric parameters found)"))
  }

  out <- c(lines, "Metric Parameters Used:")
  metric_names <- unique(as.character(metric_param_summary$metric_name))

  for (metric_name_i in metric_names) {
    out <- c(out, paste0("  [", metric_name_i, "]"))
    metric_rows <- metric_param_summary[metric_name == metric_name_i]
    for (i in seq_len(nrow(metric_rows))) {
      out <- c(out, sprintf(
        "    - %s = %s (%s)",
        as.character(metric_rows$param_name[i]),
        as.character(metric_rows$param_value[i]),
        as.character(metric_rows$source[i])
      ))
    }
  }

  out
}

GENERAL_CONFIG_DEFAULTS <- list(
  NA_POLICY = "na",
  GOOD_CHIP_LIMIT_HOT = NULL,
  GOOD_CHIP_LIMIT_COLD = NULL,
  GOOD_CHIP_RULE_HOT = NULL,
  GOOD_CHIP_RULE_COLD = NULL
)

PPT_CONFIG_DEFAULTS <- list(
  summary_rows_per_slide = 15L,
  detail_top_n = 8L,
  detail_grid_ncol = 4L,
  detail_grid_nrow = 2L,
  slide_width = 13.33,
  slide_height = 7.5,
  margin_top = 1.2,
  margin_left = 0.5,
  margin_right = 0.5,
  margin_bottom = 0.5,
  jitter_width = 0.2,
  jitter_alpha = 0.6,
  jitter_size = 1.5,
  mean_point_size = 3,
  title_size = 11,
  axis_x_angle = 30,
  axis_text_size = 10,
  axis_title_size = 9,
  plot_dpi = 150,
  color_palette = "Set1",
  up_color = "red",
  down_color = "blue",
  detail_plot_mode = "composite_v1",
  composite_row_heights = c(1.1, 0.75, 1.15),
  composite_bottom_split = c(1, 2),
  radius_scatter_alpha = 0.55,
  radius_scatter_size = 0.8,
  radius_ref_color = "#2d74b3",
  radius_tgt_color = "#de2d26",
  rootid_avg_point_size = 2.2,
  rootid_avg_line_alpha = 0.45,
  rootid_avg_axis_x_angle = 70,
  rootid_avg_axis_text_size = 6,
  rootid_avg_title_size = 8,
  cdf_ref_color = "#2d74b3",
  cdf_tgt_color = "#de2d26",
  cdf_line_size = 0.8,
  cdf_title_size = 8,
  wf_map_point_size = 3.2,
  wf_map_stroke = 0.2,
  wf_map_stroke_color = "#666666",
  wf_map_color_mode = "percentile",
  wf_map_percentiles = c(0, 0.25, 0.50, 0.75, 0.99),
  wf_map_percentile_colors = c("#1B9E4B", "#4EA3D8", "#fed339", "#F28E2B", "#D62728"),
  wf_map_low_color = "#2166AC",
  wf_map_mid_color = "#F7F7F7",
  wf_map_high_color = "#B2182B",
  wf_map_midpoint = NA_real_,
  wf_map_title_size = 6,
  wf_map_strip_text_size = 3.8,
  wf_map_strip_text_color = "#666666",
  wf_map_panel_spacing_pt = 0,
  wf_map_axis_text_size = 4.5,
  wf_map_axis_tick_linewidth = 0.15
)

resolve_runtime_config <- function(initial_object_names) {
  general_config_file_info <- load_named_list_config_file(
    GENERAL_CONFIG_FILE,
    "GENERAL_CONFIG"
  )
  ppt_config_file_info <- load_named_list_config_file(
    PPT_CONFIG_FILE,
    "PPT_CONFIG"
  )

  legacy_general_override <- list()
  for (key in names(GENERAL_CONFIG_DEFAULTS)) {
    if (key %in% initial_object_names) {
      legacy_general_override[[key]] <- get(key, inherits = TRUE)
    }
  }

  general_config_resolved <- merge_flat_config_values(
    defaults = GENERAL_CONFIG_DEFAULTS,
    file_values = general_config_file_info$value,
    run_values = GENERAL_CONFIG,
    label = "GENERAL_CONFIG"
  )
  general_config_resolved <- merge_flat_config_values(
    defaults = general_config_resolved,
    file_values = NULL,
    run_values = legacy_general_override,
    label = "GENERAL_CONFIG (legacy variables)"
  )

  ppt_config_resolved <- merge_flat_config_values(
    defaults = PPT_CONFIG_DEFAULTS,
    file_values = ppt_config_file_info$value,
    run_values = PPT_CONFIG,
    label = "PPT_CONFIG"
  )

  list(
    general_config_file_info = general_config_file_info,
    ppt_config_file_info = ppt_config_file_info,
    general_config_resolved = general_config_resolved,
    ppt_config_resolved = ppt_config_resolved
  )
}

# Stage wrapper:
# - resolves config with precedence (run.R > config files > defaults)
# - logs loaded config paths
# - returns normalized runtime knobs for downstream stages
run_stage_runtime_config <- function(initial_object_names) {
  runtime_cfg <- resolve_runtime_config(initial_object_names)

  general_config_file_info <- runtime_cfg$general_config_file_info
  ppt_config_file_info <- runtime_cfg$ppt_config_file_info
  general_config_resolved <- runtime_cfg$general_config_resolved

  if (isTRUE(general_config_file_info$loaded)) {
    log_msg(paste0("Loaded general config: ", general_config_file_info$path))
  }
  if (isTRUE(ppt_config_file_info$loaded)) {
    log_msg(paste0("Loaded PPT config: ", ppt_config_file_info$path))
  }

  list(
    general_config_file_info = general_config_file_info,
    ppt_config_file_info = runtime_cfg$ppt_config_file_info,
    general_config_resolved = general_config_resolved,
    ppt_config_resolved = runtime_cfg$ppt_config_resolved,
    NA_POLICY = general_config_resolved$NA_POLICY,
    GOOD_CHIP_LIMIT_HOT = general_config_resolved$GOOD_CHIP_LIMIT_HOT,
    GOOD_CHIP_LIMIT_COLD = general_config_resolved$GOOD_CHIP_LIMIT_COLD,
    GOOD_CHIP_RULE_HOT = general_config_resolved$GOOD_CHIP_RULE_HOT,
    GOOD_CHIP_RULE_COLD = general_config_resolved$GOOD_CHIP_RULE_COLD
  )
}
