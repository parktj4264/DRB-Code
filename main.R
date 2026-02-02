#' @title Main Orchestrator
#' @description Orchestrates the data loading, processing, and saving workflow.

# Measure Total Execution Time
start_time <- Sys.time()

# 1. Source Helper & Core Functions
source("src/00_libs.R") # Ensures libraries are loaded even if main.R is run directly

source(here::here("src", "00_utils.R"))
source(here::here("src", "01_load_data.R"))
source(here::here("src", "02_calc_sigma.R"))

# Main Execution Block with Error Handling
tryCatch({
  log_msg(bold("=== Analysis Started ==="))

  # 2. Setup Resources
  # Construct Absolute Paths from User Parameters
  RAW_FILE  <- here::here("data", RAW_FILENAME)
  ROOT_FILE <- here::here("data", ROOT_FILENAME)

  # Load Data (now returns a list with dt and group info)
  load_res <- load_and_filter_data(RAW_FILE, ROOT_FILE, GOOD_CHIP_LIMIT)
  dt <- load_res$data
  msr_cols <- load_res$msr_cols
  wf_counts <- load_res$wf_counts # Get WF counts

  log_msg("Data Loaded Successfully.")
  gc()

  # 4. Calculate Sigma Score
  # result_dt is now a LIST
  calc_res <- calculate_sigma(dt, msr_cols,
    threshold   = SIGMA_THRESHOLD,
    ref_name    = GROUP_REF_NAME, 
    target_name = GROUP_TARGET_NAME
  )

  result_dt <- calc_res$res
  final_ref <- calc_res$ref
  final_tgt <- calc_res$tgt

  # 5. Save Results (Dual Output Strategy)

  # A. Overwrite fixed file (for Spotfire/Integration)
  output_path <- here::here("output", "results.csv")
  data.table::fwrite(result_dt, output_path)

  # B. Create Timestamped Archive
  timestamp_str <- format(Sys.time(), "%y%m%d_%H%M%S") # e.g., 260131_233045
  archive_dir <- here::here("output", paste0("results_", timestamp_str))

  if (!dir.exists(archive_dir)) dir.create(archive_dir, recursive = TRUE)

  # Save Timestamped CSV
  archive_csv_name <- paste0("results_", timestamp_str, ".csv")
  archive_csv_path <- file.path(archive_dir, archive_csv_name)
  data.table::fwrite(result_dt, archive_csv_path)

  end_time <- Sys.time()
  execution_time <- round(difftime(end_time, start_time, units = "mins"), 2)

  # Format WF Counts for Logging
  wf_str <- paste(paste0("[", wf_counts$GROUP, ": ", wf_counts$N, " wfs]"), collapse = ", ")

  # Save Parameters Log
  param_log_path <- file.path(archive_dir, "parameters.txt")
  param_content <- c(
    "=== Analysis Parameters ===",
    paste0("Date: ", timestamp_str),
    paste0("Raw File: ", RAW_FILENAME),
    paste0("Good Chip Limit: ", GOOD_CHIP_LIMIT, " (Optional)"),
    paste0("Sigma Threshold: ", SIGMA_THRESHOLD),
    paste0("Ref Group: ", final_ref),
    paste0("Target Group: ", final_tgt),
    paste0("WF Counts: ", wf_str),
    paste0("Execution Time: ", execution_time, " mins"),
    "==========================="
  )
  writeLines(param_content, param_log_path)

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
