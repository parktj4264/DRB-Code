# KS-test based metrics using raw_access.
# These metrics are intended for heavy/statistical validation branches.

get_pair_raw_vectors <- function(pair_stats, row_idx, raw_access) {
  msr <- as.character(pair_stats$MSR[row_idx])
  ref_group <- as.character(pair_stats$ref_group[row_idx])
  target_group <- as.character(pair_stats$target_group[row_idx])

  if (!raw_access$has_pair(msr, ref_group, target_group)) {
    return(NULL)
  }

  raw_pair <- raw_access$get_pair(msr, ref_group, target_group)
  ref_values <- as.numeric(raw_pair$ref_values)
  tgt_values <- as.numeric(raw_pair$tgt_values)

  ref_values <- ref_values[is.finite(ref_values)]
  tgt_values <- tgt_values[is.finite(tgt_values)]

  if (length(ref_values) < 2 || length(tgt_values) < 2) {
    return(NULL)
  }

  list(ref_values = ref_values, tgt_values = tgt_values)
}

run_ks_test <- function(ref_values, tgt_values) {
  tryCatch(
    suppressWarnings(stats::ks.test(
      x = ref_values,
      y = tgt_values,
      exact = FALSE
    )),
    error = function(e) NULL
  )
}

# ks_metric_stat (disabled from auto metric loading):
# - Same KS statistic helper kept for optional/manual analysis.
# - Not prefixed with metric_, so it will NOT be auto-added to results.csv.
ks_metric_stat <- function(pair_stats, raw_access) {
  score <- vapply(seq_len(nrow(pair_stats)), function(i) {
    pair_raw <- get_pair_raw_vectors(pair_stats, i, raw_access)
    if (is.null(pair_raw)) {
      return(0)
    }

    ks_fit <- run_ks_test(pair_raw$ref_values, pair_raw$tgt_values)
    if (is.null(ks_fit)) {
      return(0)
    }

    d_stat <- as.numeric(ks_fit$statistic[[1]])
    if (!is.finite(d_stat)) {
      return(0)
    }

    as.numeric(d_stat)
  }, numeric(1))

  score[!is.finite(score)] <- 0
  as.numeric(score)
}

# ks_metric_significance (disabled from auto metric loading):
# - Same KS significance helper kept for optional/manual analysis.
# - Not prefixed with metric_, so it will NOT be auto-added to results.csv.
ks_metric_significance <- function(pair_stats, raw_access) {
  score <- vapply(seq_len(nrow(pair_stats)), function(i) {
    pair_raw <- get_pair_raw_vectors(pair_stats, i, raw_access)
    if (is.null(pair_raw)) {
      return(0)
    }

    ks_fit <- run_ks_test(pair_raw$ref_values, pair_raw$tgt_values)
    if (is.null(ks_fit)) {
      return(0)
    }

    p_value <- as.numeric(ks_fit$p.value)
    if (!is.finite(p_value) || is.na(p_value)) {
      return(0)
    }

    p_value <- min(max(p_value, 1e-300), 1)
    as.numeric(-log10(p_value))
  }, numeric(1))

  score[!is.finite(score)] <- 0
  as.numeric(score)
}
