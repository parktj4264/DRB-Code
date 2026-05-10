# Regression test: metric parameter overrides are injected and logged.
source("src/00_libs.R")
source(here::here("src", "00_utils.R"))
source(here::here("src", "02_calc_stats.R"))

tmp_metric_dir <- file.path(tempdir(), paste0("metric_param_test_", as.integer(Sys.time())))
dir.create(tmp_metric_dir, recursive = TRUE, showWarnings = FALSE)

metric_file <- file.path(tmp_metric_dir, "metric_test_params.R")
writeLines(c(
  "metric_one_sigma <- function(pair_stats) {",
  "  score <- (as.numeric(pair_stats$mean_tgt) - as.numeric(pair_stats$mean_ref)) /",
  "    as.numeric(pair_stats$sd_ref)",
  "  score[!is.finite(score)] <- 0",
  "  as.numeric(score)",
  "}",
  "",
  "metric_scaled_gap <- function(pair_stats, scale = 1) {",
  "  out <- (as.numeric(pair_stats$mean_tgt) - as.numeric(pair_stats$mean_ref)) * as.numeric(scale)",
  "  out[!is.finite(out)] <- 0",
  "  as.numeric(out)",
  "}",
  "",
  "metric_raw_shift <- function(pair_stats, raw_access, offset = 0) {",
  "  out <- vapply(seq_len(nrow(pair_stats)), function(i) {",
  "    msr <- as.character(pair_stats$MSR[i])",
  "    ref_group <- as.character(pair_stats$ref_group[i])",
  "    tgt_group <- as.character(pair_stats$target_group[i])",
  "    pair_raw <- raw_access$get_pair(msr, ref_group, tgt_group)",
  "    ref_values <- as.numeric(pair_raw$ref_values)",
  "    tgt_values <- as.numeric(pair_raw$tgt_values)",
  "    if (length(ref_values) == 0 || length(tgt_values) == 0) {",
  "      return(NA_real_)",
  "    }",
  "    as.numeric(stats::median(tgt_values) - stats::median(ref_values) + as.numeric(offset))",
  "  }, numeric(1))",
  "  out[!is.finite(out)] <- 0",
  "  as.numeric(out)",
  "}"
), con = metric_file)

dt <- data.table::data.table(
  ROOTID = paste0("W", 1:8),
  GROUP = c("REF", "REF", "REF", "REF", "TGT", "TGT", "TGT", "TGT"),
  M1 = c(10, 11, NA, 13, 14, 15, 16, 17),
  M2 = c(5, 6, 7, 8, 8, NA, 9, 10)
)

calc_res <- calculate_sigma(
  dt = dt,
  msr_cols = c("M1", "M2"),
  threshold = 1,
  ref_name = "REF",
  target_name = "TGT",
  metric_dir = tmp_metric_dir,
  metric_params = list(
    metric_scaled_gap = list(scale = 2),
    metric_raw_shift = list(offset = 3),
    metric_missing = list(alpha = 0.1),
    metric_one_sigma = list(dummy = TRUE)
  )
)

res <- calc_res$res
metric_issues <- calc_res$metric_issues
metric_param_summary <- calc_res$metric_param_summary

expected_scaled <- c(M1 = 8.33333333333333, M2 = 5)
actual_scaled <- setNames(as.numeric(res$metric_scaled_gap), as.character(res$MSR))
stopifnot(all(abs(actual_scaled[names(expected_scaled)] - expected_scaled) < 1e-12))

expected_raw_shift <- c(M1 = 7.5, M2 = 5.5)
actual_raw_shift <- setNames(as.numeric(res$metric_raw_shift), as.character(res$MSR))
stopifnot(all(abs(actual_raw_shift[names(expected_raw_shift)] - expected_raw_shift) < 1e-12))

stopifnot(any(metric_issues$issue_type == "metric_not_loaded"))
stopifnot(any(metric_issues$issue_type == "parameter_unknown"))

scaled_param <- metric_param_summary[
  metric_name == "metric_scaled_gap" & param_name == "scale"
]
stopifnot(nrow(scaled_param) == 1)
stopifnot(as.character(scaled_param$source[1]) == "override")

raw_param <- metric_param_summary[
  metric_name == "metric_raw_shift" & param_name == "offset"
]
stopifnot(nrow(raw_param) == 1)
stopifnot(as.character(raw_param$source[1]) == "override")

cat("PASS: test_metric_params_override.R\n")
