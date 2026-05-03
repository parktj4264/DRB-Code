# DRB-Code (한국어)

DRB-Code는 기준군(reference)과 비교군(target) 간 측정값 이동을 비교 분석하는 R 기반 파이프라인입니다.

언어:
- English: README.md
- Korean: docs/ko/README.md

현재 핵심 동작:
- 주요 의사결정 지표: `metric_one_sigma`
- `Sigma_Score`, `Abs_Sigma_Score`는 `metric_one_sigma` 기반
- 추가 메트릭은 코어 의사결정 로직을 바꾸지 않고 출력 컬럼으로 확장 가능
- 메인 실행 흐름에 PPT 요약 생성 포함

## 프로젝트 구조

```text
DRB-Code/
  data/                     # 입력 파일 (raw.csv, ROOTID.csv, optional msrinfo.csv)
  output/                   # 분석 결과물
  src/
    00_libs.R
    00_utils.R
    01_load_data.R
    02_calc_stats.R
    03_create_ppt.R
    metrics/                # metric_<name>.R 플러그인 파일
  tests/                    # 테스트 스크립트 및 실행기
  run.R                     # 사용자 메인 실행 진입점(분석)
  main.R                    # 오케스트레이터
```

## 빠른 시작

1. `data/`에 입력 파일 배치:
- `raw.csv`
- `ROOTID.csv`
- optional `msrinfo.csv`

2. 필요 시 `run.R` 파라미터 수정.

3. `run.R` 실행.

## `run.R` 파라미터

- `RAW_FILENAME`: `data/` 내 입력 raw 데이터 파일
- `ROOT_FILENAME`: `data/` 내 그룹 매핑 파일
- `GOOD_CHIP_LIMIT`: 선택적 필터 컷오프
- `SIGMA_THRESHOLD`: Up/Down 판정 임계값
- `GROUP_REF_NAME`: 선택적 기준 그룹
- `GROUP_TARGET_NAME`: 선택적 비교 그룹

## 출력물

- `output/results.csv`: 최신 결과 테이블
- `output/results_<timestamp>/`: 실행 아카이브 산출물
- `output/Sigma_Summary_Latest.pptx`: 최신 PPT 요약본
- `output/snapshot_*.csv`: 의도적으로 git 추적되는 스냅샷 파일

## 메트릭 확장 (협업)

새 메트릭을 추가하려면 `src/metrics/metric_custom.R`(또는 다른 `metric_*.R` 파일)에 함수를 추가하세요.

표준:
- 함수명은 `metric_`로 시작해야 함
- 입력: `pair_dt`에 다음 컬럼 포함
  `MSR`, `mean_ref`, `mean_tgt`, `sd_ref`, `sd_tgt`, `n_ref`, `n_tgt`
- 출력: 길이가 정확히 `nrow(pair_dt)`인 numeric 벡터
- 자동 로딩 규칙:
  `src/metrics/` 아래의 `.R` 파일은 메트릭 엔진이 모두 source 한다.
- 자동 인식 규칙:
  함수명 패턴이 `^metric_`인 함수만 메트릭으로 수집된다.
- 결과 컬럼:
  `metric_<name>` 함수 1개당 `metric_<name>`, `abs_metric_<name>` 2개 컬럼이 생성됨
- 유효하지 않은 값(non-finite)은 `0`으로 치환 권장
- 헬퍼/유틸 함수는 추가해도 되지만 함수명에 `metric_` 접두어를 붙이지 말 것

엔진 근거 코드:
- 파일 로딩: `src/02_calc_stats.R` (`list.files(...\\.R$)`, `sys.source(...)`)
- 메트릭 함수 수집: `src/02_calc_stats.R` (`ls(..., pattern = "^metric_")`)
- 출력 컬럼 생성: `src/02_calc_stats.R` (`final_dt[, (metric_name) := ...]`, `abs_` 컬럼)

예시:

```r
metric_my_stat <- function(pair_dt) {
  score <- (as.numeric(pair_dt$mean_tgt) - as.numeric(pair_dt$mean_ref)) /
    as.numeric(pair_dt$sd_ref)
  score[!is.finite(score)] <- 0
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
- 스키마 수준 end-to-end 검증
- pooled SD 메트릭 검증(해당 브랜치 기준)

## 문서

- 브랜치 전략 (EN): docs/BRANCH_STRATEGY.md
- 브랜치 전략 (KOR): docs/ko/BRANCH_STRATEGY.md
- 메트릭 플러그인 표준 (EN): docs/METRIC_CONTRACT.md
- 메트릭 플러그인 표준 (KOR): docs/ko/METRIC_CONTRACT.md

## 브랜치 워크플로우

- 릴리즈 브랜치: `main`
- 베이스라인 통합 브랜치: `develop` (클린 상태 유지, direct push 금지)
- 작업 브랜치 `feature/*`: 시스템 엔지니어링 및 인프라 작업
- 작업 브랜치 `stats/*`: 통계/메트릭/모델 로직 작업
- 샌드박스 브랜치 `exp/*`: 혼합 통합 테스트용 임시 브랜치
- 안전 브랜치 `backup/*`: 고위험 구조 변경 전 임시 스냅샷 브랜치
- 핵심 규칙: `exp/*`는 `develop`으로 병합하지 않으며, 검증된 `feature/*` 또는 `stats/*`만 PR로 `develop`에 병합
- 상세 정책: docs/BRANCH_STRATEGY.md


