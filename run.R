#' @title User Interface (Run Script)
#' @description Define parameters and run analysis.
rm(list = ls())
gc()

if (!requireNamespace("here", quietly = TRUE)) install.packages("here", type = "binary")
source("src/bootstrap/libs.R")

# -----------------------------------------------------------
# [User Guide]
# 1. Put input files in data/ (raw.csv, ROOTID.csv).
# 2. Edit minimal parameters below.
# 3. Run this script only (Ctrl+A, Ctrl+Enter).
# -----------------------------------------------------------

# ==========================================
# User Parameters
# ==========================================

# Input filenames (in data/)
RAW_FILENAME      <- "raw.csv"
ROOT_FILENAME     <- "ROOTID.csv"

# one_sigma threshold for Up/Down direction
SIGMA_THRESHOLD   <- 0.5

# Group settings
# If NULL or invalid, auto-detect (alphabetical: first=Ref, second=Tgt)
GROUP_REF_NAME    <- NULL # e.g., "Reference_A" or c("Ref_A", "Ref_B")
GROUP_TARGET_NAME <- NULL # e.g., "Muns_B" or c("Tgt_A", "Tgt_B")

# PPT layout mode: "dev" keeps the current development overlay coordinates;
# "template" writes into the attached PPT template's placeholders first.
PPT_LAYOUT_MODE <- "dev"
PPT_SLIDE_TITLE <- "[DM] Data Review Board Auto Report"

PPT_CONFIG <- list(
  ppt_layout_mode = PPT_LAYOUT_MODE,
  slide_title = PPT_SLIDE_TITLE,
  detail_group_by = "Category2",
  detail_msr_selection_mode = "both",
  summary_msr_selection_mode = "both",
  summary_category_columns = c("Category1", "Category2", "Category3")
)

# Other settings are managed in config files:
# - config/general_config.R
# - config/metric_config.R
# - config/ppt_config.R

# ==========================================
# Execution (analysis only)
# ==========================================
source(here::here("main.R"), local = environment())

