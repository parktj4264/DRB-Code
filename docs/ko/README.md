# DRB-Code

DRB-Code는 기준 그룹(reference)과 비교 대상 그룹(target) 간 측정값 이동을 비교 분석하는 R 기반 분석 파이프라인입니다.

언어:
- English: README.md
- Korean: docs/ko/README.md

현재 핵심 동작:
- 주요 판단 메트릭은 `metric_one_sigma`입니다.
- `Sigma_Score`, `Abs_Sigma_Score`는 `metric_one_sigma`를 기반으로 계산됩니다.
- 추가 메트릭은 핵심 판단 로직을 바꾸지 않고 출력 컬럼으로 확장할 수 있습니다.
- 메인 실행 흐름에 PPT 요약 생성이 포함됩니다.

## 프로젝트 구조

```text
DRB-Code/
  data/                     # 입력 파일(raw.csv, ROOTID.csv, optional msrinfo.csv)
  output/                   # 분석 결과물
  src/
    bootstrap/
      libs.R
      utils.R
      runtime_config.R
    01_load_data.R
    02_calc_stats.R
    03_create_ppt.R
    metrics/                # metric_<name>.R 플러그인 파일
  tests/                    # 테스트 스크립트와 실행기
  run.R                     # 사용자용 메인 실행 진입점(분석)
  main.R                    # 오케스트레이터
```

## 빠른 시작

1. `data/`에 입력 파일을 배치합니다.
- `raw.csv`
- `ROOTID.csv`
- optional `msrinfo.csv`

2. `run.R`을 열어 최소 실행 파라미터를 수정합니다.

3. 필요하면 설정 파일을 수정합니다.
- `config/general_config.R`: good chip 규칙, NA 처리 정책
- `config/metric_config.R`: 메트릭별 튜닝 파라미터
- `config/ppt_config.R`: PPT 표/플롯 레이아웃과 스타일

4. `run.R`을 실행합니다.

## `run.R` 파라미터

- `RAW_FILENAME`: `data/` 안의 입력 raw 데이터 파일입니다.
- `ROOT_FILENAME`: `data/` 안의 그룹 매핑 파일입니다.
- `SIGMA_THRESHOLD`: Up/Down 판단에 사용하는 임계값입니다.
- `GROUP_REF_NAME`: 선택형 기준 그룹입니다.
- `GROUP_TARGET_NAME`: 선택형 비교 대상 그룹입니다.

## 설정 파일

- `config/general_config.R`
  - `NA_POLICY`: non-finite 메트릭 처리 방식입니다. 기본값은 `"na"`/`"blank"`이며, `"zero"`도 사용할 수 있습니다.
  - `GOOD_CHIP_RULE_HOT`, `GOOD_CHIP_RULE_COLD`: 기본 good-chip 필터 규칙입니다.
- `config/metric_config.R`
  - `METRIC_PARAMS`: 메트릭별 파라미터 오버라이드입니다.
- `config/ppt_config.R`
  - `PPT_CONFIG`: 요약 행/페이지 수, top-N 차트, 그리드/마진, 플롯 스타일/색상 설정입니다.
  - `detail_group_by`: 상세 슬라이드 그룹 레벨입니다(`"Category1"`부터 `"Category5"`까지). 선택 레벨이 비어 있으면 가장 가까운 상위 카테고리, 그다음 `Uncategorized`로 대체됩니다.
  - `detail_msr_selection_mode`: `SLIDE_REQUIRED_YN`을 이용한 상세 후보 선택 규칙입니다. `"required_only"`, `"flagged_only"`, `"both"` 중 선택합니다.
  - `detail_progress_log_every`: MSR별 진행 로그를 선택적으로 표시하는 간격입니다. 기본값 `0`은 MSR별 로그를 끄고, 현재/전체 플롯 수·경과 시간·ETA가 포함된 슬라이드 시작/완료 로그만 표시합니다.
  - `summary_msr_selection_mode`: 레거시 호환 키입니다. 재설계된 요약 선택 로직은 이 모드를 무시합니다.
  - `summary_category_columns`: 요약 표의 카테고리 그룹/표시 계층입니다. 예: `c("Category1", "Category2", "Category3")`. 요약은 카테고리 조합별 대표 MSR 1개를 선택하며 `SUMMARY_REQUIRED_YN`을 우선합니다.
  - `summary_table_left`, `summary_table_top`, `summary_table_width`, `summary_table_height`: 요약 표의 고정 콘텐츠 박스 좌표이며 단위는 inch입니다.
  - `summary_*_col_width`: compact 요약 표 컬럼 너비입니다. `TREND`와 note 컬럼은 수동 편집을 위해 비워 둡니다.
  - `summary_*_fill` / `summary_*_color`: header, category cell, sigma-delta 강조 텍스트에 쓰는 compact 요약 표 색상입니다.
  - `ppt_font_family`: 생성 PPT의 텍스트와 표에 적용할 글꼴입니다(기본값: `Malgun Gothic`, 즉 맑은 고딕).
  - `wf_map_coordinate_mode`: `wafer_grid`는 wafer별 좌표 원점/배율/간격을 정규화해 WFMAP을 크게 표시하고, `physical`은 실제 좌표 간격을 보존합니다.
  - `wf_map_panel_arrangement`: `auto`는 REF/TARGET WFMAP이 가장 크게 보이는 가로/세로 배치를 자동 선택합니다.
  - `wf_map_force_square_display`: 실제 데이터의 X/Y pitch 또는 관측 범위가 달라도 `wafer_grid` WFMAP을 정사각형으로 보정하는 표시 전용 옵션입니다. chip 평균과 색 구간은 바뀌지 않습니다.
  - `composite_bottom_split`: 하단 CDF/WFMAP 폭 비율입니다. 기본값은 두 WFMAP을 촘촘하게 유지하면서 CDF 폭을 넓힙니다.
  - `radius_scatter_max_points_per_side`: 화면 표시용 결정적 scatter 상한입니다. 극단값과 희소한 2차원 영역을 보존하며 계산은 전체 행을 사용합니다.
  - `cdf_max_points_per_side`: Side별로 그릴 정확한 rank 기반 CDF knot 상한입니다. 통계 결과는 전체 데이터를 사용합니다.
  - `wf_map_value_cache_max_cells`: 여러 MSR의 WFMAP 값을 재사용하는 캐시의 메모리 안전 한도입니다. 큰 입력은 자동으로 필요 시 집계 방식으로 전환합니다.
  - `data/msrinfo.csv`: `Category1`부터 `Category5`, `SLIDE_REQUIRED_YN`, `SUMMARY_REQUIRED_YN`의 기준 데이터입니다. required flag는 대소문자 구분 없이 `Y`, `YES`, `TRUE`, `1`을 참으로 처리합니다.
- `run.R`
  - `GENERATE_PPT`: `TRUE`면 PPT를 생성·갱신하고, `FALSE`면 CSV·Spotfire feed·이력 결과는 계속 생성하면서 PPT 단계만 건너뜁니다. 비활성화 시 기존 최신 PPT는 변경하지 않습니다.

## 출력물

- `output/results.csv`: 최신 결과 테이블입니다.
- `output/sigma_score_raw.csv`: 고정 스키마의 최신 Spotfire 피드(`MSR × REF × TARGET`)이며, 실행 성공 시 임시 파일을 거쳐 안전하게 교체합니다.
- `output/results_<timestamp>/`: 실행별 아카이브 결과물입니다.
- `output/metric_issues_latest.csv`: 최신 메트릭 이슈 요약입니다. 이슈가 없으면 헤더만 저장됩니다.
- `output/results_<timestamp>/metric_issues_<timestamp>.csv`: 실행별 아카이브 메트릭 이슈 요약입니다.
- `output/sigma_summary_latest.pptx`: 최신 PPT 요약본입니다.
- `output/snapshot_develop_framework.csv`: git으로 추적하는 기준 스냅샷입니다.

Spotfire 연결:

- MSR별 sigma/평균/표준편차/count는 `output/sigma_score_raw.csv`를 연결합니다.
- chip 단위 원본은 `data/raw.csv`를 연결하고, 그룹 정보가 필요하면 `data/ROOTID.csv`를 `ROOTID`로 관계 설정합니다.
- 대용량 raw 파일은 `output/`에 중복 복사하지 않습니다.

Git 추적 규칙(단순/수동):
- 로컬 실행 이력 보존을 위해 `output/results_*` 폴더는 의도적으로 git에서 제외합니다.
- `output/`에서는 아래 최신 고정 파일만 push합니다.
  `results.csv`, `metric_issues_latest.csv`, `sigma_summary_latest.pptx`, `snapshot_develop_framework.csv`
- `sigma_score_raw.csv`는 사내 결과가 포함될 수 있는 실시간 Spotfire 피드이므로 의도적으로 git ignore 상태를 유지합니다.
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

## 테스트

전체 테스트 실행:

```bash
Rscript tests/run_tests.R
```

현재 테스트 범위:
- core one_sigma 회귀 검증
- raw_access 메타데이터 접근 검증(`EDGE`/`Radius` 예시)
- 스키마 수준 end-to-end 검증
- pooled SD 메트릭 검증(pooled 브랜치 기준)

## 문서

- 브랜치 전략(EN): docs/BRANCH_STRATEGY.md
- 브랜치 전략(KOR): docs/ko/BRANCH_STRATEGY.md
- 메트릭 플러그인 표준(EN): docs/METRIC_CONTRACT.md
- 메트릭 플러그인 표준(KOR): docs/ko/METRIC_CONTRACT.md

## 브랜치 워크플로우

- 릴리즈 브랜치: `main`
- 통합 베이스라인 브랜치: `develop`(클린 상태 필요, direct push 금지)
- 작업 브랜치 `feature/*`: 시스템 엔지니어링 및 인프라 작업
- 작업 브랜치 `stats/*`: 통계/메트릭/모델 로직 작업
- 샌드박스 브랜치 `exp/*`: 임시 혼합 통합 테스트
- 안전 브랜치 `backup/*`: 고위험 변경 전 임시 스냅샷
- 핵심 규칙: `exp/*`는 절대 `develop`으로 병합하지 않고, 검증된 `feature/*` 또는 `stats/*` 브랜치만 PR로 `develop`에 병합합니다.
- 상세 정책: docs/BRANCH_STRATEGY.md
