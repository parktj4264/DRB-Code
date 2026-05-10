# Anderson-Darling p-value metric.
#
# Formula (per MSR pair):
#   score = p-value from twosamples::ad_test(target_raw, reference_raw)
# Uses cached AD results from metric_ad_helper.R.
metric_ad_pvalue <- function(pair_stats, raw_access) {
  if (!requireNamespace("twosamples", quietly = TRUE)) {
    return(rep(NA_real_, nrow(pair_stats)))
  }

  nboots <- helper_function_get_ad_nboots()

  score <- vapply(seq_len(nrow(pair_stats)), function(i) {
    msr <- as.character(pair_stats$MSR[i])
    ref_group <- as.character(pair_stats$ref_group[i])
    target_group <- as.character(pair_stats$target_group[i])

    ad_pair <- helper_function_get_ad_pair_result(raw_access, msr, ref_group, target_group, nboots)
    as.numeric(ad_pair[[2]])
  }, numeric(1))

  as.numeric(score)
}
