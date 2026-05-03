# Raw-access reference metric with pooled-SD normalization.
#
# metric_median_shift:
# - Computes median(target_raw) - median(ref_raw) for each MSR row.
# - Normalizes by pooled SD from pair_stats:
#   sqrt(((n_ref_valid - 1) * sd_ref^2 + (n_tgt_valid - 1) * sd_tgt^2) /
#        (n_ref_valid + n_tgt_valid - 2))
# - Returns standardized location shift (effect-size like score).
metric_median_shift <- function(pair_stats, raw_access) {
  required_cols <- c(
    "MSR", "ref_group", "target_group",
    "sd_ref", "sd_tgt", "n_ref_valid", "n_tgt_valid"
  )
  missing_cols <- setdiff(required_cols, names(pair_stats))
  if (length(missing_cols) > 0) {
    stop("metric_median_shift: missing required columns: ", paste(missing_cols, collapse = ", "))
  }

  score <- vapply(seq_len(nrow(pair_stats)), function(i) {
    msr <- as.character(pair_stats$MSR[i])
    ref_group <- as.character(pair_stats$ref_group[i])
    target_group <- as.character(pair_stats$target_group[i])

    if (!raw_access$has_pair(msr, ref_group, target_group)) {
      return(NA_real_)
    }

    pair_raw <- raw_access$get_pair(msr, ref_group, target_group)
    ref_values <- as.numeric(pair_raw$ref_values)
    tgt_values <- as.numeric(pair_raw$tgt_values)

    ref_values <- ref_values[is.finite(ref_values)]
    tgt_values <- tgt_values[is.finite(tgt_values)]
    if (length(ref_values) == 0 || length(tgt_values) == 0) {
      return(NA_real_)
    }

    n_ref_valid <- as.numeric(pair_stats$n_ref_valid[i])
    n_tgt_valid <- as.numeric(pair_stats$n_tgt_valid[i])
    sd_ref <- as.numeric(pair_stats$sd_ref[i])
    sd_tgt <- as.numeric(pair_stats$sd_tgt[i])

    pooled_df <- n_ref_valid + n_tgt_valid - 2
    if (!is.finite(pooled_df) || pooled_df <= 0) {
      return(NA_real_)
    }
    if (!is.finite(sd_ref) || !is.finite(sd_tgt)) {
      return(NA_real_)
    }

    pooled_var_num <- (n_ref_valid - 1) * (sd_ref^2) + (n_tgt_valid - 1) * (sd_tgt^2)
    pooled_sd <- sqrt(pooled_var_num / pooled_df)
    if (!is.finite(pooled_sd) || pooled_sd <= 0) {
      return(NA_real_)
    }

    median_shift <- stats::median(tgt_values) - stats::median(ref_values)
    out <- median_shift / pooled_sd
    if (!is.finite(out)) {
      return(NA_real_)
    }
    as.numeric(out)
  }, numeric(1))

  as.numeric(score)
}
