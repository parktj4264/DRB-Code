#' @title Main Orchestrator
#' @description Orchestrates the data loading, processing, and saving workflow.

# Measure Total Execution Time
start_time <- Sys.time()

if (!exists("NA_POLICY", inherits = TRUE)) {
  NA_POLICY <- "na"
}
if (!exists("METRIC_PARAMS", inherits = TRUE)) {
  METRIC_PARAMS <- NULL
}
if (!exists("METRIC_PARAMS_FILE", inherits = TRUE)) {
  METRIC_PARAMS_FILE <- here::here("config", "metric_params.R")
}

# 1. Source Helper & Core Functions
source("src/00_libs.R") # Ensures libraries are loaded even if main.R is run directly

source(here::here("src", "00_utils.R"))
source(here::here("src", "01_load_data.R"))
source(here::here("src", "02_calc_stats.R"))
source(here::here("src", "03_create_ppt.R"))

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

# Main Execution Block with Error Handling
tryCatch({
  log_msg(bold("=== Analysis Started ==="))

  # 2. Setup Resources
  # Construct Absolute Paths from User Parameters
  RAW_FILE  <- here::here("data", RAW_FILENAME)
  ROOT_FILE <- here::here("data", ROOT_FILENAME)

  # Load Data (now returns a list with dt and group info)
  load_res <- load_and_filter_data(
    RAW_FILE,
    ROOT_FILE,
    good_chip_limit_hot = if (exists("GOOD_CHIP_LIMIT_HOT", inherits = TRUE)) GOOD_CHIP_LIMIT_HOT else NULL,
    good_chip_limit_cold = if (exists("GOOD_CHIP_LIMIT_COLD", inherits = TRUE)) GOOD_CHIP_LIMIT_COLD else NULL,
    good_chip_rule_hot = if (exists("GOOD_CHIP_RULE_HOT", inherits = TRUE)) GOOD_CHIP_RULE_HOT else NULL,
    good_chip_rule_cold = if (exists("GOOD_CHIP_RULE_COLD", inherits = TRUE)) GOOD_CHIP_RULE_COLD else NULL
  )
  dt <- load_res$data
  msr_cols <- load_res$msr_cols
  wf_counts <- load_res$wf_counts # Get WF counts
  fallback_count_by_root <- load_res$fallback_count_by_root
  auto_good_count_by_root <- load_res$auto_good_count_by_root

  if (nrow(fallback_count_by_root) > 0) {
    log_msg("[GoodChip] Cold NA -> Hot fallback rows by ROOTID (top 10):")
    print(utils::head(fallback_count_by_root, 10))
  }

  if (nrow(auto_good_count_by_root) > 0) {
    log_msg("[GoodChip] Auto-good rows by ROOTID (no evaluable Cold/Hot bin value or no filter criteria; top 10):")
    print(utils::head(auto_good_count_by_root, 10))
  }

  log_msg("Data Loaded Successfully.")
  gc()

  metric_params_file_info <- load_metric_params_file(METRIC_PARAMS_FILE)
  metric_params_resolved <- merge_metric_params(
    file_params = metric_params_file_info$params,
    run_params = METRIC_PARAMS
  )
  if (isTRUE(metric_params_file_info$loaded)) {
    log_msg(paste0("Loaded metric parameter file: ", metric_params_file_info$path))
  }

  # 4. Calculate Sigma Score
  # result_dt is now a LIST
  calc_res <- calculate_sigma(dt, msr_cols,
    threshold   = SIGMA_THRESHOLD,
    ref_name    = GROUP_REF_NAME, 
    target_name = GROUP_TARGET_NAME,
    metric_params = metric_params_resolved,
    na_policy   = NA_POLICY
  )

  result_dt <- calc_res$res
  final_ref <- calc_res$ref
  final_tgt <- calc_res$tgt
  metric_runtime_summary <- calc_res$metric_runtime_summary
  metric_param_summary <- calc_res$metric_param_summary

  # 4b. Load MSR Info and Merge
  msrinfo_path <- here::here("data", "msrinfo.csv")
  if (file.exists(msrinfo_path)) {
    msr_info <- data.table::fread(msrinfo_path)
    result_dt <- merge(result_dt, msr_info, by.x = "MSR", by.y = "FIELD", all.x = TRUE)
    log_msg("Merged MSR Information successfully.")
  } else {
    log_msg("[Warning] msrinfo.csv not found in data/. PPT generation might be un-categorized.")
  }

  # 5. Save Results (Dual Output Strategy)

  # A. Overwrite fixed file (for Spotfire/Integration)
  output_path <- here::here("output", "results.csv")
  data.table::fwrite(result_dt, output_path)

  # B. Create Timestamped Archive
  timestamp_str <- format(Sys.time(), "%y%m%d_%H%M%S") # e.g., 260131_233045
  archive_dir <- here::here("output", paste0("results_", timestamp_str))

  if (!dir.exists(archive_dir)) dir.create(archive_dir, recursive = TRUE)

  # Save Timestamped CSV
  raw_base <- tools::file_path_sans_ext(RAW_FILENAME)
  archive_csv_name <- paste0("sigma_score_", raw_base, "_", timestamp_str, ".csv")
  archive_csv_path <- file.path(archive_dir, archive_csv_name)
  data.table::fwrite(result_dt, archive_csv_path)

  # Save metric issue report (always written with header, even when empty)
  issue_report <- write_metric_issue_reports(calc_res$metric_issues, archive_dir, timestamp_str)
  log_msg(paste0("Metric issue report (Latest):  ./output/", basename(issue_report$latest_path)))
  log_msg(paste0("Metric issue report (History): ./output/", basename(archive_dir), "/", basename(issue_report$archive_path)))

  end_time <- Sys.time()
  execution_time <- round(difftime(end_time, start_time, units = "mins"), 2)

  # Format WF Counts for Logging
  wf_str <- paste(paste0("[", wf_counts$GROUP, ": ", wf_counts$N, " wfs]"), collapse = ", ")
  rule_hot_str <- if (exists("GOOD_CHIP_RULE_HOT", inherits = TRUE) && is.function(GOOD_CHIP_RULE_HOT)) {
    paste(deparse(body(GOOD_CHIP_RULE_HOT)), collapse = " ")
  } else {
    "NULL"
  }
  rule_cold_str <- if (exists("GOOD_CHIP_RULE_COLD", inherits = TRUE) && is.function(GOOD_CHIP_RULE_COLD)) {
    paste(deparse(body(GOOD_CHIP_RULE_COLD)), collapse = " ")
  } else {
    "NULL"
  }
  legacy_hot_str <- if (exists("GOOD_CHIP_LIMIT_HOT", inherits = TRUE) && !is.null(GOOD_CHIP_LIMIT_HOT)) {
    as.character(GOOD_CHIP_LIMIT_HOT)
  } else {
    "NULL"
  }
  legacy_cold_str <- if (exists("GOOD_CHIP_LIMIT_COLD", inherits = TRUE) && !is.null(GOOD_CHIP_LIMIT_COLD)) {
    as.character(GOOD_CHIP_LIMIT_COLD)
  } else {
    "NULL"
  }

  metric_param_lines <- build_metric_param_log_lines(
    metric_param_summary = metric_param_summary,
    metric_params_file_info = metric_params_file_info,
    run_params = METRIC_PARAMS
  )

  # Save Parameters Log
  param_log_path <- file.path(archive_dir, paste0("parameters_", timestamp_str, ".txt"))
  runtime_lines <- "Metric Runtime Summary: (no metric runtime data)"
  if (!is.null(metric_runtime_summary) && nrow(metric_runtime_summary) > 0) {
    runtime_lines <- c(
      "Metric Runtime Summary:",
      vapply(seq_len(nrow(metric_runtime_summary)), function(i) {
        metric_name <- as.character(metric_runtime_summary$metric_name[i])
        elapsed_sec <- as.numeric(metric_runtime_summary$elapsed_sec[i])
        pair_count <- as.integer(metric_runtime_summary$pair_count[i])
        sprintf("  - %s: %.3f sec (pairs=%d)", metric_name, elapsed_sec, pair_count)
      }, character(1)),
      sprintf("Metric Runtime Total: %.3f sec", sum(metric_runtime_summary$elapsed_sec))
    )
  }

  param_content <- c(
    "=== Analysis Parameters ===",
    paste0("Date: ", timestamp_str),
    paste0("Raw File: ", RAW_FILENAME),
    paste0("Good Chip Rule (Hot): ", rule_hot_str),
    paste0("Good Chip Rule (Cold): ", rule_cold_str),
    paste0("Legacy Good Chip Limit (Hot): ", legacy_hot_str, " (used only when rule is NULL)"),
    paste0("Legacy Good Chip Limit (Cold): ", legacy_cold_str, " (used only when rule is NULL)"),
    paste0("Sigma Threshold: ", SIGMA_THRESHOLD),
    paste0("Ref Group: ", paste(final_ref, collapse = ", ")),
    paste0("Target Group: ", paste(final_tgt, collapse = ", ")),
    paste0("WF Counts: ", wf_str),
    metric_param_lines,
    runtime_lines,
    paste0("Execution Time: ", execution_time, " mins"),
    "==========================="
  )
  writeLines(param_content, param_log_path)

  # 6. Generate PPT
  log_msg("Initiating PPT Generator...")
  tryCatch({
    generate_sigma_ppt(dt, result_dt, archive_dir, timestamp_str)
  }, error = function(e_ppt) {
    log_msg(paste0("[Warning] PPT generation failed: ", e_ppt$message))
  })

  log_msg(green("Analysis Complete."))
  log_msg(paste0(" - Result (Latest):  ./output/results.csv"))
  log_msg(paste0(" - Result (History): ./output/", basename(archive_dir)))
}, error = function(e) {
  log_msg(blue(paste0("CRITICAL ERROR: ", e$message)))
}, finally = {
  # Cleanup

  end_time <- Sys.time()
  duration_sec <- as.numeric(difftime(end_time, start_time, units = "secs"))
  mins <- floor(duration_sec / 60)
  secs <- round(duration_sec %% 60, 0)
  log_msg(paste0("Total Execution Time: ", mins, " mins ", secs, " secs."))
  log_msg(bold("=== Analysis Ended ==="))
})
