#' @title User Interface (Run Script)
#' @description Define parameters and execute validity check.
rm(list = ls())
gc()

# File Paths (Use absolute paths or relative to project root)
if (!requireNamespace("here", quietly = TRUE)) install.packages("here", type = "binary")
source("src/00_libs.R")

# -----------------------------------------------------------
# [User Guide]
# 1. Ensure files are placed according to the folder structure below.
#    DRB-Code/
#    ├── data/          <-- Input files (raw.csv, ROOTID.csv) go here. Required!
#    ├── output/        <-- Results will be saved here.
#    └── src/           <-- Source code. Do not modify.
#
# 2. Check and modify 'User Parameters' below.
# 3. Select all code (Ctrl+A) and run (Ctrl+Enter).
# -----------------------------------------------------------

# ==========================================
# User Parameters 
# ==========================================

# Input Filenames (Located in 'data/' folder)
RAW_FILENAME      <- "raw.csv"
ROOT_FILENAME     <- "ROOTID.csv"

# Analysis Settings
GOOD_CHIP_LIMIT   <- 130  # Filter cutoff
SIGMA_THRESHOLD   <- 0.5  # Threshold for Up/Down direction


# Group Settings (Optional)
# Specify exact group names found in ROOTID.csv under 'GROUP' column.
# If NULL or invalid, the script will auto-detect (Alphabetical: 1st=Ref, 2nd=Tgt)
GROUP_REF_NAME    <- NULL # e.g., "Reference_A"
GROUP_TARGET_NAME <- NULL # e.g., "Muns_B"

# ==========================================
# Execution (Do Not Modify Below)
# ==========================================
source(here::here("main.R"))