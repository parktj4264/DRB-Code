#' @title Main Orchestrator
#' @description Orchestrates the data loading, processing, and saving workflow.

# ==========================================================
# Execution Flow (High Level)
# 1) Resolve runtime config (run.R override > config file > defaults)
# 2) Load and filter data
# 3) Resolve metric parameters
# 4) Calculate sigma and metric outputs
# 5) Save CSV and parameter/runtime logs
# 6) Generate PPT summary
# ==========================================================

# ----------------------------------------------------------
# Source pipeline modules
# ----------------------------------------------------------
source("src/bootstrap/libs.R", local = environment())
source(here::here("src", "bootstrap", "utils.R"), local = environment())
source(here::here("src", "bootstrap", "runtime_config.R"), local = environment())
source(here::here("src", "01_load_data.R"), local = environment())
source(here::here("src", "02_calc_stats.R"), local = environment())
source(here::here("src", "03_create_ppt.R"), local = environment())

# Runtime bootstrap
start_time <- Sys.time()
initial_object_names <- initialize_runtime_context(environment())

# ----------------------------------------------------------
# Main execution block
# ----------------------------------------------------------
tryCatch({
  log_msg(bold("=== Analysis Started ==="))

  # ------------------------------
  # Step 1. Resolve runtime config
  # ------------------------------
  runtime_cfg <- resolve_runtime_config(initial_object_names)

  general_config_file_info <- runtime_cfg$general_config_file_info
  ppt_config_file_info <- runtime_cfg$ppt_config_file_info
  general_config_resolved <- runtime_cfg$general_config_resolved
  ppt_config_resolved <- runtime_cfg$ppt_config_resolved

  NA_POLICY <- general_config_resolved$NA_POLICY
  GOOD_CHIP_LIMIT_HOT <- general_config_resolved$GOOD_CHIP_LIMIT_HOT
  GOOD_CHIP_LIMIT_COLD <- general_config_resolved$GOOD_CHIP_LIMIT_COLD
  GOOD_CHIP_RULE_HOT <- general_config_resolved$GOOD_CHIP_RULE_HOT
  GOOD_CHIP_RULE_COLD <- general_config_resolved$GOOD_CHIP_RULE_COLD

  if (isTRUE(general_config_file_info$loaded)) {
    log_msg(paste0("Loaded general config: ", general_config_file_info$path))
  }
  if (isTRUE(ppt_config_file_info$loaded)) {
    log_msg(paste0("Loaded PPT config: ", ppt_config_file_info$path))
  }

  # -------------------------
  # Step 2. Setup resources
  # -------------------------
  RAW_FILE  <- here::here("data", RAW_FILENAME)
  ROOT_FILE <- here::here("data", ROOT_FILENAME)

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
  wf_counts <- load_res$wf_counts
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

  # -----------------------------------
  # Step 3. Resolve metric parameters
  # -----------------------------------
  metric_params_file_info <- load_metric_params_file(METRIC_PARAMS_FILE)
  metric_params_resolved <- merge_metric_params(
    file_params = metric_params_file_info$params,
    run_params = METRIC_PARAMS
  )
  if (isTRUE(metric_params_file_info$loaded)) {
    log_msg(paste0("Loaded metric parameter file: ", metric_params_file_info$path))
  }

  # ----------------------------------------
  # Step 4. Calculate sigma / metric output
  # ----------------------------------------
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

  msrinfo_path <- here::here("data", "msrinfo.csv")
  if (file.exists(msrinfo_path)) {
    msr_info <- data.table::fread(msrinfo_path)
    result_dt <- merge(result_dt, msr_info, by.x = "MSR", by.y = "FIELD", all.x = TRUE)
    log_msg("Merged MSR Information successfully.")
  } else {
    log_msg("[Warning] msrinfo.csv not found in data/. PPT generation might be un-categorized.")
  }

  # ---------------------------------------------
  # Step 5-6. Save outputs/logs and generate PPT
  # ---------------------------------------------
  output_summary <- finalize_outputs_and_generate_ppt(
    result_dt = result_dt,
    calc_res = calc_res,
    dt = dt,
    wf_counts = wf_counts,
    raw_filename = RAW_FILENAME,
    start_time = start_time,
    sigma_threshold = SIGMA_THRESHOLD,
    na_policy = NA_POLICY,
    final_ref = final_ref,
    final_tgt = final_tgt,
    general_config_file_info = general_config_file_info,
    ppt_config_file_info = ppt_config_file_info,
    metric_params_file_info = metric_params_file_info,
    metric_param_summary = metric_param_summary,
    metric_runtime_summary = metric_runtime_summary,
    metric_params_run = METRIC_PARAMS,
    good_chip_rule_hot = GOOD_CHIP_RULE_HOT,
    good_chip_rule_cold = GOOD_CHIP_RULE_COLD,
    good_chip_limit_hot = GOOD_CHIP_LIMIT_HOT,
    good_chip_limit_cold = GOOD_CHIP_LIMIT_COLD,
    ppt_config_resolved = ppt_config_resolved
  )

  log_msg(green("Analysis Complete."))
  log_msg(paste0(" - Result (Latest):  ./output/results.csv"))
  log_msg(paste0(" - Result (History): ./output/", basename(output_summary$archive_dir)))
}, error = function(e) {
  log_msg(blue(paste0("CRITICAL ERROR: ", e$message)))
}, finally = {
  end_time <- Sys.time()
  duration_sec <- as.numeric(difftime(end_time, start_time, units = "secs"))
  mins <- floor(duration_sec / 60)
  secs <- round(duration_sec %% 60, 0)
  log_msg(paste0("Total Execution Time: ", mins, " mins ", secs, " secs."))
  log_msg(bold("=== Analysis Ended ==="))
})
