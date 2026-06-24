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
    bootstrap/
      libs.R
      utils.R
      runtime_config.R
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

2. Open and edit `run.R` minimal parameters.
3. Edit config files when needed:
- `config/general_config.R` (good chip rules, NA policy)
- `config/metric_config.R` (metric-specific tunables)
- `config/ppt_config.R` (PPT table/plot layout and style)

4. Run `run.R`.

## `run.R` Parameters

- `RAW_FILENAME`: input raw data file in `data/`.
- `ROOT_FILENAME`: group mapping file in `data/`.
- `SIGMA_THRESHOLD`: threshold used for Up/Down decision.
- `GROUP_REF_NAME`: optional reference group(s).
- `GROUP_TARGET_NAME`: optional target group(s).

## Config Files

- `config/general_config.R`
  - `NA_POLICY`: non-finite metric handling (`"na"`/`"blank"` default, or `"zero"`).
  - `GOOD_CHIP_RULE_HOT`, `GOOD_CHIP_RULE_COLD`: primary good-chip filter rules.
- `config/metric_config.R`
  - `METRIC_PARAMS`: per-metric parameter overrides.
- `config/ppt_config.R`
  - `PPT_CONFIG`: summary rows/page, top-N charts, grid/margins, plot style/colors.
  - `detail_group_by`: detail slide grouping level (`"Category1"` through `"Category5"`). Blank selected levels fall back to the nearest upper category, then `Uncategorized`.
  - `detail_msr_selection_mode`: detail candidate rule using `SLIDE_REQUIRED_YN`; choose `"required_only"`, `"flagged_only"`, or `"both"`.
  - `summary_msr_selection_mode`: legacy compatibility key; redesigned summary selection ignores this mode.
  - `summary_category_columns`: category grouping/display hierarchy for summary tables, for example `c("Category1", "Category2", "Category3")`. Summary selects one representative MSR per category combination, prioritizing `SUMMARY_REQUIRED_YN`.
  - `summary_table_left`, `summary_table_top`, `summary_table_width`, `summary_table_height`: fixed summary table content box in inches.
  - `summary_*_col_width`: compact summary table widths; `TREND` and note columns are left blank for manual editing.
  - `summary_*_fill` / `summary_*_color`: compact summary table colors for header, category cells, and sigma-delta text highlights.
  - `data/msrinfo.csv`: category source of truth with `Category1` through `Category5`, `SLIDE_REQUIRED_YN`, and `SUMMARY_REQUIRED_YN`. Required flags treat `Y`, `YES`, `TRUE`, and `1` as true, case-insensitively.

## Outputs

- `output/results.csv`: latest result table.
- `output/results_<timestamp>/`: archived run artifacts.
- `output/metric_issues_latest.csv`: latest metric issue summary (header-only when no issues).
- `output/results_<timestamp>/metric_issues_<timestamp>.csv`: archived metric issue summary.
- `output/sigma_summary_latest.pptx`: latest PPT summary.
- `output/snapshot_develop_framework.csv`: tracked baseline snapshot.

Git tracking rule (simple/manual):
- Keep local history: `output/results_*` folders are intentionally ignored by git.
- Push only these latest fixed files from `output/`:
  `results.csv`, `metric_issues_latest.csv`, `sigma_summary_latest.pptx`, `snapshot_develop_framework.csv`.
- If you need to share extra archives, do it intentionally by copying/renaming into a separately tracked path.

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
  `has_pair(msr, ref_group, target_group)`,
  `get_pair(msr, ref_group, target_group)`,
  `get_group_values(msr, group_name)`,
  `get_group_meta(msr, group_name, include_values = FALSE)`,
  `get_group_data(msr, group_name)`,
  `get_pair_meta(msr, ref_group, target_group, include_values = FALSE)`.
- Metadata scope for `raw_access`:
  all columns up to `PARTID` are preserved as metadata context (for example `EDGE`, `Radius`, `LOTID`, `WF`, bin columns, and additional custom meta columns).
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
- raw_access metadata access checks (`EDGE`/`Radius` examples),
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

