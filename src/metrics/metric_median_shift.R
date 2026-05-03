# Fast raw-access metric for collaboration smoke testing.
#
# metric_median_shift:
# - Computes median(target_raw) - median(ref_raw) for each MSR row.
# - Uses raw_access to prove raw-vector based metric flow.
# - Fast and robust for location-shift checking on raw vectors.
metric_median_shift <- function(pair_stats, raw_access) {
  score <- vapply(seq_len(nrow(pair_stats)), function(i) {
    msr <- as.character(pair_stats$MSR[i])
    ref_group <- as.character(pair_stats$ref_group[i])
    target_group <- as.character(pair_stats$target_group[i])

    if (!raw_access$has_pair(msr, ref_group, target_group)) {
      return(0)
    }

    pair_raw <- raw_access$get_pair(msr, ref_group, target_group)
    ref_values <- as.numeric(pair_raw$ref_values)
    tgt_values <- as.numeric(pair_raw$tgt_values)

    ref_values <- ref_values[is.finite(ref_values)]
    tgt_values <- tgt_values[is.finite(tgt_values)]
    if (length(ref_values) == 0 || length(tgt_values) == 0) {
      return(0)
    }

    out <- stats::median(tgt_values) - stats::median(ref_values)
    if (!is.finite(out)) {
      return(0)
    }
    as.numeric(out)
  }, numeric(1))

  score[!is.finite(score)] <- 0
  as.numeric(score)
}
