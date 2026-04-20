#' @title User Interface (Run Script)
#' @description Single entrypoint for analysis and optional test execution.
rm(list = ls())
gc()

if (!requireNamespace("here", quietly = TRUE)) install.packages("here", type = "binary")
source("src/00_libs.R")

# -----------------------------------------------------------
# [User Guide]
# 1. Put input files in data/ (raw.csv, ROOTID.csv).
# 2. Edit parameters below.
# 3. Run this script only (Ctrl+A, Ctrl+Enter).
# -----------------------------------------------------------

# ==========================================
# User Parameters
# ==========================================

# Input filenames (in data/)
RAW_FILENAME      <- "raw.csv"
ROOT_FILENAME     <- "ROOTID.csv"

# Analysis settings
GOOD_CHIP_LIMIT   <- 130
SIGMA_THRESHOLD   <- 1.0  # Glass decision threshold for Up/Down

# Group settings
# If NULL or invalid, auto-detect (alphabetical: first=Ref, second=Tgt)
GROUP_REF_NAME    <- NULL # e.g., "Reference_A" or c("Ref_A", "Ref_B")
GROUP_TARGET_NAME <- NULL # e.g., "Muns_B" or c("Tgt_A", "Tgt_B")

# Run mode (single entrypoint behavior)
# - "analysis": run main pipeline only (default)
# - "tests": run tests only
# - "both": run analysis then tests
RUN_MODE <- "analysis"

# -----------------------------------------------------------
# Metric extension for collaborators
# -----------------------------------------------------------
# Add only function definitions in src/metrics/metric_custom.R.
# Contract:
# - function name: metric_<name>
# - input: pair_dt (MSR, mean_ref, mean_tgt, sd_ref, sd_tgt, n_ref, n_tgt)
# - output: numeric vector (length == nrow(pair_dt))

# ==========================================
# Execution
# ==========================================

valid_modes <- c("analysis", "tests", "both")
if (!RUN_MODE %in% valid_modes) {
  stop("RUN_MODE must be one of: ", paste(valid_modes, collapse = ", "))
}

if (RUN_MODE %in% c("analysis", "both")) {
  source(here::here("main.R"), local = environment())
}

if (RUN_MODE %in% c("tests", "both")) {
  tests_runner <- here::here("tests", "run_tests.R")
  if (!file.exists(tests_runner)) {
    stop("tests/run_tests.R not found. Cannot run tests mode.")
  }
  source(tests_runner, local = environment())
}
