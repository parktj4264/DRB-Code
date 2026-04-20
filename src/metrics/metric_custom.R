# Add collaborator metrics in this file only.
# Each function must follow:
# - name: metric_<name>
# - input: pair_dt data.frame/data.table with columns
#   MSR, mean_ref, mean_tgt, sd_ref, sd_tgt, n_ref, n_tgt
# - output: numeric vector, length == nrow(pair_dt)
#
# Example:
# metric_my_stat <- function(pair_dt) {
#   score <- (pair_dt$mean_tgt - pair_dt$mean_ref) / pair_dt$sd_ref
#   score[!is.finite(score)] <- 0
#   as.numeric(score)
# }
