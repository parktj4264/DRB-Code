# Regression test: metric issue collection and CSV reporting
source("src/00_libs.R")
source(here::here("src", "00_utils.R"))
source(here::here("src", "02_calc_stats.R"))

tmp_metric_dir <- file.path(tempdir(), paste0("metric_issue_report_", as.integer(Sys.time())))
dir.create(tmp_metric_dir, recursive = TRUE, showWarnings = FALSE)

metric_file <- file.path(tmp_metric_dir, "metric_test_set.R")
writeLines(c(
  "metric_one_sigma <- function(pair_stats) {",
  "  (as.numeric(pair_stats$mean_tgt) - as.numeric(pair_stats$mean_ref)) / as.numeric(pair_stats$sd_ref)",
  "}",
  "",
  "metric_bad_type <- function(pair_stats) {",
  "  c('x', 'y')",
  "}",
  "",
  "metric_bad_length <- function(pair_stats) {",
  "  c(1)",
  "}",
  "",
  "metric_boom <- function(pair_stats) {",
  "  stop('boom')",
  "}"
), con = metric_file)

dt <- data.table::data.table(
  ROOTID = paste0("W", 1:6),
  GROUP = c("REF", "REF", "REF", "TGT", "TGT", "TGT"),
  M1 = c(1, 2, 3, 4, 5, 6),
  M2 = c(2, 3, 4, 5, 6, 7)
)

calc_res <- calculate_sigma(
  dt = dt,
  msr_cols = c("M1", "M2"),
  threshold = 1,
  ref_name = "REF",
  target_name = "TGT",
  metric_dir = tmp_metric_dir,
  na_policy = "na"
)

issues <- calc_res$metric_issues
required_cols <- c("metric_name", "issue_type", "pair_id", "message", "count")
stopifnot(all(required_cols %in% names(issues)))

issue_key <- paste(issues$metric_name, issues$issue_type, sep = "::")
expected_key <- c(
  "metric_bad_length::length_mismatch",
  "metric_bad_type::type_mismatch",
  "metric_boom::error"
)
stopifnot(setequal(issue_key, expected_key))
stopifnot(all(issues$count == 1L))

archive_dir <- file.path(tempdir(), paste0("metric_issue_archive_", as.integer(Sys.time())))
dir.create(archive_dir, recursive = TRUE, showWarnings = FALSE)
latest_path <- file.path(tempdir(), paste0("metric_issues_latest_", as.integer(Sys.time()), ".csv"))
timestamp_str <- format(Sys.time(), "%y%m%d_%H%M%S")

report <- write_metric_issue_reports(issues, archive_dir, timestamp_str, latest_path = latest_path)
stopifnot(file.exists(report$archive_path))
stopifnot(file.exists(report$latest_path))

archive_dt <- data.table::fread(report$archive_path)
latest_dt <- data.table::fread(report$latest_path)
stopifnot(all(required_cols %in% names(archive_dt)))
stopifnot(all(required_cols %in% names(latest_dt)))
stopifnot(nrow(archive_dt) == nrow(issues))
stopifnot(nrow(latest_dt) == nrow(issues))

empty_latest_path <- file.path(tempdir(), paste0("metric_issues_latest_empty_", as.integer(Sys.time()), ".csv"))
empty_report <- write_metric_issue_reports(
  empty_metric_issue_table(),
  archive_dir = archive_dir,
  timestamp_str = paste0(timestamp_str, "_empty"),
  latest_path = empty_latest_path
)
empty_dt <- data.table::fread(empty_report$archive_path)
stopifnot(all(required_cols %in% names(empty_dt)))
stopifnot(nrow(empty_dt) == 0)

cat("PASS: test_metric_issue_report.R\n")
