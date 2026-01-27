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
  log_msg("=== Analysis Started ===")
  
  # 2. Setup Resources
  # Construct Absolute Paths from User Parameters
  RAW_FILE    <- here::here("data", RAW_FILENAME)
  ROOT_FILE   <- here::here("data", ROOT_FILENAME)

  if (is.null(N_CORES)) {
    N_CORES <- get_safe_cores(RAW_FILE)
  } else {
    log_msg(paste0("User forced core count: ", N_CORES))
  }
  
  # 3. Load & Filter Data
  load_res <- load_and_filter_data(RAW_FILE, ROOT_FILE, HOT_BIN_LIMIT)
  dt <- load_res$data
  msr_cols <- load_res$msr_cols
  
  rm(load_res) # Free list memory
  gc()
  
  # 4. Calculate Sigma Score
  result_dt <- calculate_sigma_parallel(dt, msr_cols, n_cores = N_CORES, chunk_size = CHUNK_SIZE, 
                                        threshold = SIGMA_THRESHOLD,
                                        ref_name = GROUP_REF_NAME, target_name = GROUP_TARGET_NAME)
  
  # 5. Post-process & Save
  # Sort by abs(sigma_score) descending
  data.table::setorder(result_dt, -abs(Sigma_Score), na.last = TRUE)
  
  output_path <- here::here("output", OUTPUT_FILENAME)
  data.table::fwrite(result_dt, output_path)
  
  log_msg(paste0("Analysis Complete. Results saved to: ", output_path))
  
}, error = function(e) {
  log_msg(paste0("CRITICAL ERROR: ", e$message))
}, finally = {
  # Cleanup parallel plan if needed, though 'future' handles it mostly.
  end_time <- Sys.time()
  duration <- round(difftime(end_time, start_time, units = "mins"), 2)
  log_msg(paste0("Total Execution Time: ", duration, " mins."))
})
