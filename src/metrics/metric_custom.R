# -------------------------------------------------------------------
# Collaborator Guide: add metric_* function definitions in this file.
#
# Quick rules
# 0) File scan behavior
#    - The engine sources every `.R` file under `src/metrics/`.
#    - Therefore helper functions in the same file are allowed.
#
# 1) Function name
#    - Must start with: metric_
#    - Example: metric_my_stat
#    - Only functions matching `^metric_` are treated as output metrics.
#    - Helper utilities must NOT use `metric_` prefix.
#
# 2) Supported function signatures (dual-mode)
#    A. Legacy compatible:
#       metric_x(pair_stats)
#    B. New raw-access mode:
#       metric_x(pair_stats, raw_access)
#
# 3) pair_stats columns (always available)
#    - You do NOT need per-metric `required_cols` checks.
#      The engine standardizes the schema before calling metric functions.
#    - MSR          : metric name for current row
#    - ref_group    : selected reference group name
#    - target_group : selected target group name
#    - mean_ref     : mean of ref raw values (NA removed)
#    - mean_tgt     : mean of target raw values (NA removed)
#    - sd_ref       : sd of ref raw values (NA removed)
#    - sd_tgt       : sd of target raw values (NA removed)
#    - n_ref        : unique ROOTID count of reference group (wafer-level)
#    - n_tgt        : unique ROOTID count of target group (wafer-level)
#    - n_ref_valid  : finite raw chip count for ref group at current MSR
#    - n_tgt_valid  : finite raw chip count for target group at current MSR
#
# 4) raw_access helpers (available in 2-arg mode)
#    - raw_access$has_pair(msr, ref_group, target_group)
#      -> TRUE/FALSE if both raw vectors exist.
#    - raw_access$get_pair(msr, ref_group, target_group)
#      -> list(ref_values = numeric, tgt_values = numeric)
#    - raw_access$get_group_values(msr, group_name)
#      -> numeric vector for one MSR/group.
#
# 5) Output standard (required)
#    - Return numeric vector only.
#    - Length must be exactly nrow(pair_stats).
#    - Non-finite values are handled by engine policy (`na_policy`).
#      Default is blank (`NA` in R, blank in CSV). Legacy option: zero.
#    - One metric function creates two output columns:
#      `metric_<name>` and `abs_metric_<name>`.
#
# 6) Practical tips
#    - Vectorized code is preferred for speed.
#    - If you iterate row-by-row for raw-based metrics, keep logic simple.
#    - You may skip heavy defensive checks in each metric function.
#      If a metric errors or returns invalid shape/type, engine fills blanks by default.
#    - Metric issues are recorded to CSV reports:
#      `output/metric_issues_latest.csv`
#      `output/results_<timestamp>/metric_issues_<timestamp>.csv`
#    - Example normalized formula (median shift / sd_ref):
#      median_shift = median(tgt_raw) - median(ref_raw)
#      score = median_shift / sd_ref
#    - Engine reference:
#      `src/02_calc_stats.R` -> load (`list.files` + `sys.source`),
#      discover (`ls(..., pattern='^metric_')`),
#      write columns (`metric_<name>`, `abs_metric_<name>`).
# -------------------------------------------------------------------

# -------------------------------------------------------------------
# Template A: legacy 1-arg metric (still supported)
# -------------------------------------------------------------------
# metric_my_stat <- function(pair_stats) {
#   score <- (as.numeric(pair_stats$mean_tgt) - as.numeric(pair_stats$mean_ref)) /
#     as.numeric(pair_stats$sd_ref)
#   as.numeric(score)
# }

# -------------------------------------------------------------------
# Template B: new 2-arg metric with raw access
# -------------------------------------------------------------------
# metric_my_raw_stat <- function(pair_stats, raw_access) {
#   score <- vapply(seq_len(nrow(pair_stats)), function(i) {
#     msr <- as.character(pair_stats$MSR[i])
#     ref_group <- as.character(pair_stats$ref_group[i])
#     target_group <- as.character(pair_stats$target_group[i])
#
#     raw_pair <- raw_access$get_pair(msr, ref_group, target_group)
#     ref_values <- as.numeric(raw_pair$ref_values)
#     tgt_values <- as.numeric(raw_pair$tgt_values)
#
#     # Example metric: target_mean - ref_mean using raw vectors
#     as.numeric(mean(tgt_values) - mean(ref_values))
#   }, numeric(1))
#
#   as.numeric(score)
# }

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

metric_ks_pvalue <- function(pair_stats, raw_access) {
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

    as.numeric(suppressWarnings(stats::ks.test(tgt_values, ref_values)$p.value))
  }, numeric(1))

  as.numeric(score)
}

# Shared cache for Anderson-Darling results within one R session.
.ad_cache_env <- new.env(parent = emptyenv())

get_ad_nboots <- function(default_nboots = 100L) {
  raw_value <- Sys.getenv("SIGMA_AD_NBOOTS", "")
  if (identical(raw_value, "")) {
    return(as.integer(default_nboots))
  }

  parsed <- suppressWarnings(as.integer(raw_value))
  if (is.na(parsed)) {
    return(as.integer(default_nboots))
  }

  # Keep runtime and statistical stability in a sane range.
  as.integer(max(20L, min(2000L, parsed)))
}

get_ad_pair_result <- function(raw_access, msr, ref_group, target_group, nboots) {
  cache_key <- paste(msr, ref_group, target_group, nboots, sep = "||")
  if (exists(cache_key, envir = .ad_cache_env, inherits = FALSE)) {
    return(get(cache_key, envir = .ad_cache_env, inherits = FALSE))
  }

  raw_pair <- raw_access$get_pair(msr, ref_group, target_group)
  ref_values <- as.numeric(raw_pair$ref_values)
  tgt_values <- as.numeric(raw_pair$tgt_values)

  if (length(ref_values) == 0 || length(tgt_values) == 0) {
    ad_pair <- c(statistic = NA_real_, pvalue = NA_real_)
  } else {
    ad_res <- twosamples::ad_test(
      tgt_values,
      ref_values,
      nboots = nboots,
      keep.boots = FALSE,
      keep.samples = FALSE
    )
    ad_pair <- c(statistic = as.numeric(ad_res[[1]]), pvalue = as.numeric(ad_res[[2]]))
  }

  assign(cache_key, ad_pair, envir = .ad_cache_env)
  ad_pair
}

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

metric_ad_pvalue <- function(pair_stats, raw_access) {
  if (!requireNamespace("twosamples", quietly = TRUE)) {
    return(rep(NA_real_, nrow(pair_stats)))
  }

  nboots <- get_ad_nboots()

  score <- vapply(seq_len(nrow(pair_stats)), function(i) {
    msr <- as.character(pair_stats$MSR[i])
    ref_group <- as.character(pair_stats$ref_group[i])
    target_group <- as.character(pair_stats$target_group[i])

    ad_pair <- get_ad_pair_result(raw_access, msr, ref_group, target_group, nboots)
    as.numeric(ad_pair[[2]])
  }, numeric(1))

  as.numeric(score)
}
