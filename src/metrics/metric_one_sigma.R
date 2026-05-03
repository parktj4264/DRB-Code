# Core decision metric (one_sigma).
# Formula: (mean_tgt - mean_ref) / sd_ref
# Note: invalid/non-finite values are handled by engine `na_policy`.
metric_one_sigma <- function(pair_stats) {
  mean_ref <- as.numeric(pair_stats$mean_ref)
  mean_tgt <- as.numeric(pair_stats$mean_tgt)
  sd_ref <- as.numeric(pair_stats$sd_ref)
  as.numeric((mean_tgt - mean_ref) / sd_ref)
}
