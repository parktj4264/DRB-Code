# 메트릭 플러그인 표준

## 1) 목적 (30초 요약)
`src/metrics`에 `metric_*` 함수 하나를 추가하면, 결과 컬럼이 자동으로 생긴다.

- 함수 입력: `pair_stats`(항상), `raw_access`(2인자 모드에서 사용)
- 함수 출력: 숫자 벡터, 길이 = `nrow(pair_stats)`
- 엔진 자동 컬럼: `metric_<name>`, `abs_metric_<name>`

## 2) 이름 규칙 + 자동 로드 규칙
- 파일: `src/metrics/` 아래의 아무 `.R` 파일
- 메트릭 함수명: `metric_`로 시작해야 함
- 헬퍼 함수명: `metric_`로 시작하면 안 됨

이유:
- 엔진이 `src/metrics/`의 `.R` 파일을 모두 `source`함
- 그 다음 함수명 패턴 `^metric_`만 메트릭으로 수집함
- 그래서 `metric_*`만 결과 컬럼으로 추가됨

## 3) 지원 함수 형태 (Dual-mode)
- 레거시 모드: `metric_<name>(pair_stats)`
- raw-access 모드: `metric_<name>(pair_stats, raw_access)`

raw 벡터가 필요한 메트릭(중앙값, 분위수, KS 계열, ML 피처 등)은 raw-access 모드를 쓰면 된다.

## 4) 입력 A: `pair_stats` (읽기 쉬운 표)
`pair_stats`는 MSR 1행당 1행이다.

| 컬럼 | 의미 |
|---|---|
| `MSR` | 현재 행의 측정 항목 이름 |
| `ref_group` | 기준 그룹 이름 |
| `target_group` | 비교 대상 그룹 이름 |
| `mean_ref` | 기준 그룹 raw 평균 |
| `mean_tgt` | 대상 그룹 raw 평균 |
| `sd_ref` | 기준 그룹 raw 표준편차 |
| `sd_tgt` | 대상 그룹 raw 표준편차 |
| `n_ref` | 기준 그룹 고유 ROOTID 개수 |
| `n_tgt` | 대상 그룹 고유 ROOTID 개수 |
| `n_ref_valid` | 현재 MSR에서 기준 그룹의 유효(finite) chip 개수 |
| `n_tgt_valid` | 현재 MSR에서 대상 그룹의 유효(finite) chip 개수 |

참고:
- `n_ref`/`n_tgt`는 raw chip row 개수가 아니라, 고유 `ROOTID` 개수(wafer 단위 개수)다.
- `n_ref_valid`/`n_tgt_valid`는 MSR별 결측 제외 유효 chip 개수다.

예시 모양:

```text
pair_stats
+-----+----------+-------------+----------+----------+--------+--------+------+------+------------+------------+
|MSR  |ref_group |target_group |mean_ref  |mean_tgt  |sd_ref  |sd_tgt  |n_ref |n_tgt |n_ref_valid |n_tgt_valid |
+-----+----------+-------------+----------+----------+--------+--------+------+------+------------+------------+
|M1   |REF       |TGT          |2.40      |7.40      |1.14    |1.14    |5     |5     |451          |451         |
|M2   |REF       |TGT          |12.00     |12.00     |1.58    |1.58    |5     |5     |447          |450         |
+-----+----------+-------------+----------+----------+--------+--------+------+------+------------+------------+
```

## 5) 입력 B: `raw_access` (raw 조회 도구)
`raw_access`는 테이블이 아니라, 필요할 때 raw 벡터를 꺼내는 함수 묶음이다.

- `raw_access$has_pair(msr, ref_group, target_group)` -> `TRUE/FALSE`
- `raw_access$get_pair(msr, ref_group, target_group)` -> `list(ref_values, tgt_values)`
- `raw_access$get_group_values(msr, group_name)` -> 숫자 벡터

직관적인 비유:

```text
raw_access = "raw 벡터 조회 박스"
키(key) = (MSR, group)
값(value) = 숫자 raw 벡터
```

예시:

```r
raw_access$has_pair("M1", "REF", "TGT")
# TRUE

raw_access$get_pair("M1", "REF", "TGT")
# $ref_values: c(1, 2, 2, 3, 4)
# $tgt_values: c(6, 7, 7, 8, 9)
```

## 6) 왜 `raw_access`가 더 어렵게 보이나?
`pair_stats`는 이미 요약값이 준비되어 있어서 바로 계산이 가능하다.
`raw_access`는 행마다 raw 벡터를 조회해야 해서 단계가 하나 더 있다.

1. `pair_stats`의 i행에서 `MSR/ref_group/target_group`을 읽는다.
2. `raw_access`로 해당 raw 벡터를 가져온다.
3. 그 행의 점수 1개를 계산한다.
4. 모든 행에 대해 반복한다.

그래서 코드에 `for (...)` 또는 `vapply(...)`와 `[i]`가 보인다.

`vapply(seq_len(nrow(pair_stats)), function(i) {...}, numeric(1))` 뜻:
- `i = 1..N` 행 반복
- 각 행에서 숫자 1개를 반환
- 최종적으로 길이 `N`인 숫자 벡터 생성

## 7) 가장 쉬운 raw 메트릭 템플릿 (복붙용)
아래는 이해하기 쉬운 `for` 루프 버전이다.

이 섹션 수식:
- `median_shift = median(tgt_raw) - median(ref_raw)`
- `score = median_shift / sd_ref`
- 메트릭 함수는 단순하게 작성해도 되고, 에러/형식 불일치는 엔진이 자동으로 빈칸(NA) 처리한다.

```r
metric_median_shift <- function(pair_stats, raw_access) {
  out <- numeric(nrow(pair_stats))

  for (i in seq_len(nrow(pair_stats))) {
    msr <- as.character(pair_stats$MSR[i])
    ref_group <- as.character(pair_stats$ref_group[i])
    target_group <- as.character(pair_stats$target_group[i])
    pair_raw <- raw_access$get_pair(msr, ref_group, target_group)
    ref_values <- as.numeric(pair_raw$ref_values)
    tgt_values <- as.numeric(pair_raw$tgt_values)
    sd_ref <- as.numeric(pair_stats$sd_ref[i])
    median_shift <- stats::median(tgt_values) - stats::median(ref_values)
    out[i] <- as.numeric(median_shift / sd_ref)
  }

  as.numeric(out)
}
```

### 7-1) 같은 로직의 `vapply` 버전 (간결 스타일)
코드를 더 짧게 쓰고 싶으면 아래처럼 `vapply`를 써도 동작은 동일하다.

```r
metric_median_shift <- function(pair_stats, raw_access) {
  out <- vapply(seq_len(nrow(pair_stats)), function(i) {
    msr <- as.character(pair_stats$MSR[i])
    ref_group <- as.character(pair_stats$ref_group[i])
    target_group <- as.character(pair_stats$target_group[i])
    pair_raw <- raw_access$get_pair(msr, ref_group, target_group)
    ref_values <- as.numeric(pair_raw$ref_values)
    tgt_values <- as.numeric(pair_raw$tgt_values)
    sd_ref <- as.numeric(pair_stats$sd_ref[i])
    median_shift <- stats::median(tgt_values) - stats::median(ref_values)
    as.numeric(median_shift / sd_ref)
  }, numeric(1))

  as.numeric(out)
}
```

## 8) 출력 예시 (결과에 무엇이 생기나?)
함수명이 `metric_median_shift`면:

- 함수 반환값 예: `c(5.0, 0.0, -1.3, ...)`
- 결과 테이블 자동 추가 컬럼:
  - `metric_median_shift`
  - `abs_metric_median_shift`

즉, 협업자는 함수만 추가하면 되고 컬럼 생성은 엔진이 자동 처리한다.

## 9) 출력 표준 (반드시 지킬 것)
- 숫자 벡터만 반환
- 길이는 반드시 `nrow(pair_stats)`와 동일
- 함수마다 과도한 예외처리를 하지 않아도 됨 (엔진이 시스템 레벨에서 보호)
- 메트릭 함수 에러/타입 불일치/길이 불일치 시, 해당 메트릭 컬럼은 빈칸(NA)으로 자동 채움
- 기본 정책: `na_policy = "na"`/`"blank"` (CSV에서는 빈칸)
- 표준 정책: `na_policy = "na"`/`"blank"` 사용

## 10) 현재 코어 동작 (중요)
- `Sigma_Score`, `Abs_Sigma_Score`는 항상 `metric_one_sigma` 기준
- Direction/Flag 판단도 one_sigma 임계값 기준
- 추가 메트릭은 기본적으로 분석용 컬럼이며, 코어 판정 로직을 자동으로 바꾸지 않음
