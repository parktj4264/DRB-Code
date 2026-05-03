# E2E test: run main pipeline and validate core metric columns in output schema
source("src/00_libs.R")

RAW_FILENAME <- "raw.csv"
ROOT_FILENAME <- "ROOTID.csv"
GOOD_CHIP_LIMIT <- 130
SIGMA_THRESHOLD <- 1
GROUP_REF_NAME <- NULL
GROUP_TARGET_NAME <- NULL

source(here::here("main.R"), local = environment())

output_path <- here::here("output", "results.csv")
stopifnot(file.exists(output_path))

result_dt <- data.table::fread(output_path)
required_cols <- c(
  "Sigma_Score", "Abs_Sigma_Score", "Direction",
  "metric_one_sigma", "abs_metric_one_sigma"
)

missing_cols <- setdiff(required_cols, names(result_dt))
stopifnot(length(missing_cols) == 0)
stopifnot(nrow(result_dt) > 0)

ppt_path <- here::here("output", "Sigma_Summary_Latest.pptx")
stopifnot(file.exists(ppt_path))

cat("PASS: test_e2e_output_schema.R\n")
