metric_ad_stats <- function(pair_stats, raw_access) {
  if (!requireNamespace("twosamples", quietly = TRUE)) {
    return(rep(NA_real_, nrow(pair_stats)))
  }

  nboots <- get_ad_nboots()

  score <- vapply(seq_len(nrow(pair_stats)), function(i) {
    msr <- as.character(pair_stats$MSR[i])
    ref_group <- as.character(pair_stats$ref_group[i])
    target_group <- as.character(pair_stats$target_group[i])

    ad_pair <- get_ad_pair_result(raw_access, msr, ref_group, target_group, nboots)
    as.numeric(ad_pair[[1]])
  }, numeric(1))

  as.numeric(score)
}
