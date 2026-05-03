#' @title User Interface (Run Script)
#' @description Define parameters and run analysis.
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
SIGMA_THRESHOLD   <- 1.0  # one_sigma threshold for Up/Down
# Non-finite metric handling:
# - "zero": NA/NaN/Inf -> 0 (legacy default)
# - "na" or "blank": NA/NaN/Inf -> NA (written as blank in CSV)
NA_POLICY         <- "zero"

# Group settings
# If NULL or invalid, auto-detect (alphabetical: first=Ref, second=Tgt)
GROUP_REF_NAME    <- NULL # e.g., "Reference_A" or c("Ref_A", "Ref_B")
GROUP_TARGET_NAME <- NULL # e.g., "Muns_B" or c("Tgt_A", "Tgt_B")

# -----------------------------------------------------------
# Metric extension for collaborators
# -----------------------------------------------------------
# Add only function definitions in src/metrics/metric_custom.R.
# Standard:
# - function name: metric_<name>
# - supported input signatures:
#   1) metric_x(pair_stats)
#   2) metric_x(pair_stats, raw_access)
# - pair_stats columns:
#   MSR, ref_group, target_group, mean_ref, mean_tgt, sd_ref, sd_tgt, n_ref, n_tgt
# - raw_access helpers:
#   has_pair(msr, ref_group, target_group), get_pair(msr, ref_group, target_group)
# - output: numeric vector (length == nrow(pair_stats))

# ==========================================
# Execution (analysis only)
# ==========================================
source(here::here("main.R"), local = environment())
