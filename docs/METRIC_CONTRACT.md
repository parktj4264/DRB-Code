# Metric Plugin Contract

## Goal
Add new comparison statistics by adding one function file under `src/metrics`.

## File naming
- File: `metric_<name>.R`
- Function name: `metric_<name>`

## Supported signatures (dual-mode)
- Legacy mode: `metric_<name>(pair_stats)`
- Raw-access mode: `metric_<name>(pair_stats, raw_access)`

## `pair_stats` columns
- `MSR`
- `ref_group`
- `target_group`
- `mean_ref`
- `mean_tgt`
- `sd_ref`
- `sd_tgt`
- `n_ref`
- `n_tgt`

## `raw_access` helpers (2-arg mode)
- `raw_access$has_pair(msr, ref_group, target_group)` -> logical
- `raw_access$get_pair(msr, ref_group, target_group)` -> list(`ref_values`, `tgt_values`)
- `raw_access$get_group_values(msr, group_name)` -> numeric vector

## Output contract
- Return a numeric vector.
- Length must be exactly `nrow(pair_stats)`.
- Non-finite values should be handled (recommended: set to `0`).

## Current core behavior
- `Sigma_Score` and `Abs_Sigma_Score` are always one_sigma-based.
- Direction and flagging are one_sigma threshold based.
- Additional metrics are output-only columns for analysis.

## Example (raw-access mode)
```r
metric_example <- function(pair_stats, raw_access) {
  score <- vapply(seq_len(nrow(pair_stats)), function(i) {
    msr <- as.character(pair_stats$MSR[i])
    ref_group <- as.character(pair_stats$ref_group[i])
    target_group <- as.character(pair_stats$target_group[i])

    if (!raw_access$has_pair(msr, ref_group, target_group)) {
      return(0)
    }

    raw_pair <- raw_access$get_pair(msr, ref_group, target_group)
    ref_values <- as.numeric(raw_pair$ref_values)
    tgt_values <- as.numeric(raw_pair$tgt_values)
    if (length(ref_values) < 2 || length(tgt_values) < 2) {
      return(0)
    }

    out <- mean(tgt_values) - mean(ref_values)
    if (!is.finite(out)) {
      return(0)
    }
    as.numeric(out)
  }, numeric(1))

  score[!is.finite(score)] <- 0
  as.numeric(score)
}
```
