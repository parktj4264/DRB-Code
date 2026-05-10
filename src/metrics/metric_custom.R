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
