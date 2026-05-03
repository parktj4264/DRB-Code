# Raw-access reference metric with sd_ref normalization.
#
# metric_median_shift:
# - Computes median(target_raw) - median(ref_raw) for each MSR row.
# - Normalizes by sd_ref from pair_stats.
# - Returns standardized location shift (effect-size like score).
metric_median_shift <- function(pair_stats, raw_access) {
  required_cols <- c("MSR", "ref_group", "target_group", "sd_ref")
  missing_cols <- setdiff(required_cols, names(pair_stats))
  if (length(missing_cols) > 0) {
    stop("metric_median_shift: missing required columns: ", paste(missing_cols, collapse = ", "))
  }

  score <- vapply(seq_len(nrow(pair_stats)), function(i) {
    msr <- as.character(pair_stats$MSR[i])
    ref_group <- as.character(pair_stats$ref_group[i])
    target_group <- as.character(pair_stats$target_group[i])
    pair_raw <- raw_access$get_pair(msr, ref_group, target_group)
    ref_values <- as.numeric(pair_raw$ref_values)
    tgt_values <- as.numeric(pair_raw$tgt_values)

    ref_values <- ref_values[is.finite(ref_values)]
    tgt_values <- tgt_values[is.finite(tgt_values)]

    sd_ref <- as.numeric(pair_stats$sd_ref[i])
    median_shift <- stats::median(tgt_values) - stats::median(ref_values)
    as.numeric(median_shift / sd_ref)
  }, numeric(1))

  as.numeric(score)
}
