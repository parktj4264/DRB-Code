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

# Generate the PPT after CSV/Spotfire outputs.
# FALSE skips PPT generation and leaves any existing latest PPT unchanged.
GENERATE_PPT <- TRUE

# PPT layout mode: "template" uses data/template_16_9.pptx;
# "dev" keeps the development overlay coordinates as a fallback.
PPT_LAYOUT_MODE <- "template"
PPT_SLIDE_TITLE <- "[DM] Data Review Board Auto Report"
PPT_AFFILIATION <- "Flash PE / 홍길동"
PPT_SCATTER_TRIM_IQR <- 6 # FALSE or positive number; larger trims less
PPT_SCATTER_SHOW_MEAN <- TRUE

PPT_CONFIG <- list(
  ppt_layout_mode = PPT_LAYOUT_MODE,
  slide_title = PPT_SLIDE_TITLE,
  slide_affiliation = PPT_AFFILIATION,
  radius_scatter_trim_iqr = PPT_SCATTER_TRIM_IQR,
  radius_scatter_show_mean = PPT_SCATTER_SHOW_MEAN,
  detail_group_by = "Category2",
  # Detail mode options: "required_only", "flagged_only", or "both".
  # Summary keeps summary_msr_selection_mode for compatibility, but now selects
  # one representative MSR per summary category group with SUMMARY_REQUIRED_YN priority.
  detail_msr_selection_mode = "both",
  summary_msr_selection_mode = "required_only",
  summary_category_columns = c("Category1", "Category2", "Category3")
)

# Other settings are managed in config files:
# - config/general_config.R
# - config/metric_config.R
# - config/ppt_config.R

# ==========================================
# Execution
# ==========================================
source(here::here("main.R"), local = environment())

