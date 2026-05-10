# Metric 플러그인 계약서

## 1) 목적 (30초 요약)
`src/metrics` 아래에 `metric_*` 함수를 추가하면, 엔진이 결과 컬럼을 자동 생성합니다.

- 입력: `pair_stats`(항상), `raw_access`(선택)
- 출력: 숫자 벡터, 길이 = `nrow(pair_stats)`
- 자동 생성 컬럼: `metric_<name>`, `abs_metric_<name>`

## 2) 자동 로드 규칙
- 파일: `src/metrics/` 아래의 모든 `.R`
- 메트릭 함수명: `metric_`로 시작해야 함
- 헬퍼 함수명: `metric_`로 시작하면 안 됨

이유:
- 엔진이 `src/metrics/`의 `.R` 파일을 전부 `source`
- 이후 `^metric_` 패턴으로 함수만 수집

## 3) 지원 함수 시그니처
- `metric_<name>(pair_stats)`
- `metric_<name>(pair_stats, raw_access)`
- `metric_<name>(pair_stats, my_param = 1)`
- `metric_<name>(pair_stats, raw_access, my_param = 1)`

파라미터 해석:
- `pair_stats`: 엔진이 항상 주입
- `raw_access`: 인자 이름이 정확히 `raw_access`일 때만 주입
- 그 외 named 인자: 튜닝 가능한 메트릭 파라미터로 인식

## 4) 어떤 인자가 수정 가능한가?
짧게 말하면, `pair_stats`/`raw_access`를 제외한 함수 인자입니다.

예시:

```r
metric_outlier_junsik <- function(pair_stats, raw_access,
                                  two_side = TRUE,
                                  sample_percentile = c(0.25, 0.5, 0.75),
                                  outlier_percentile = 0.99) {
  ...
}
```

이 함수에서 수정 가능한 파라미터:
- `two_side`
- `sample_percentile`
- `outlier_percentile`

## 5) 파라미터 설정 위치와 우선순위
파라미터는 3곳에서 설정할 수 있습니다.

1. `run.R`의 `METRIC_PARAMS` (최우선, 개인/임시 실험용)
2. `config/metric_params.R`의 `METRIC_PARAMS` (팀 공유 기본값)
3. `metric_*.R` 함수 기본 인자값 (최종 fallback)

우선순위:
- `run.R` > `config/metric_params.R` > 함수 기본값

## 6) 설정 예시
### 6-1) 팀 기본값 (`config/metric_params.R`)

```r
METRIC_PARAMS <- list(
  metric_outlier_junsik = list(
    two_side = TRUE,
    sample_percentile = c(0.25, 0.5, 0.75),
    outlier_percentile = 0.99
  )
)
```

### 6-2) 개인 오버라이드 (`run.R`)

```r
METRIC_PARAMS <- list(
  metric_outlier_junsik = list(
    two_side = FALSE,
    outlier_percentile = 0.995
  )
)
```

두 곳에 동일 키가 있으면 `run.R` 값이 최종 적용됩니다.

### 6-3) 부분 오버라이드 동작
- 필요한 키만 덮어쓰면 됩니다.
- 없는 키는 하위 우선순위 값을 그대로 사용합니다.

예:
- 함수 기본값: `sample_percentile = c(0.25, 0.5, 0.75)`
- config 설정: 없음
- run 설정: `two_side = FALSE`
- 최종 적용:
  - `two_side = FALSE` (run 오버라이드)
  - `sample_percentile = c(0.25, 0.5, 0.75)` (함수 기본값)

## 7) 잘못된 키 처리
- 존재하지 않는 metric 이름을 `METRIC_PARAMS`에 넣으면: 무시 + 이슈 리포트 기록
- 존재하지 않는 파라미터명을 넣으면: 무시 + 이슈 리포트 기록
- 즉, 잘못된 키 때문에 전체 실행이 바로 실패하지는 않습니다.

이슈 리포트 경로:
- `output/metric_issues_latest.csv`
- `output/results_<timestamp>/metric_issues_<timestamp>.csv`

## 8) 실행 로그 / 파라미터 로그
파라미터 아카이브 파일에 아래가 함께 기록됩니다.
- `Metric Parameter Configuration` (설정 소스/우선순위)
- `Metric Parameters Used` (값 + default/override 출처)
- `Metric Runtime Summary`

경로:
- `output/results_<timestamp>/parameters_<timestamp>.txt`

## 9) 입력 A: `pair_stats`
`pair_stats`는 MSR 기준 1행 1레코드입니다.

| 컬럼 | 의미 |
|---|---|
| `MSR` | 측정 항목 이름 |
| `ref_group` | 기준 그룹 이름 |
| `target_group` | 비교 그룹 이름 |
| `mean_ref` | 기준 그룹 raw 평균 |
| `mean_tgt` | 비교 그룹 raw 평균 |
| `sd_ref` | 기준 그룹 raw 표준편차 |
| `sd_tgt` | 비교 그룹 raw 표준편차 |
| `n_ref` | 기준 그룹 고유 ROOTID 수 |
| `n_tgt` | 비교 그룹 고유 ROOTID 수 |
| `n_ref_valid` | 기준 그룹 유효(finite) chip 수 |
| `n_tgt_valid` | 비교 그룹 유효(finite) chip 수 |

## 10) 입력 B: `raw_access`
- `raw_access$meta_columns`
- `raw_access$has_pair(msr, ref_group, target_group)`
- `raw_access$get_pair(msr, ref_group, target_group)`
- `raw_access$get_group_values(msr, group_name)`
- `raw_access$get_group_meta(msr, group_name, include_values = FALSE)`
- `raw_access$get_group_data(msr, group_name)`
- `raw_access$get_pair_meta(msr, ref_group, target_group, include_values = FALSE)`

메타데이터 범위:
- raw에서 `PARTID` 이전 컬럼 전체

## 11) 출력 계약
- 숫자 벡터만 반환
- 길이는 반드시 `nrow(pair_stats)`와 동일
- 함수 에러/반환 형태 불일치는 엔진 fallback으로 처리
- 기본 NA 정책: CSV에서 빈칸(`na_policy = "na"` 또는 `"blank"`)

## 12) 코어 동작 (중요)
- `Sigma_Score`, `Abs_Sigma_Score`는 항상 `metric_one_sigma` 기반
- Direction 판정도 one_sigma 임계값 기반
- 추가 메트릭은 기본적으로 분석용 컬럼입니다.
