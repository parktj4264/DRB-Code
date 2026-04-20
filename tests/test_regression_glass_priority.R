# Regression test: Sigma/Direction remain one_sigma-based in core metric framework
source("src/00_libs.R")
source(here::here("src", "00_utils.R"))
source(here::here("src", "02_calc_sigma.R"))

dt <- data.table::data.table(
  ROOTID = paste0("W", 1:8),
  GROUP = c("REF", "REF", "REF", "REF", "TGT", "TGT", "TGT", "TGT"),
  M1 = c(10, 11, 12, 13, 14, 15, 16, 17),
  M2 = c(5, 5, 6, 6, 8, 9, 9, 10)
)

res <- calculate_sigma(
  dt = dt,
  msr_cols = c("M1", "M2"),
  threshold = 1,
  ref_name = "REF",
  target_name = "TGT"
)$res

required_cols <- c(
  "Sigma_Score", "Abs_Sigma_Score", "Direction",
  "metric_one_sigma", "abs_metric_one_sigma"
)
missing_cols <- setdiff(required_cols, names(res))
stopifnot(length(missing_cols) == 0)

# Sigma columns must remain Glass metric columns.
stopifnot(all(abs(res$Sigma_Score - res$metric_one_sigma) < 1e-12))
stopifnot(all(abs(res$Abs_Sigma_Score - res$abs_metric_one_sigma) < 1e-12))

# Direction must still be tied to Glass/Sigma score.
expected_direction <- ifelse(
  res$Sigma_Score > 1,
  "Up",
  ifelse(res$Sigma_Score < -1, "Down", "Stable")
)
stopifnot(all(res$Direction == expected_direction))

cat("PASS: test_regression_glass_priority.R\n")
