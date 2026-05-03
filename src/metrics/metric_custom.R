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
#    - MSR          : metric name for current row
#    - ref_group    : selected reference group name
#    - target_group : selected target group name
#    - mean_ref     : mean of ref raw values (NA removed)
#    - mean_tgt     : mean of target raw values (NA removed)
#    - sd_ref       : sd of ref raw values (NA removed)
#    - sd_tgt       : sd of target raw values (NA removed)
#    - n_ref        : unique ROOTID count of reference group
#    - n_tgt        : unique ROOTID count of target group
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
#    - Non-finite values must be converted to 0.
#    - One metric function creates two output columns:
#      `metric_<name>` and `abs_metric_<name>`.
#
# 6) Practical tips
#    - Vectorized code is preferred for speed.
#    - If you iterate row-by-row for raw-based metrics, keep logic simple.
#    - Any invalid denominator or missing pair should return 0 for that row.
#    - Engine reference:
#      `src/02_calc_sigma.R` -> load (`list.files` + `sys.source`),
#      discover (`ls(..., pattern='^metric_')`),
#      write columns (`metric_<name>`, `abs_metric_<name>`).
# -------------------------------------------------------------------

# -------------------------------------------------------------------
# Template A: legacy 1-arg metric (still supported)
# -------------------------------------------------------------------
# metric_my_stat <- function(pair_stats) {
#   required_cols <- c("mean_ref", "mean_tgt", "sd_ref")
#   missing_cols <- setdiff(required_cols, names(pair_stats))
#   if (length(missing_cols) > 0) {
#     stop("metric_my_stat: missing required columns: ", paste(missing_cols, collapse = ", "))
#   }
#
#   score <- (as.numeric(pair_stats$mean_tgt) - as.numeric(pair_stats$mean_ref)) /
#     as.numeric(pair_stats$sd_ref)
#   score[!is.finite(score)] <- 0
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
#     if (!raw_access$has_pair(msr, ref_group, target_group)) {
#       return(0)
#     }
#
#     raw_pair <- raw_access$get_pair(msr, ref_group, target_group)
#     ref_values <- as.numeric(raw_pair$ref_values)
#     tgt_values <- as.numeric(raw_pair$tgt_values)
#
#     if (length(ref_values) < 2 || length(tgt_values) < 2) {
#       return(0)
#     }
#
#     # Example metric: target_mean - ref_mean using raw vectors
#     raw_score <- mean(tgt_values) - mean(ref_values)
#     if (!is.finite(raw_score)) {
#       return(0)
#     }
#     as.numeric(raw_score)
#   }, numeric(1))
#
#   score[!is.finite(score)] <- 0
#   as.numeric(score)
# }
