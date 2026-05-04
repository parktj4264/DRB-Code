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

# Good chip filter rules (user-editable):
# - Edit each rule directly. You can use OR (|) conditions freely.
# - Return TRUE for good chips, FALSE otherwise.
# - Priority: Cold rule -> Hot fallback when Cold is NA -> if both are NA, treat as good.
# - `!is.na(...)` means "evaluate only when that bin value exists".
#   Final behavior is still: if both Cold and Hot are NA on a row, that row is treated as good.
GOOD_CHIP_RULE_HOT <- function(lds_hot_bin) {
  !is.na(lds_hot_bin) & (lds_hot_bin < 130)
}

GOOD_CHIP_RULE_COLD <- function(lds_cold_bin) {
  !is.na(lds_cold_bin) & ((lds_cold_bin < 130) | (lds_cold_bin >= 790 & lds_cold_bin < 800))
}

# one_sigma threshold for Up/Down
SIGMA_THRESHOLD   <- 1.0

# Group settings
# If NULL or invalid, auto-detect (alphabetical: first=Ref, second=Tgt)
GROUP_REF_NAME    <- NULL # e.g., "Reference_A" or c("Ref_A", "Ref_B")
GROUP_TARGET_NAME <- NULL # e.g., "Muns_B" or c("Tgt_A", "Tgt_B")

# ==========================================
# Execution (analysis only)
# ==========================================
source(here::here("main.R"), local = environment())
