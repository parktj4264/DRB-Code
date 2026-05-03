# Smoke test: sd_ref-normalized median-shift metric should be created and finite.
source("src/00_libs.R")
source(here::here("src", "00_utils.R"))
source(here::here("src", "02_calc_stats.R"))

dt <- data.table::data.table(
  ROOTID = paste0("W", 1:10),
  GROUP = c(rep("REF", 5), rep("TGT", 5)),
  M1 = c(1, 2, 2, 3, 4, 6, 7, 7, 8, 9),
  M2 = c(10, 11, 12, 13, 14, 10, 11, 12, 13, 14)
)

res <- calculate_sigma(
  dt = dt,
  msr_cols = c("M1", "M2"),
  threshold = 1,
  ref_name = "REF",
  target_name = "TGT"
)$res

required_cols <- c("metric_median_shift", "abs_metric_median_shift")
missing_cols <- setdiff(required_cols, names(res))
stopifnot(length(missing_cols) == 0)

stopifnot(all(is.finite(res$metric_median_shift)))
stopifnot(all(is.finite(res$abs_metric_median_shift)))
stopifnot(all(res$abs_metric_median_shift >= 0))

# Check formula behavior on M1:
# median_shift = median(c(6,7,7,8,9)) - median(c(1,2,2,3,4)) = 5
# score = median_shift / sd_ref.
expected_m1 <- {
  ref_values <- c(1, 2, 2, 3, 4)
  tgt_values <- c(6, 7, 7, 8, 9)
  sd_ref <- stats::sd(ref_values)
  (stats::median(tgt_values) - stats::median(ref_values)) / sd_ref
}

actual_by_msr <- setNames(res$metric_median_shift, res$MSR)
stopifnot(abs(actual_by_msr[["M1"]] - expected_m1) < 1e-10)
stopifnot(abs(actual_by_msr[["M2"]]) < 1e-12)

cat("PASS: test_metric_median_shift_smoke.R\n")
