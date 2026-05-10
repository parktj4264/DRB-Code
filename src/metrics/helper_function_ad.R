# Anderson-Darling helper functions.
#
# Core test call:
#   twosamples::ad_test(target_raw, reference_raw, nboots = N)
# Returns:
#   [1] AD statistic, [2] p-value
#
# We cache per (MSR, ref_group, target_group, nboots) to avoid duplicate
# ad_test calls when both metric_ad_stats and metric_ad_pvalue are requested.
# Shared cache for Anderson-Darling results within one R session.
.ad_cache_env <- new.env(parent = emptyenv())

helper_function_get_ad_nboots <- function(default_nboots = 100L) {
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

helper_function_get_ad_pair_result <- function(raw_access, msr, ref_group, target_group, nboots) {
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
