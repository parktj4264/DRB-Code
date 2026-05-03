# Regression test: dual-mode metric API (legacy + raw_access) works together.
source("src/00_libs.R")
source(here::here("src", "00_utils.R"))
source(here::here("src", "02_calc_sigma.R"))

tmp_metric_dir <- file.path(tempdir(), paste0("metric_test_", as.integer(Sys.time())))
dir.create(tmp_metric_dir, recursive = TRUE, showWarnings = FALSE)

metric_file <- file.path(tmp_metric_dir, "metric_test_set.R")
writeLines(c(
  "metric_one_sigma <- function(pair_stats) {",
  "  score <- (as.numeric(pair_stats$mean_tgt) - as.numeric(pair_stats$mean_ref)) /",
  "    as.numeric(pair_stats$sd_ref)",
  "  score[!is.finite(score)] <- 0",
  "  as.numeric(score)",
  "}",
  "",
  "metric_legacy_gap <- function(pair_stats) {",
  "  out <- as.numeric(pair_stats$mean_tgt) - as.numeric(pair_stats$mean_ref)",
  "  out[!is.finite(out)] <- 0",
  "  as.numeric(out)",
  "}",
  "",
  "metric_raw_gap <- function(pair_stats, raw_access) {",
  "  out <- vapply(seq_len(nrow(pair_stats)), function(i) {",
  "    msr <- as.character(pair_stats$MSR[i])",
  "    ref_group <- as.character(pair_stats$ref_group[i])",
  "    tgt_group <- as.character(pair_stats$target_group[i])",
  "    if (!raw_access$has_pair(msr, ref_group, tgt_group)) {",
  "      return(0)",
  "    }",
  "    raw_pair <- raw_access$get_pair(msr, ref_group, tgt_group)",
  "    ref_values <- as.numeric(raw_pair$ref_values)",
  "    tgt_values <- as.numeric(raw_pair$tgt_values)",
  "    if (length(ref_values) == 0 || length(tgt_values) == 0) {",
  "      return(0)",
  "    }",
  "    out_i <- mean(tgt_values) - mean(ref_values)",
  "    if (!is.finite(out_i)) {",
  "      return(0)",
  "    }",
  "    as.numeric(out_i)",
  "  }, numeric(1))",
  "  out[!is.finite(out)] <- 0",
  "  as.numeric(out)",
  "}",
  "",
  "metric_raw_count_gap <- function(pair_stats, raw_access) {",
  "  out <- vapply(seq_len(nrow(pair_stats)), function(i) {",
  "    msr <- as.character(pair_stats$MSR[i])",
  "    ref_group <- as.character(pair_stats$ref_group[i])",
  "    tgt_group <- as.character(pair_stats$target_group[i])",
  "    raw_pair <- raw_access$get_pair(msr, ref_group, tgt_group)",
  "    as.numeric(length(raw_pair$tgt_values) - length(raw_pair$ref_values))",
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

res <- calculate_sigma(
  dt = dt,
  msr_cols = c("M1", "M2"),
  threshold = 1,
  ref_name = "REF",
  target_name = "TGT",
  metric_dir = tmp_metric_dir
)$res

required_cols <- c(
  "metric_one_sigma",
  "metric_legacy_gap",
  "metric_raw_gap",
  "metric_raw_count_gap",
  "Sigma_Score",
  "Abs_Sigma_Score",
  "Direction"
)
missing_cols <- setdiff(required_cols, names(res))
stopifnot(length(missing_cols) == 0)

# one_sigma backbone must stay identical to Sigma_Score.
stopifnot(all(abs(res$Sigma_Score - res$metric_one_sigma) < 1e-12))

# Legacy mode metric and raw-access metric should agree for mean difference.
stopifnot(all(abs(res$metric_legacy_gap - res$metric_raw_gap) < 1e-12))

# raw_access should expose per-group finite-value counts by MSR.
actual_count_gap <- setNames(res$metric_raw_count_gap, res$MSR)
expected_count_gap <- c(M1 = 1, M2 = -1)
stopifnot(all(actual_count_gap[names(expected_count_gap)] == expected_count_gap))

cat("PASS: test_metric_dual_mode_raw_access.R\n")
