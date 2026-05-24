# General analysis configuration
# Priority: run.R override > GENERAL_CONFIG > default

GENERAL_CONFIG <- list(
  # =========================
  # Frequently Edited
  # =========================
  NA_POLICY = "na", # "na" or "zero"

  # =========================
  # Good Chip Rules
  # =========================
  # Priority: Cold rule -> Hot fallback (when Cold is NA) -> auto-good (when both are NA)
  GOOD_CHIP_RULE_HOT = function(lds_hot_bin) {
    !is.na(lds_hot_bin) & (lds_hot_bin < 130)
  },
  GOOD_CHIP_RULE_COLD = function(lds_cold_bin) {
    !is.na(lds_cold_bin) & ((lds_cold_bin < 130) | (lds_cold_bin >= 790 & lds_cold_bin < 800))
  }
)
