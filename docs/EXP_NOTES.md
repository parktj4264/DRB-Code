# Experiment Notes

## 2026-05-11 - exp/stats-no-median-shift

- Purpose: mixed integration validation for selected `stats/*` metric branches.
- Important naming note: branch name includes `no-median-shift`, but this branch is tracked by actual enabled metrics below.
- Enabled metrics in this experiment:
  - `metric_one_sigma`
  - `metric_ks_stats`
  - `metric_ks_pvalue`
  - `metric_ad_stats`
  - `metric_ad_pvalue`
  - `metric_quantile_tail_ratio`
- Excluded from this experiment:
  - `metric_median_shift`

