# Metric Plugin Contract

## 1) Purpose (30-second version)
Add one `metric_*` function under `src/metrics`, and the engine auto-creates result columns.

- Input: `pair_stats` (always), `raw_access` (optional)
- Output: numeric vector, length = `nrow(pair_stats)`
- Engine output columns: `metric_<name>`, `abs_metric_<name>`

## 2) Auto-load Rules
- File: any `.R` file under `src/metrics/`
- Metric function: must start with `metric_`
- Helper function: must **not** start with `metric_`

Why:
- The engine sources all `.R` files in `src/metrics/`
- Then it collects functions with `^metric_`

## 3) Supported Signatures
- `metric_<name>(pair_stats)`
- `metric_<name>(pair_stats, raw_access)`
- `metric_<name>(pair_stats, my_param = 1)`
- `metric_<name>(pair_stats, raw_access, my_param = 1)`

Parameter meaning:
- `pair_stats`: always injected by engine
- `raw_access`: injected only if argument name is exactly `raw_access`
- All other named arguments: treated as tunable metric parameters

## 4) Which Arguments Are User-Tunable?
Short answer: function arguments except `pair_stats` and `raw_access`.

Example:

```r
metric_outlier_junsik <- function(pair_stats, raw_access,
                                  two_side = TRUE,
                                  sample_percentile = c(0.25, 0.5, 0.75),
                                  outlier_percentile = 0.99) {
  ...
}
```

In this function, tunable parameters are:
- `two_side`
- `sample_percentile`
- `outlier_percentile`

## 5) Where to Set Parameters (Priority)
You can set parameters in three places:

1. `run.R` -> `METRIC_PARAMS` (highest priority, personal/local override)
2. `config/metric_params.R` -> `METRIC_PARAMS` (team shared defaults)
3. `metric_*.R` function default arguments (fallback)

Priority rule:
- `run.R` > `config/metric_params.R` > function defaults

## 6) Configuration Examples
### 6-1) Team default (`config/metric_params.R`)

```r
METRIC_PARAMS <- list(
  metric_outlier_junsik = list(
    two_side = TRUE,
    sample_percentile = c(0.25, 0.5, 0.75),
    outlier_percentile = 0.99
  )
)
```

### 6-2) Local override (`run.R`)

```r
METRIC_PARAMS <- list(
  metric_outlier_junsik = list(
    two_side = FALSE,
    outlier_percentile = 0.995
  )
)
```

If both files define `metric_outlier_junsik$outlier_percentile`, `run.R` wins.

### 6-3) Partial override behavior
- Override only what you need
- Missing keys continue to use lower-priority value

Example:
- Function default: `sample_percentile = c(0.25, 0.5, 0.75)`
- Config override: none
- Run override: `two_side = FALSE`
- Final:
  - `two_side = FALSE` (run override)
  - `sample_percentile = c(0.25, 0.5, 0.75)` (function default)

## 7) Invalid Keys and Safety Behavior
- Unknown metric name in `METRIC_PARAMS`: ignored, recorded in metric issue report
- Unknown parameter name for a metric: ignored, recorded in metric issue report
- Existing metrics keep running (no hard crash from unknown keys)

Issue report files:
- `output/metric_issues_latest.csv`
- `output/results_<timestamp>/metric_issues_<timestamp>.csv`

## 8) Runtime Logging / Parameter Log
The parameter archive file now includes metric parameter details:
- `Metric Parameter Configuration` (source and priority context)
- `Metric Parameters Used` (value + `default`/`override` source)
- `Metric Runtime Summary`

File path:
- `output/results_<timestamp>/parameters_<timestamp>.txt`

## 9) Input A: `pair_stats`
`pair_stats` has one row per MSR.

| column | meaning |
|---|---|
| `MSR` | metric/measurement name |
| `ref_group` | reference group name |
| `target_group` | target group name |
| `mean_ref` | reference raw mean |
| `mean_tgt` | target raw mean |
| `sd_ref` | reference raw sd |
| `sd_tgt` | target raw sd |
| `n_ref` | unique ROOTID count in reference |
| `n_tgt` | unique ROOTID count in target |
| `n_ref_valid` | finite raw chip count for MSR in reference |
| `n_tgt_valid` | finite raw chip count for MSR in target |

## 10) Input B: `raw_access`
- `raw_access$meta_columns`
- `raw_access$has_pair(msr, ref_group, target_group)`
- `raw_access$get_pair(msr, ref_group, target_group)`
- `raw_access$get_group_values(msr, group_name)`
- `raw_access$get_group_meta(msr, group_name, include_values = FALSE)`
- `raw_access$get_group_data(msr, group_name)`
- `raw_access$get_pair_meta(msr, ref_group, target_group, include_values = FALSE)`

Metadata scope:
- all raw columns before `PARTID`

## 11) Output Contract
- Return numeric vector only
- Length must equal `nrow(pair_stats)`
- Engine fallback handles metric errors / invalid return shape/type
- Default NA policy: blanks in CSV (`na_policy = "na"` / `"blank"`)

## 12) Core Behavior (Important)
- `Sigma_Score` and `Abs_Sigma_Score` are always based on `metric_one_sigma`
- Direction is still one_sigma-threshold based
- Additional metrics are analysis columns by default
