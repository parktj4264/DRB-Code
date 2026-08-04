#' @title Main Orchestrator
#' @description Orchestrates the data loading, processing, and saving workflow.

# ==========================================================
# Execution Flow (High Level)
# 0) Resolve runtime config (run.R override > config file > defaults)
# 1) Load input data (raw load + good-chip filtering + group join)
# 2) Resolve metric params + calculate sigma
# 3) Save outputs/logs and optionally generate Spotfire/PPT artifacts
# ==========================================================

# ----------------------------------------------------------
# Source pipeline modules
# ----------------------------------------------------------
if (!isTRUE(get0(".DRB_LIBRARIES_LOADED", inherits = TRUE))) {
  source("src/bootstrap/libs.R", local = environment())
}
source(here::here("src", "bootstrap", "utils.R"), local = environment())
source(here::here("src", "bootstrap", "runtime_config.R"), local = environment())
source(here::here("src", "01_load_data.R"), local = environment())
source(here::here("src", "02_calc_stats.R"), local = environment())
source(here::here("src", "03_create_ppt.R"), local = environment())
source(here::here("src", "04_create_spotfire.R"), local = environment())

# Runtime bootstrap
start_time <- Sys.time()
initial_object_names <- initialize_runtime_context(environment())

# ----------------------------------------------------------
# Main execution block
# ----------------------------------------------------------
tryCatch({
  log_msg(bold("=== Analysis Started ==="))

  # ------------------------------
  # Step 0. Resolve runtime config
  # Source: src/bootstrap/runtime_config.R::run_stage_runtime_config
  # Role: apply precedence (run.R > config > default) and expose runtime knobs.
  # ------------------------------
  runtime_stage <- run_stage_runtime_config(initial_object_names)

  # -------------------------
  # Step 1. Load input data
  # Source: src/01_load_data.R::run_stage_load_data
  # Role: read raw/root files, apply good-chip filtering, and return analysis-ready table.
  # -------------------------
  load_stage <- run_stage_load_data(
    raw_filename = RAW_FILENAME,
    root_filename = ROOT_FILENAME,
    general_config = runtime_stage$general_config_resolved
  )

  # ----------------------------------------
  # Step 2. Resolve metric params + sigma
  # Source: src/02_calc_stats.R::run_stage_calculate_sigma
  # Role: resolve metric params, run metric engine, and merge optional msrinfo metadata.
  # ----------------------------------------
  calc_stage <- run_stage_calculate_sigma(
    load_stage = load_stage,
    sigma_threshold = SIGMA_THRESHOLD,
    group_ref_name = GROUP_REF_NAME,
    group_target_name = GROUP_TARGET_NAME,
    metric_params_file = METRIC_PARAMS_FILE,
    metric_params_run = METRIC_PARAMS,
    na_policy = runtime_stage$NA_POLICY
  )

  # ---------------------------------------------
  # Step 3. Save outputs/logs and optionally generate Spotfire/PPT artifacts
  # Source: src/03_create_ppt.R::finalize_outputs_and_generate_ppt
  # Role: write artifacts/logs and build enabled Spotfire/PPT outputs.
  # ---------------------------------------------
  output_summary <- finalize_outputs_and_generate_ppt(
    result_dt = calc_stage$result_dt,
    calc_res = calc_stage$calc_res,
    dt = load_stage$data,
    wf_counts = load_stage$wf_counts,
    raw_filename = RAW_FILENAME,
    root_filename = ROOT_FILENAME,
    start_time = start_time,
    sigma_threshold = SIGMA_THRESHOLD,
    na_policy = runtime_stage$NA_POLICY,
    final_ref = calc_stage$final_ref,
    final_tgt = calc_stage$final_tgt,
    general_config_file_info = runtime_stage$general_config_file_info,
    ppt_config_file_info = runtime_stage$ppt_config_file_info,
    metric_params_file_info = calc_stage$metric_params_file_info,
    metric_param_summary = calc_stage$metric_param_summary,
    metric_runtime_summary = calc_stage$metric_runtime_summary,
    metric_params_run = METRIC_PARAMS,
    good_chip_rule_hot = runtime_stage$GOOD_CHIP_RULE_HOT,
    good_chip_rule_cold = runtime_stage$GOOD_CHIP_RULE_COLD,
    good_chip_limit_hot = runtime_stage$GOOD_CHIP_LIMIT_HOT,
    good_chip_limit_cold = runtime_stage$GOOD_CHIP_LIMIT_COLD,
    ppt_config_resolved = runtime_stage$ppt_config_resolved,
    generate_ppt = GENERATE_PPT,
    generate_spotfire = GENERATE_SPOTFIRE
  )

  log_msg(green("Analysis Complete."))
  log_msg(paste0(" - Result (Latest):  ./output/results.csv"))
  if (isTRUE(output_summary$spotfire_generation_enabled)) {
    log_msg(paste0(" - Spotfire Data:    ./spotfire"))
  }
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
