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
    02_calc_sigma.R
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
- `GROUP_REF_NAME`: optional reference group(s).
- `GROUP_TARGET_NAME`: optional target group(s).

## Outputs

- `output/results.csv`: latest result table.
- `output/results_<timestamp>/`: archived run artifacts.
- `output/Sigma_Summary_Latest.pptx`: latest PPT summary.
- `output/snapshot_*.csv`: snapshot files intentionally tracked in git.

## Metric Extension (Collaboration)

To add a new metric, add a function in `src/metrics/metric_custom.R` (or another `metric_*.R` file).

Contract:
- Function name must start with `metric_`.
- Input: `pair_dt` containing
  `MSR`, `mean_ref`, `mean_tgt`, `sd_ref`, `sd_tgt`, `n_ref`, `n_tgt`.
- Output: numeric vector with length exactly `nrow(pair_dt)`.
- Invalid/non-finite values should be converted to `0`.

Example:

```r
metric_my_stat <- function(pair_dt) {
  score <- (as.numeric(pair_dt$mean_tgt) - as.numeric(pair_dt$mean_ref)) /
    as.numeric(pair_dt$sd_ref)
  score[!is.finite(score)] <- 0
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

