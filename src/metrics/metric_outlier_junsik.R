# Percentile-distance outlier ratio metric (two-sided by default).
#
# For each side:
# 1) Build anchor percentiles (25/50/75) from one group.
# 2) Compute point-to-nearest-anchor distance for both groups.
# 3) Set outlier cutoff as 99th percentile of anchor group's distances.
# 4) Score = fraction of opposite-group points above that cutoff.
# Final score (two-sided) = (score_ref + score_tgt) / 2.
#
# TODO(EDGE meta):
# - raw_access$get_pair(...) already returns ref_meta / tgt_meta.
# - When EDGE is available in meta (E1/E2/E3/E4), we can:
#   1) compute this score per EDGE bucket, then
#   2) combine buckets with a weighted average (or max-risk rule).
# - Keep current global score as fallback when EDGE is missing.
metric_outlier_junsik <- function(pair_stats, raw_access) {
  two_side <- TRUE
  sample_percentile <- c(0.25, 0.5, 0.75)
  outlier_percentile <- 0.99
  score <- vapply(seq_len(nrow(pair_stats)), function(i) {
    msr <- as.character(pair_stats$MSR[i])
    ref_group <- as.character(pair_stats$ref_group[i])
    target_group <- as.character(pair_stats$target_group[i])

    raw_pair <- raw_access$get_pair(msr, ref_group, target_group)
    ref_values <- as.numeric(raw_pair$ref_values)
    tgt_values <- as.numeric(raw_pair$tgt_values)

    if (length(ref_values) == 0 || length(tgt_values) == 0) {
      return(NA_real_)
    }

    ref_percentile <- unique(as.numeric(stats::quantile(ref_values, sample_percentile, na.rm = TRUE)))
    if (length(ref_percentile) == 0) {
      return(NA_real_)
    }

    ref_dist1 <- do.call(pmin, lapply(ref_percentile, function(x) abs(ref_values - x)))
    tar_dist1 <- do.call(pmin, lapply(ref_percentile, function(x) abs(tgt_values - x)))
    ref_outlier <- as.numeric(stats::quantile(ref_dist1, outlier_percentile, na.rm = TRUE))
    score_tar <- sum(tar_dist1 > ref_outlier)

    if (isTRUE(two_side)) {
      tar_percentile <- unique(as.numeric(stats::quantile(tgt_values, sample_percentile, na.rm = TRUE)))
      if (length(tar_percentile) == 0) {
        return(NA_real_)
      }

      ref_dist2 <- do.call(pmin, lapply(tar_percentile, function(x) abs(ref_values - x)))
      tar_dist2 <- do.call(pmin, lapply(tar_percentile, function(x) abs(tgt_values - x)))
      tar_outlier <- as.numeric(stats::quantile(tar_dist2, outlier_percentile, na.rm = TRUE))
      score_ref <- sum(ref_dist2 > tar_outlier)

      as.numeric((score_ref / length(ref_values) + score_tar / length(tgt_values)) / 2)
    } else {
      as.numeric(score_tar / length(tgt_values))
    }
  }, numeric(1))

  as.numeric(score)
}
