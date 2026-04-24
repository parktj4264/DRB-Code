# 메트릭 플러그인 표준

## 목표
`src/metrics` 아래에 함수 파일 1개를 추가하는 방식으로 새로운 비교 통계량을 확장한다.

## 파일 명명
- 파일: `metric_<name>.R`
- 함수: `metric_<name>(pair_dt)`

## `pair_dt` 필수 입력 컬럼
- `MSR`
- `mean_ref`
- `mean_tgt`
- `sd_ref`
- `sd_tgt`
- `n_ref`
- `n_tgt`

## 출력 표준
- 숫자형 벡터를 반환해야 한다.
- 길이는 정확히 `nrow(pair_dt)`와 같아야 한다.
- 유한하지 않은 값(non-finite)은 처리해야 한다(권장: `0`으로 치환).

## 현재 코어 동작
- `Sigma_Score`, `Abs_Sigma_Score`는 항상 one_sigma 기준이다.
- 방향성(Direction) 및 플래그 판단은 one_sigma 임계값 기준이다.
- 추가 메트릭은 분석용 출력 컬럼으로만 사용된다.

## 예시
```r
metric_example <- function(pair_dt) {
  score <- (pair_dt$mean_tgt - pair_dt$mean_ref) / pair_dt$sd_ref
  score[!is.finite(score)] <- 0
  as.numeric(score)
}
```
