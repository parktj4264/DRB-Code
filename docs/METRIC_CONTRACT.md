# Metric Plugin Contract

## Goal
Add new comparison statistics by adding one function file under `src/metrics`.

## File naming
- File: `metric_<name>.R`
- Function: `metric_<name>(pair_dt)`

## Required input columns in `pair_dt`
- `MSR`
- `mean_ref`
- `mean_tgt`
- `sd_ref`
- `sd_tgt`
- `n_ref`
- `n_tgt`

## Output contract
- Return a numeric vector.
- Length must be exactly `nrow(pair_dt)`.
- Non-finite values should be handled (recommended: set to `0`).

## Current core behavior
- `Sigma_Score` and `Abs_Sigma_Score` are always Glass-based.
- Direction and flagging are Glass-threshold based.
- Additional metrics are output-only columns for analysis.

## Example
```r
metric_example <- function(pair_dt) {
  score <- (pair_dt$mean_tgt - pair_dt$mean_ref) / pair_dt$sd_ref
  score[!is.finite(score)] <- 0
  as.numeric(score)
}
```
