metric_pooled_sd_delta <- function(pair_dt) {
  required_cols <- c("mean_ref", "mean_tgt", "sd_ref", "sd_tgt", "n_ref", "n_tgt")
  missing_cols <- setdiff(required_cols, names(pair_dt))
  if (length(missing_cols) > 0) {
    stop("metric_pooled_sd_delta: missing required columns: ", paste(missing_cols, collapse = ", "))
  }

  mean_ref <- as.numeric(pair_dt$mean_ref)
  mean_tgt <- as.numeric(pair_dt$mean_tgt)
  sd_ref <- as.numeric(pair_dt$sd_ref)
  sd_tgt <- as.numeric(pair_dt$sd_tgt)
  n_ref <- as.numeric(pair_dt$n_ref)
  n_tgt <- as.numeric(pair_dt$n_tgt)

  pooled_df <- n_ref + n_tgt - 2
  pooled_var <- ((n_ref - 1) * (sd_ref ^ 2) + (n_tgt - 1) * (sd_tgt ^ 2)) / pooled_df
  pooled_sd <- sqrt(pooled_var)

  score <- (mean_tgt - mean_ref) / pooled_sd

  invalid <- !is.finite(score) |
    !is.finite(pooled_sd) |
    pooled_sd <= 0 |
    !is.finite(pooled_df) |
    pooled_df <= 0 |
    sd_ref <= 0 |
    sd_tgt <= 0 |
    n_ref <= 1 |
    n_tgt <= 1 |
    is.na(sd_ref) |
    is.na(sd_tgt) |
    is.na(n_ref) |
    is.na(n_tgt)

  score[invalid] <- 0

  as.numeric(score)
}
