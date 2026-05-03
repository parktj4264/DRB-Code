# DRB-Code

DRB-Code is an R-based analysis pipeline for comparing measurement shifts between reference and target groups.

Language:
- English: README.md
- Korean: docs/ko/README.md

Current core behavior:
- Primary decision metric: `metric_one_sigma`.
- `Sigma_Score` and `Abs_Sigma_Score` are based on `metric_one_sigma`.
- Additional metrics can be added as output columns without changing core decision logic.
- PPT summary generation is included in the main run flow.

## Project Structure

```text
DRB-Code/
  data/                     # Input files (raw.csv, ROOTID.csv, optional msrinfo.csv)
  output/                   # Analysis outputs
  src/
    00_libs.R
    00_utils.R
    01_load_data.R
    02_calc_stats.R
    03_create_ppt.R
    metrics/                # metric_<name>.R plugin files
  tests/                    # test scripts and runner
  run.R                     # Main user entrypoint (analysis)
  main.R                    # Orchestrator
```

## Quick Start

1. Put input files in `data/`:
- `raw.csv`
- `ROOTID.csv`
- optional `msrinfo.csv`

2. Open and edit `run.R` parameters if needed.

3. Run `run.R`.

## `run.R` Parameters

- `RAW_FILENAME`: input raw data file in `data/`.
- `ROOT_FILENAME`: group mapping file in `data/`.
- `GOOD_CHIP_LIMIT`: optional filter cutoff.
- `SIGMA_THRESHOLD`: threshold used for Up/Down decision.
- `NA_POLICY`: non-finite metric handling (`"na"`/`"blank"` default, or `"zero"` legacy).
- `GROUP_REF_NAME`: optional reference group(s).
- `GROUP_TARGET_NAME`: optional target group(s).

## Outputs

- `output/results.csv`: latest result table.
- `output/results_<timestamp>/`: archived run artifacts.
- `output/metric_issues_latest.csv`: latest metric issue summary (header-only when no issues).
- `output/results_<timestamp>/metric_issues_<timestamp>.csv`: archived metric issue summary.
- `output/Sigma_Summary_Latest.pptx`: latest PPT summary.
- `output/snapshot_*.csv`: snapshot files intentionally tracked in git.

For git push automation of output history:
- Run `Rscript scripts/stage_latest_output.R`
- It keeps local `output/results_*` folders as-is, but updates git tracking so only latest folder is staged for push.

## Metric Extension (Collaboration)

To add a new metric, add a function in `src/metrics/metric_custom.R` (or another `metric_*.R` file).

Standard:
- Function name must start with `metric_`.
- Auto-load rule:
  every `.R` file under `src/metrics/` is sourced by the metric engine.
- Auto-discovery rule:
  only functions with names matching `^metric_` are collected as metrics.
- Supported signatures:
  `metric_x(pair_stats)` or `metric_x(pair_stats, raw_access)`.
- `pair_stats` contains:
  `MSR`, `ref_group`, `target_group`, `mean_ref`, `mean_tgt`, `sd_ref`, `sd_tgt`, `n_ref`, `n_tgt`, `n_ref_valid`, `n_tgt_valid`.
- Count semantics:
  `n_ref`/`n_tgt` are unique ROOTID counts (wafer-level), and
  `n_ref_valid`/`n_tgt_valid` are per-MSR finite chip counts used for robust/normalized metrics.
- `raw_access` supports:
  `has_pair(msr, ref_group, target_group)`, `get_pair(msr, ref_group, target_group)`.
- Output: numeric vector with length exactly `nrow(pair_stats)`.
- Per-metric `required_cols` checks are not needed; engine passes standardized `pair_stats`.
- Result columns:
  each `metric_<name>` creates `metric_<name>` and `abs_metric_<name>` columns.
- Keep metric code simple; engine fills blanks by default when metric error/type/length mismatch occurs.
- Metric issues are saved to CSV reports in `output/` after each run.
- Helper/non-metric utility functions are allowed, but do not prefix them with `metric_`.

Engine reference:
- Function loading: `src/02_calc_stats.R` (`list.files(...\\.R$)`, `sys.source(...)`)
- Metric discovery: `src/02_calc_stats.R` (`ls(..., pattern = "^metric_")`)
- Output column creation: `src/02_calc_stats.R` (`final_dt[, (metric_name) := ...]`, `abs_` pair column)

Example:

```r
metric_my_stat <- function(pair_stats) {
  score <- (as.numeric(pair_stats$mean_tgt) - as.numeric(pair_stats$mean_ref)) /
    as.numeric(pair_stats$sd_ref)
  as.numeric(score)
}
```

## Tests

Run all tests:

```bash
Rscript tests/run_tests.R
```

Current test scope includes:
- core one_sigma regression checks,
- schema-level end-to-end checks,
- pooled SD metric checks (on pooled branch).

## Documentation

- Branch strategy (EN): docs/BRANCH_STRATEGY.md
- Branch strategy (KOR): docs/ko/BRANCH_STRATEGY.md
- Metric plugin standard (EN): docs/METRIC_CONTRACT.md
- Metric plugin standard (KOR): docs/ko/METRIC_CONTRACT.md

## Branch Workflow

- Release branch: `main`
- Baseline integration branch: `develop` (clean state required, direct push disallowed)
- Work branch `feature/*`: system engineering and infrastructure work
- Work branch `stats/*`: statistics/metric/model logic work
- Sandbox branch `exp/*`: temporary mixed integration tests
- Safety branch `backup/*`: temporary snapshot before risky structural changes
- Critical rule: never merge `exp/*` into `develop`; only merge validated `feature/*` or `stats/*` branches via PR
- Detailed policy: docs/BRANCH_STRATEGY.md

