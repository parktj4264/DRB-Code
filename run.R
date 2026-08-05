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

# ------------------------------------------
# 1. DRB Analysis
# ------------------------------------------
RAW_FILENAME        <- "raw.csv"
ROOT_FILENAME       <- "ROOTID.csv"
GROUP_REF_NAME      <- NULL # e.g., "Reference_A" or c("Ref_A", "Ref_B")
GROUP_TARGET_NAME   <- NULL # e.g., "Muns_B" or c("Tgt_A", "Tgt_B")
SIGMA_THRESHOLD     <- 0.5  # one_sigma threshold for Up/Down direction

# Good-chip filter priority: Cold -> Hot fallback
GOOD_CHIP_RULE_HOT  <- function(x) !is.na(x) & x < 130
GOOD_CHIP_RULE_COLD <- function(x) !is.na(x) & (x < 130 | (x >= 790 & x < 800))

# ------------------------------------------
# 2. Output Controls
# ------------------------------------------
GENERATE_SPOTFIRE <- TRUE
OPEN_SPOTFIRE     <- TRUE
GENERATE_PPT      <- TRUE

# ------------------------------------------
# 3. PPT Presentation
# ------------------------------------------
PPT_SLIDE_TITLE         <- "[DM] Data Review Board Auto Report"
PPT_AFFILIATION         <- "Flash PE / 홍길동"
PPT_SCATTER_TRIM_IQR    <- 6 # FALSE: off
PPT_SCATTER_SHOW_MEAN   <- TRUE
PPT_CATEGORY_SCOPE      <- NULL # NULL: all
PPT_CATEGORY_ORDER_FILE <- "cateinfo.csv" # missing/NULL: auto
PPT_DETAIL_GROUP_BY     <- "Category2"
PPT_SUMMARY_GROUP_BY    <- c("Category1", "Category2", "Category3")

# ==========================================
# Execution
# ==========================================
source(here::here("main.R"), local = environment())

