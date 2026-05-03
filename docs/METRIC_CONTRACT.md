# Metric Plugin Contract

## 1) Purpose (30-second version)
Add one `metric_*` function under `src/metrics`, and the engine will auto-create result columns.

- Input to your function: `pair_stats` (always), `raw_access` (optional, 2-arg mode)
- Output from your function: numeric vector, length = `nrow(pair_stats)`
- Engine output columns: `metric_<name>`, `abs_metric_<name>`

## 2) Naming and Auto-load Rules
- File: any `.R` file under `src/metrics/`
- Metric function name: must start with `metric_`
- Helper function name: must **not** start with `metric_`

Why:
- The engine sources all `.R` files in `src/metrics/`
- Then it collects functions by pattern `^metric_`
- So only `metric_*` functions become output metrics

## 3) Supported Signatures (Dual-mode)
- Legacy mode: `metric_<name>(pair_stats)`
- Raw-access mode: `metric_<name>(pair_stats, raw_access)`

Use raw-access mode when you need raw vectors (median, quantile, KS-like logic, ML features, etc.).

## 4) Input A: `pair_stats` (easy table)
`pair_stats` is one row per MSR.

| column | meaning |
|---|---|
| `MSR` | metric/measurement name for this row |
| `ref_group` | reference group name |
| `target_group` | target group name |
| `mean_ref` | mean of reference raw values |
| `mean_tgt` | mean of target raw values |
| `sd_ref` | sd of reference raw values |
| `sd_tgt` | sd of target raw values |
| `n_ref` | unique ROOTID count in reference group |
| `n_tgt` | unique ROOTID count in target group |

Note:
- `n_ref`/`n_tgt` count unique `ROOTID` (wafer-level group count), not raw chip-row count.

Example shape:

```text
pair_stats
+-----+----------+-------------+----------+----------+--------+--------+------+------+
|MSR  |ref_group |target_group |mean_ref  |mean_tgt  |sd_ref  |sd_tgt  |n_ref |n_tgt |
+-----+----------+-------------+----------+----------+--------+--------+------+------+
|M1   |REF       |TGT          |2.40      |7.40      |1.14    |1.14    |5     |5     |
|M2   |REF       |TGT          |12.00     |12.00     |1.58    |1.58    |5     |5     |
+-----+----------+-------------+----------+----------+--------+--------+------+------+
```

## 5) Input B: `raw_access` (lookup helper)
`raw_access` is not a table. It is a small API to fetch raw vectors on demand.

- `raw_access$has_pair(msr, ref_group, target_group)` -> `TRUE/FALSE`
- `raw_access$get_pair(msr, ref_group, target_group)` -> `list(ref_values, tgt_values)`
- `raw_access$get_group_values(msr, group_name)` -> numeric vector

Mental model:

```text
raw_access = "raw vector lookup box"
key = (MSR, group)
value = numeric raw vector
```

Example:

```r
raw_access$has_pair("M1", "REF", "TGT")
# TRUE

raw_access$get_pair("M1", "REF", "TGT")
# $ref_values: c(1, 2, 2, 3, 4)
# $tgt_values: c(6, 7, 7, 8, 9)
```

## 6) Why `raw_access` Feels Harder
`pair_stats` is already summarized, so vectorized math is straightforward.
`raw_access` requires per-row lookup:

1. Read one row from `pair_stats` (`MSR`, `ref_group`, `target_group`)
2. Fetch raw vectors with `raw_access`
3. Compute one scalar score for that row
4. Repeat for all rows

That is why code often has `for (...)` or `vapply(...)` and `[i]`.

`vapply(seq_len(nrow(pair_stats)), function(i) {...}, numeric(1))` means:
- loop rows `i = 1..N`
- return exactly one numeric value per row
- build numeric vector of length `N`

## 7) Easiest Raw Metric Template (copy/paste)
This template is beginner-friendly (explicit `for` loop).

```r
metric_median_shift <- function(pair_stats, raw_access) {
  out <- numeric(nrow(pair_stats))

  for (i in seq_len(nrow(pair_stats))) {
    msr <- as.character(pair_stats$MSR[i])
    ref_group <- as.character(pair_stats$ref_group[i])
    target_group <- as.character(pair_stats$target_group[i])

    if (!raw_access$has_pair(msr, ref_group, target_group)) {
      out[i] <- 0
      next
    }

    pair_raw <- raw_access$get_pair(msr, ref_group, target_group)
    ref_values <- as.numeric(pair_raw$ref_values)
    tgt_values <- as.numeric(pair_raw$tgt_values)

    ref_values <- ref_values[is.finite(ref_values)]
    tgt_values <- tgt_values[is.finite(tgt_values)]
    if (length(ref_values) == 0 || length(tgt_values) == 0) {
      out[i] <- 0
      next
    }

    score <- stats::median(tgt_values) - stats::median(ref_values)
    out[i] <- if (is.finite(score)) as.numeric(score) else 0
  }

  out[!is.finite(out)] <- 0
  as.numeric(out)
}
```

### 7-1) Same Logic with `vapply` (compact style)
If you prefer concise code, this is equivalent behavior using `vapply`.

```r
metric_median_shift <- function(pair_stats, raw_access) {
  out <- vapply(seq_len(nrow(pair_stats)), function(i) {
    msr <- as.character(pair_stats$MSR[i])
    ref_group <- as.character(pair_stats$ref_group[i])
    target_group <- as.character(pair_stats$target_group[i])

    if (!raw_access$has_pair(msr, ref_group, target_group)) {
      return(0)
    }

    pair_raw <- raw_access$get_pair(msr, ref_group, target_group)
    ref_values <- as.numeric(pair_raw$ref_values)
    tgt_values <- as.numeric(pair_raw$tgt_values)

    ref_values <- ref_values[is.finite(ref_values)]
    tgt_values <- tgt_values[is.finite(tgt_values)]
    if (length(ref_values) == 0 || length(tgt_values) == 0) {
      return(0)
    }

    score <- stats::median(tgt_values) - stats::median(ref_values)
    if (!is.finite(score)) {
      return(0)
    }
    as.numeric(score)
  }, numeric(1))

  out[!is.finite(out)] <- 0
  as.numeric(out)
}
```

## 8) Output Example (what will be added to results)
If your metric function is `metric_median_shift`:

- your function returns: `c(5.0, 0.0, -1.3, ...)`
- engine appends:
  - `metric_median_shift`
  - `abs_metric_median_shift`

So collaborators only need to add a function; output columns are automatic.

## 9) Output Contract (must follow)
- Return numeric vector only
- Vector length must be exactly `nrow(pair_stats)`
- Handle invalid values (`NA`, `NaN`, `Inf`) safely (recommended: `0`)
- Current engine behavior: non-finite values are normalized to `0` in metric validation (`src/02_calc_stats.R`, `validate_metric_vector`)
- Engine option now available: `na_policy = "zero"` (legacy) or `na_policy = "na"`/`"blank"` (keep as `NA`)

## 10) Current Core Behavior (important)
- `Sigma_Score` and `Abs_Sigma_Score` are always based on `metric_one_sigma`
- Direction/flag logic is one_sigma-threshold based
- Additional metrics are analysis columns and do not replace core decision logic by default
