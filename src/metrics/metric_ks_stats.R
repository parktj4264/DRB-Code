# Two-sample Kolmogorov-Smirnov statistic.
#
# Formula:
#   D = sup_x |F_tgt(x) - F_ref(x)|
# where F_tgt and F_ref are empirical CDFs of target/reference raw values.
metric_ks_stats <- function(pair_stats, raw_access) {
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

    as.numeric(suppressWarnings(stats::ks.test(tgt_values, ref_values)$statistic))
  }, numeric(1))

  as.numeric(score)
}
