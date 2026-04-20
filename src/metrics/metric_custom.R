# -------------------------------------------------------------------
# Collaborator Guide: add new metrics in this file only.
#
# 1) Function naming rule
#    - Must start with: metric_
#    - Example: metric_my_stat
#
# 2) Input contract (pair_dt columns)
#    - MSR
#    - mean_ref, mean_tgt
#    - sd_ref, sd_tgt
#    - n_ref, n_tgt
#
# 3) Output contract
#    - Must return a numeric vector.
#    - Vector length must be exactly nrow(pair_dt).
#    - Handle non-finite values and set them to 0.
#
# 4) Safety tip
#    - Any divide-by-zero or invalid row should return 0 for that row.
#    - Keep the function vectorized (no row loop) for speed.
# -------------------------------------------------------------------
#
# Template:
# metric_my_stat <- function(pair_dt) {
#   required_cols <- c("mean_ref", "mean_tgt", "sd_ref")
#   missing_cols <- setdiff(required_cols, names(pair_dt))
#   if (length(missing_cols) > 0) {
#     stop("metric_my_stat: missing required columns: ", paste(missing_cols, collapse = ", "))
#   }
#
#   score <- (as.numeric(pair_dt$mean_tgt) - as.numeric(pair_dt$mean_ref)) /
#     as.numeric(pair_dt$sd_ref)
#   score[!is.finite(score)] <- 0
#   as.numeric(score)
# }
