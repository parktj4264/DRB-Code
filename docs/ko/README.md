# DRB-Code

DRB-Code는 기준 그룹(reference)과 비교 대상 그룹(target) 간 측정값 이동을 비교 분석하는 R 기반 분석 파이프라인입니다.

문서 구분:
- 사용자 실행 안내: `README.md`
- 기술 상세 안내: `docs/ko/README.md`(현재 문서)

현재 핵심 동작:
- 주요 판단 메트릭은 `metric_one_sigma`입니다.
- `Sigma_Score`, `Abs_Sigma_Score`는 `metric_one_sigma`를 기반으로 계산됩니다.
- 추가 메트릭은 핵심 판단 로직을 바꾸지 않고 출력 컬럼으로 확장할 수 있습니다.
- 메인 실행 흐름에서 하나의 통합 PPT를 생성합니다.
- 통합 PPT 순서는 `표지 -> 목차 -> Summary (Required, 정확히 1장) -> Summary (Alarm-all) -> GOOBAE -> 카테고리별 Required/Alarm 상세 쌍`입니다. 각 카테고리에서 Required 바로 다음에 Alarm이 오며, 한쪽이 없으면 0 MSR 빈 장표를 유지합니다.

## 프로젝트 구조

```text
DRB-Code/
  data/                     # 입력 파일(raw.csv, ROOTID.csv, optional msrinfo/cateinfo.csv)
  output/                   # 분석 결과물
  spotfire/                 # DXP 껍데기와 고정 경로 Spotfire 데이터 묶음
  src/
    gui/
      gui_preview.R         # 실제 PPT와 공통인 composite Quick Preview
      gui_app.R             # 로컬 Shiny 화면과 기존 main.R 실행 연결
    bootstrap/
      libs.R
      utils.R
      io_utils.R
      runtime_config.R
    01_load_data.R
    02_calc_stats.R
    03_create_ppt.R
    04_create_spotfire.R
    05_finalize_outputs.R
    metrics/                # metric_<name>.R 플러그인 파일
  run.R                     # 사용자용 메인 실행 진입점(분석)
  run_gui.R                 # 사용자용 GUI 실행 진입점
  main.R                    # 오케스트레이터
```

## 빠른 시작

1. `data/`에 입력 파일을 배치합니다.
- `raw.csv`
- `ROOTID.csv`
- optional `msrinfo.csv`
- optional `cateinfo.csv`: PPT 카테고리 순서표

2. GUI를 사용하려면 `run_gui.R`을 실행하고, 스크립트 방식을 사용하려면 `run.R`의 최소 실행 파라미터를 수정합니다.

3. 필요하면 설정 파일을 수정합니다.
- `config/general_config.R`: good chip 규칙, NA 처리 정책
- `config/metric_config.R`: 메트릭별 튜닝 파라미터
- `config/ppt_config.R`: PPT 표/플롯 레이아웃과 스타일

4. 선택한 `run_gui.R` 또는 `run.R`을 실행합니다. GUI 상세 사용법은 [GUI 사용 및 설계](GUI.md)를 참고합니다.

## `run.R` 파라미터

- `RAW_FILENAME`: `data/` 안의 입력 raw 데이터 파일입니다.
- `ROOT_FILENAME`: `data/` 안의 그룹 매핑 파일입니다.
- `GOOD_CHIP_RULE_HOT`, `GOOD_CHIP_RULE_COLD`: Hot/Cold Bin의 Good-chip 조건 함수입니다. `run.R` 값이 일반 설정 파일보다 우선합니다.
- `SIGMA_THRESHOLD`: Up/Down 판단에 사용하는 임계값입니다.
- `GROUP_REF_NAME`: 선택형 기준 그룹입니다.
- `GROUP_TARGET_NAME`: 선택형 비교 대상 그룹입니다.
- `GENERATE_SPOTFIRE`: `results.csv` 생성 직후 고정 경로 Spotfire 데이터 묶음을 갱신합니다.
- `OPEN_SPOTFIRE`: Spotfire 데이터 단계 직후 설정된 DXP를 단순히 엽니다. `GENERATE_SPOTFIRE`와 독립적이며, 파일 또는 Windows 연결 프로그램이 없으면 경고만 남기고 분석을 계속합니다.
- `GENERATE_PPT`: PPT 단계만 생성하거나 건너뜁니다.
- PPT는 저장소의 `data/template_16_9.pptx`를 자동 사용하며, 템플릿 모드는 더 이상 `run.R`에 노출하지 않습니다.
- `PPT_AFFILIATION`: 모든 슬라이드의 `Confidential` 왼쪽에 표시할 소속명입니다.
- `PPT_SCATTER_TRIM_IQR`: `FALSE`면 끄고, 양수면 그룹별 IQR 배수 밖의 극단값만 radius scatter에서 제외합니다.
- `PPT_SCATTER_SHOW_MEAN`: radius scatter의 그룹별 평균선과 평균값 표시를 켜거나 끕니다.
- `PPT_CATEGORY_SCOPE`: PPT에 포함할 카테고리 값 범위입니다. `NULL`은 전체이며, 예를 들어 `list(Category1 = "PERI", Category2 = c("PB", "BL"))`처럼 지정합니다. 같은 Category의 값은 OR, 서로 다른 Category 조건은 AND로 적용됩니다. 이름 있는 범위 값이 비어 있으면 전체로 풀지 않고 즉시 오류를 냅니다.
- `PPT_CATEGORY_ORDER_FILE`: `data/`의 `msrinfo.csv` 옆에 둘 순서 파일명입니다. `Category1`부터 `Category5`까지 작성한 행 순서대로 PPT 카테고리를 배치합니다. `NULL`이거나 파일이 없거나 비어 있으면 오류 없이 기존 자동 순서를 사용합니다.
- `PPT_DETAIL_GROUP_BY`: 상세 슬라이드를 묶을 Category 단계입니다.
- `PPT_SUMMARY_GROUP_BY`: Required/Alarm Summary에 표시할 Category 계층입니다.

공통 PowerPoint 마스터 좌표와 재생성 방법은
[PPT 템플릿 디자인 명세](PPT_TEMPLATE_DESIGN.md)를 참고하세요.

## 설정 파일

- `config/general_config.R`
  - `NA_POLICY`: non-finite 메트릭 처리 방식입니다. 기본값은 `"na"`/`"blank"`이며, `"zero"`도 사용할 수 있습니다.
  - `GOOD_CHIP_RULE_HOT`, `GOOD_CHIP_RULE_COLD`: `run.R`에서 규칙을 지정하지 않았을 때 사용할 기본 good-chip 필터입니다.
- `config/metric_config.R`
  - `METRIC_PARAMS`: 메트릭별 파라미터 오버라이드입니다.
- `config/ppt_config.R`
  - `PPT_CONFIG`: 요약 행/페이지 수, top-N 차트, 그리드/마진, 플롯 스타일/색상 설정입니다.
  - `detail_group_by`: 상세 슬라이드 그룹 레벨입니다(`"Category1"`부터 `"Category5"`까지). 선택 레벨이 비어 있으면 가장 가까운 상위 카테고리, 그다음 `Uncategorized`로 대체됩니다.
  - `detail_progress_log_every`: MSR별 진행 로그를 선택적으로 표시하는 간격입니다. 기본값 `0`은 MSR별 로그를 끄고, 현재/전체 플롯 수와 ETA가 포함된 슬라이드 시작 로그만 표시합니다.
  - `summary_category_columns`: 통합 PPT 안의 두 Summary 구역에 적용하는 카테고리 그룹/표시 계층입니다. Required는 카테고리 조합마다 `SUMMARY_REQUIRED_YN` 체크 항목 중 최대 `|Sigma|`를 대표로 사용하고, 체크가 없으면 해당 조합 전체의 최대 `|Sigma|`를 사용합니다. Alarm-all은 finite `|Sigma_Score|`가 `SIGMA_THRESHOLD`를 엄격히 초과한 MSR을 카테고리별로 전부 표시하며, Required와 겹치는 MSR도 포함합니다.
  - `summary_table_left`, `summary_table_top`, `summary_table_width`, `summary_table_height`: 요약 표의 고정 콘텐츠 박스 좌표이며 단위는 inch입니다.
  - `summary_*_col_width`: compact 요약 표 컬럼 너비입니다. `TREND`는 수동 편집용으로 남겨 두고, Alarm-all의 note 컬럼에는 Required Summary/상세 중복 여부를 표시합니다.
  - `summary_*_fill` / `summary_*_color`: header, category cell, sigma-delta 강조 텍스트에 쓰는 compact 요약 표 색상입니다.
  - `ppt_font_family`: 생성 PPT의 텍스트와 표에 적용할 글꼴입니다(기본값: `Malgun Gothic`, 즉 맑은 고딕).
  - `wf_map_coordinate_mode`: `wafer_grid`는 wafer별 좌표 원점/배율/간격을 정규화해 WFMAP을 크게 표시하고, `physical`은 실제 좌표 간격을 보존합니다.
  - `wf_map_panel_arrangement`: `auto`는 REF/TARGET WFMAP이 가장 크게 보이는 가로/세로 배치를 자동 선택합니다.
  - `wf_map_force_square_display`: 실제 데이터의 X/Y pitch 또는 관측 범위가 달라도 `wafer_grid` WFMAP을 정사각형으로 보정하는 표시 전용 옵션입니다. chip 평균과 색 구간은 바뀌지 않습니다.
  - `composite_bottom_split`: 하단 CDF/WFMAP 폭 비율입니다. 기본값은 두 WFMAP을 촘촘하게 유지하면서 CDF 폭을 넓힙니다.
  - `radius_scatter_max_points_per_side`: 실무 PPT의 Radius chip scatter 표시 상한입니다. Rev1 기본값 `0`은 trim 후 모든 chip point를 표시합니다. GUI Quick Preview는 응답성을 위해 이 값과 별도로 Side당 최대 2,000점을 표시합니다.
  - `radius_scatter_trim_iqr`: `FALSE` 또는 그룹별 IQR 배수이며 radius scatter 화면에만 적용됩니다.
  - `radius_scatter_show_mean`: 화면에 표시된 radius scatter 데이터를 기준으로 평균선과 평균값을 표시합니다.
  - `cdf_max_points_per_side`: Side별로 그릴 정확한 rank 기반 CDF knot 상한입니다. 통계 결과는 전체 데이터를 사용합니다.
  - `wf_map_value_cache_max_cells`: 여러 MSR의 WFMAP 값을 재사용하는 캐시의 메모리 안전 한도입니다. 큰 입력은 자동으로 필요 시 집계 방식으로 전환합니다.
  - `data/msrinfo.csv`: `Category1`부터 `Category5`, `SLIDE_REQUIRED_YN`, `SUMMARY_REQUIRED_YN`의 기준 데이터입니다. required flag는 대소문자 구분 없이 `Y`, `YES`, `TRUE`, `1`을 참으로 처리합니다.
  - `data/cateinfo.csv`: `Category1`부터 `Category5`까지 가진 선택형 순서표입니다. 행 순서를 Summary, 표지 카테고리 집계, 목차, 카테고리별 Required/Alarm 상세 쌍에 공통 적용합니다. 파일에 없는 실제 카테고리는 제거하지 않고 지정 항목 뒤에 자동으로 붙입니다.
- `run.R`
  - `GENERATE_SPOTFIRE`: `TRUE`면 `spotfire/` 안의 생성 CSV를 모두 갱신하고, `FALSE`면 기존 Spotfire 묶음을 변경하지 않습니다.
  - `OPEN_SPOTFIRE`: `TRUE`면 데이터 단계 직후 DXP 열기를 요청합니다. DXP 내부 파일을 수정하거나 절대경로 데이터 연결을 자동 복구하지는 않습니다.
  - `GENERATE_PPT`: `TRUE`면 PPT를 생성·갱신하고, `FALSE`면 CSV·Spotfire feed·이력 결과는 계속 생성하면서 PPT 단계만 건너뜁니다. 비활성화 시 기존 최신 PPT는 변경하지 않습니다.
  - DRB 전용 템플릿은 내부에서 자동 선택하므로 일반 사용자는 layout mode를 설정할 필요가 없습니다.
  - `PPT_AFFILIATION`: 모든 생성 슬라이드에 공통으로 표시할 선택형 소속명입니다.
  - `PPT_SCATTER_TRIM_IQR`, `PPT_SCATTER_SHOW_MEAN`: radius scatter의 극단값 및 평균 표시 옵션입니다.
  - `PPT_CATEGORY_SCOPE`: PPT 범위만 제어합니다. `results.csv`와 Spotfire 데이터는 전체를 유지합니다.
  - `PPT_CATEGORY_ORDER_FILE`: `"cateinfo.csv"`면 저장된 순서를 사용하고, `NULL`이면 데이터 기반 자동 순서를 사용합니다.
  - 화면에 보이는 `PPT_*` 값은 내부 설정에 자동 반영합니다. 상세 그룹 단계와 Summary 계층도 각각 `PPT_DETAIL_GROUP_BY`, `PPT_SUMMARY_GROUP_BY`로 직접 설정합니다.

## 출력물

- `output/results.csv`: 최신 결과 테이블입니다.
- `output/results_<timestamp>/`: 실행별 아카이브 결과물입니다.
- `output/metric_issues_latest.csv`: 최신 메트릭 이슈 요약입니다. 이슈가 없으면 헤더만 저장됩니다.
- `output/results_<timestamp>/metric_issues_<timestamp>.csv`: 실행별 아카이브 메트릭 이슈 요약입니다.
- `output/sigma_summary_latest.pptx`: 최신 통합 PPT입니다. 표지, 간결한 실제 페이지 번호 목차, 한 장짜리 Required Summary, 페이지가 넘어가는 Alarm-all Summary, GOOBAE, 카테고리별 Required/Alarm 상세 쌍을 순서대로 담습니다. 한쪽이 없으면 0 MSR 빈 장표를 유지하고, Alarm에는 Required와 겹치는 Sigma 초과 MSR도 의도적으로 포함합니다.
- `output/results_<timestamp>/sigma_summary_<timestamp>.pptx`: 해당 실행의 단일 PPT 아카이브입니다.
- `output/snapshot_develop_framework.csv`: git으로 추적하는 기준 스냅샷입니다.

기존 중복 파일 `output/sigma_score_raw.csv`는 더 이상 생성하지 않으며, 업데이트 후 첫 실행에서 제거합니다. 이제 고정 경로는 `spotfire/sigma_score_raw.csv` 하나뿐입니다.

Spotfire 연결:

- `spotfire/drb_spotfire.dxp`와 모든 생성 데이터 파일은 `spotfire/` 한 폴더에 함께 둡니다.
- `spotfire/results.csv`: marking과 선택에 사용할 MSR별 control table입니다.
- `spotfire/<raw 파일명>_spotfire.csv`: Spotfire 전용 chip 단위 wide 데이터입니다. 예를 들어 `raw.csv`는 `raw_spotfire.csv`, `data_wow.csv`는 `data_wow_spotfire.csv`가 됩니다. 1행은 컬럼명, 2행은 Spotfire Type row이며 `PARTID` 다음의 모든 MSR 컬럼은 `Real`로 고정합니다.
- `spotfire/rootid.csv`: raw 행에 REF/TARGET 그룹을 연결하기 위한 `ROOTID`-`GROUP` 매핑입니다.
- `spotfire/goobae.csv`: category, wordline 이름/순서, `MSR`, `GROUP`, `VALUE`를 담은 그룹 평균 long-form 데이터입니다.
- `spotfire/sigma_score_raw.csv`: MSR별 sigma/평균/표준편차/count 고정 스키마 데이터입니다.
- 첫 실행은 원본 raw를 복사하고, 이후에는 원본 경로·크기·수정 시각이 같으면 대용량 복사를 건너뜁니다.
- `OPEN_SPOTFIRE <- TRUE`면 Spotfire CSV 단계 직후 운영체제에 `spotfire/drb_spotfire.dxp` 열기를 요청하고 PPT 생성은 계속 진행합니다. 이는 문서 열기만 수행하며, DXP 내부의 절대경로 데이터 소스를 갱신·재연결·수정하지 않습니다.

Git 추적 규칙(단순/수동):
- 로컬 실행 이력 보존을 위해 `output/results_*` 폴더는 의도적으로 git에서 제외합니다.
- `output/`에서는 아래 최신 고정 파일만 push합니다.
  `results.csv`, `metric_issues_latest.csv`, `sigma_summary_latest.pptx`, `snapshot_develop_framework.csv`
- 생성된 `spotfire/*.csv`와 raw 복사 판별 파일은 git에서 제외하고, `spotfire/README.md`와 `spotfire/drb_spotfire.dxp`는 추적합니다.
- 추가 아카이브를 공유해야 하면 별도 추적 경로로 복사하거나 이름을 바꾼 뒤 명시적으로 추가합니다.
- `.gitignore`는 이미 Git이 추적 중인 파일을 보호하지 못합니다. 사내 데이터를 `data/raw.csv`에 넣기 전에 `git ls-files -- data/raw.csv`로 추적 여부를 확인하고, 경로가 출력되면 사내 저장소 정책에 따라 untrack 또는 로컬 전용 데이터 절차를 적용하세요.

## 메트릭 확장(협업)

새 메트릭을 추가하려면 `src/metrics/metric_custom.R` 또는 다른 `metric_*.R` 파일에 함수를 추가합니다.

표준:
- 함수 이름은 반드시 `metric_`으로 시작해야 합니다.
- 자동 로드 규칙:
  `src/metrics/` 아래의 모든 `.R` 파일은 메트릭 엔진에서 source됩니다.
- 자동 발견 규칙:
  함수명 패턴이 `^metric_`와 일치하는 함수만 메트릭으로 수집됩니다.
- 지원 시그니처:
  `metric_x(pair_stats)` 또는 `metric_x(pair_stats, raw_access)`
- `pair_stats` 컬럼:
  `MSR`, `ref_group`, `target_group`, `mean_ref`, `mean_tgt`, `sd_ref`, `sd_tgt`, `n_ref`, `n_tgt`, `n_ref_valid`, `n_tgt_valid`
- count 의미:
  `n_ref`/`n_tgt`는 고유 `ROOTID` 개수(wafer 단위)이고,
  `n_ref_valid`/`n_tgt_valid`는 robust/normalized 메트릭에 쓰이는 MSR별 finite chip 개수입니다.
- `raw_access` 지원 함수:
  `has_pair(msr, ref_group, target_group)`,
  `get_pair(msr, ref_group, target_group)`,
  `get_group_values(msr, group_name)`,
  `get_group_meta(msr, group_name, include_values = FALSE)`,
  `get_group_data(msr, group_name)`,
  `get_pair_meta(msr, ref_group, target_group, include_values = FALSE)`
- `raw_access` 메타데이터 범위:
  `raw.csv`에서 `PARTID` 이전까지의 모든 컬럼을 메타데이터 컨텍스트로 보존합니다. 예: `EDGE`, `Radius`, `LOTID`, `WF`, bin 컬럼, 추가 사용자 정의 메타 컬럼
- 출력: 길이가 정확히 `nrow(pair_stats)`인 numeric 벡터입니다.
- 메트릭별 `required_cols` 검사는 필요하지 않습니다. 엔진이 표준화된 `pair_stats`를 전달합니다.
- 결과 컬럼:
  각 `metric_<name>` 함수는 `metric_<name>`과 `abs_metric_<name>` 컬럼을 생성합니다.
- 메트릭 코드는 단순하게 유지합니다. 메트릭 에러, 타입 불일치, 길이 불일치가 발생하면 엔진이 기본적으로 빈 값으로 채웁니다.
- 메트릭 이슈는 실행 후 `output/`의 CSV 리포트로 저장됩니다.
- helper/non-metric 유틸리티 함수는 허용되지만 `metric_` 접두어를 붙이지 마세요.

엔진 근거 코드:
- 함수 로드: `src/02_calc_stats.R` (`list.files(...\\.R$)`, `sys.source(...)`)
- 메트릭 발견: `src/02_calc_stats.R` (`ls(..., pattern = "^metric_")`)
- 출력 컬럼 생성: `src/02_calc_stats.R` (`final_dt[, (metric_name) := ...]`, `abs_` 쌍 컬럼)

예시:

```r
metric_my_stat <- function(pair_stats) {
  score <- (as.numeric(pair_stats$mean_tgt) - as.numeric(pair_stats$mean_ref)) /
    as.numeric(pair_stats$sd_ref)
  as.numeric(score)
}
```

## 문서

- 브랜치 전략(EN): docs/BRANCH_STRATEGY.md
- 브랜치 전략(KOR): docs/ko/BRANCH_STRATEGY.md
- 메트릭 플러그인 표준(EN): docs/METRIC_CONTRACT.md
- 메트릭 플러그인 표준(KOR): docs/ko/METRIC_CONTRACT.md
- 통합 PPT 변경·복구 안내: docs/ko/PPT_MAIN_SUGGESTED_ROLLBACK.md

## 브랜치 워크플로우

- 릴리즈 브랜치: `main`
- 통합 베이스라인 브랜치: `develop`(클린 상태 필요, direct push 금지)
- 작업 브랜치 `feature/*`: 시스템 엔지니어링 및 인프라 작업
- 작업 브랜치 `stats/*`: 통계/메트릭/모델 로직 작업
- 샌드박스 브랜치 `exp/*`: 임시 혼합 통합 테스트
- 안전 브랜치 `backup/*`: 고위험 변경 전 임시 스냅샷
- 핵심 규칙: `exp/*`는 절대 `develop`으로 병합하지 않고, 검증된 `feature/*` 또는 `stats/*` 브랜치만 PR로 `develop`에 병합합니다.
- 상세 정책: docs/BRANCH_STRATEGY.md

## 문서 정리 상태

현재 문서는 통합 PPT, `cateinfo.csv`, Spotfire DXP 단순 열기 계약까지 반영했습니다. 사내에서 DXP 데이터 연결 경로와 실행환경을 확인한 뒤 설치·실행 절차를 최종 정리합니다.
