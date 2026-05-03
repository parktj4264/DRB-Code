# 메트릭 플러그인 표준

## 목표
`src/metrics` 아래에 함수 파일 1개를 추가하는 방식으로 새로운 비교 통계량을 확장한다.

## 파일 명명
- 파일: `metric_<name>.R`
- 함수명: `metric_<name>`

## 지원 시그니처 (Dual-mode)
- 레거시 모드: `metric_<name>(pair_stats)`
- raw-access 모드: `metric_<name>(pair_stats, raw_access)`

## `pair_stats` 컬럼
- `MSR`
- `ref_group`
- `target_group`
- `mean_ref`
- `mean_tgt`
- `sd_ref`
- `sd_tgt`
- `n_ref`
- `n_tgt`

## `raw_access` 헬퍼 (2인자 모드)
- `raw_access$has_pair(msr, ref_group, target_group)` -> 논리값
- `raw_access$get_pair(msr, ref_group, target_group)` -> list(`ref_values`, `tgt_values`)
- `raw_access$get_group_values(msr, group_name)` -> 숫자 벡터

## 출력 표준
- 숫자형 벡터를 반환해야 한다.
- 길이는 정확히 `nrow(pair_stats)`와 같아야 한다.
- 유한하지 않은 값(non-finite)은 처리해야 한다(권장: `0`으로 치환).

## 현재 코어 동작
- `Sigma_Score`, `Abs_Sigma_Score`는 항상 one_sigma 기준이다.
- 방향성(Direction) 및 플래그 판단은 one_sigma 임계값 기준이다.
- 추가 메트릭은 분석용 출력 컬럼으로만 사용된다.

## 예시 (raw-access 모드)
```r
metric_example <- function(pair_stats, raw_access) {
  score <- vapply(seq_len(nrow(pair_stats)), function(i) {
    msr <- as.character(pair_stats$MSR[i])
    ref_group <- as.character(pair_stats$ref_group[i])
    target_group <- as.character(pair_stats$target_group[i])

    if (!raw_access$has_pair(msr, ref_group, target_group)) {
      return(0)
    }

    raw_pair <- raw_access$get_pair(msr, ref_group, target_group)
    ref_values <- as.numeric(raw_pair$ref_values)
    tgt_values <- as.numeric(raw_pair$tgt_values)
    if (length(ref_values) < 2 || length(tgt_values) < 2) {
      return(0)
    }

    out <- mean(tgt_values) - mean(ref_values)
    if (!is.finite(out)) {
      return(0)
    }
    as.numeric(out)
  }, numeric(1))

  score[!is.finite(score)] <- 0
  as.numeric(score)
}
```
