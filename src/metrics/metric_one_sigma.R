metric_one_sigma <- function(pair_dt) {
  required_cols <- c("mean_ref", "mean_tgt", "sd_ref")
  missing_cols <- setdiff(required_cols, names(pair_dt))
  if (length(missing_cols) > 0) {
    stop("metric_one_sigma: missing required columns: ", paste(missing_cols, collapse = ", "))
  }

  mean_ref <- as.numeric(pair_dt$mean_ref)
  mean_tgt <- as.numeric(pair_dt$mean_tgt)
  sd_ref <- as.numeric(pair_dt$sd_ref)

  score <- (mean_tgt - mean_ref) / sd_ref
  invalid <- !is.finite(score) | is.na(sd_ref) | sd_ref <= 0
  score[invalid] <- 0

  as.numeric(score)
}
