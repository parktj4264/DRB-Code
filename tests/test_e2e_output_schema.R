# E2E test: run main pipeline and validate core metric columns in output schema
source("src/bootstrap/libs.R")

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
stopifnot(!("Glass_Flag" %in% names(result_dt)))

ppt_path <- here::here("output", "sigma_summary_latest.pptx")
stopifnot(file.exists(ppt_path))
ppt_text <- officer::pptx_summary(officer::read_pptx(ppt_path))
summary_text <- ppt_text[ppt_text$slide_id == 1, "text"]
stopifnot(!any(summary_text == "\u25A0 comment"))
stopifnot(any(grepl("TREND: plot \uC218\uB3D9 \uBD80\uCC29", summary_text, fixed = TRUE)))
expected_summary_headers <- c(
  "\uAD6C\uBD84",
  "\uC8FC\uC694 \uD56D\uBAA9",
  "\uC9C0\uC218\uC218\uC900",
  "Diff",
  "\uBCC0\uB3D9\uACB0\uACFC",
  "TREND",
  "\uBE44\uACE0"
)
stopifnot(all(vapply(
  expected_summary_headers,
  function(header) any(grepl(header, summary_text, fixed = TRUE)),
  logical(1)
)))

issues_latest_path <- here::here("output", "metric_issues_latest.csv")
stopifnot(file.exists(issues_latest_path))
issues_dt <- data.table::fread(issues_latest_path)
issue_cols <- c("metric_name", "issue_type", "pair_id", "message", "count")
stopifnot(all(issue_cols %in% names(issues_dt)))

cat("PASS: test_e2e_output_schema.R\n")

