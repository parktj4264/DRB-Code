#' @title User Interface (Run Script)
#' @description Define parameters and execute validity check.
rm(list = ls())
gc()

# File Paths (Use absolute paths or relative to project root)
source("src/00_libs.R")

# ==========================================
# User Parameters
# ==========================================

# Input Filenames (Located in 'data/' folder)
RAW_FILENAME      <- "raw.csv"
ROOT_FILENAME     <- "ROOTID.csv"

# Analysis Settings
GOOD_CHIP_LIMIT   <- 130  # Filter cutoff
SIGMA_THRESHOLD   <- 0.5  # Threshold for Up/Down direction
N_CORES           <- 2    # Set to Integer (e.g., 2) to force specific. NULL = Auto
CHUNK_SIZE        <- 100  # Number of columns per chunk for parallel processing

# Group Settings (Optional)
# Specify exact group names found in ROOTID.csv under 'GROUP' column.
# If NULL or invalid, the script will auto-detect (Alphabetical: 1st=Ref, 2nd=Tgt)
GROUP_REF_NAME    <- NULL # e.g., "Reference_A"
GROUP_TARGET_NAME <- NULL # e.g., "Muns_B"

# ==========================================
# Execution (Do Not Modify Below)
# ==========================================
source(here::here("main.R"))