# Core production metric (one_sigma).
# Formula:
#   one_sigma = (mean_tgt - mean_ref) / sd_ref
# Notes:
# - This metric is used as the primary Sigma_Score backbone.
# - Rows with invalid denominator or non-finite results are forced to 0.
metric_one_sigma <- function(pair_dt) {
  # Validate required columns first to fail fast with a clear message.
  required_cols <- c("mean_ref", "mean_tgt", "sd_ref")
  missing_cols <- setdiff(required_cols, names(pair_dt))
  if (length(missing_cols) > 0) {
    stop("metric_one_sigma: missing required columns: ", paste(missing_cols, collapse = ", "))
  }

  # Numeric cast protects against character/factor input coming from joins.
  mean_ref <- as.numeric(pair_dt$mean_ref)
  mean_tgt <- as.numeric(pair_dt$mean_tgt)
  sd_ref <- as.numeric(pair_dt$sd_ref)

  # Vectorized calculation for performance on wide MSR tables.
  score <- (mean_tgt - mean_ref) / sd_ref

  # Safety handling:
  # - non-finite result (Inf/-Inf/NaN)
  # - missing or zero/negative denominator
  # -> force score to 0 so downstream sorting and direction logic stay stable.
  invalid <- !is.finite(score) | is.na(sd_ref) | sd_ref <= 0
  score[invalid] <- 0

  # Always return strict numeric vector as metric engine contract requires.
  as.numeric(score)
}
