# DRB 코드

* Reference와 Target 그룹 간의 Sigma Score (Glass's Delta)를 계산하는 R 스크립트입니다. 심플하게 단일 코어로 작동하며, 결과는 절댓값(Abs Sigma Score) 기준으로 내림차순 정렬됩니다.
* 이 코드는 DRB 업무에 데이터 분석 엔지니어의 판단을 돕는 용도로 직관적인 Sigma Score (Glass's Delta) Effect Size 통계량을 활용합니다.

## 📂 프로젝트 구조 (Project Structure)
```text
DRB-Code/
├── data/              # 분석할 파일(raw.csv, ROOTID.csv)을 여기에 넣어주세요. ☆
├── output/            # 분석 결과가 저장되는 곳입니다.
├── src/               # 소스 코드 모음 (수정 금지)
├── run.R              # [실행용] 사용자는 이 파일만 열어서 실행하면 됩니다. ☆
└── main.R             # 전체 프로세스를 조율하는 파일
```

## 🏃 실행 가이드 (How to Run)

### 1. 준비하기
`data/` 폴더에 아래 두 파일을 넣어주세요.
- **`raw.csv`**: 원본 데이터 (`PARTID` 이후 `MSR`로 취급)
- **`ROOTID.csv`**: `ROOTID`와 `GROUP` 정보가 매핑된 파일

### 2. 실행하기
1. **`DRB-Code.Rproj`** 파일을 더블 클릭해 RStudio 실행.
2. **`run.R`** 파일을 열기.
3. 필요한 설정값 조정.
4. 전체 코드 선택(`Ctrl + A`) 후 실행(`Ctrl + Enter`).
끝입니다.

---

## ⚙️ 설정 안내 (`run.R`)

| 변수명 | 기본값 | 설명 |
| :--- | :--- | :--- |
| **`GOOD_CHIP_LIMIT`** | `130` | `LDS Cold Bin` 값이 이보다 작은 칩만 남깁니다. |
| **`SIGMA_THRESHOLD`** | `1.0` | Up/Down 방향을 정하는 기준입니다. (±1.0 이내면 Stable, =1sigma) |
| **`GROUP_REF_NAME`** | `NULL` | Ref 그룹명. `c("A", "B")` 처럼 여러 개 입력 가능합니다. |
| **`GROUP_TARGET_NAME`** | `NULL` | Target 그룹명. `c("C", "D")` 처럼 여러 개 입력 가능합니다. |

> **참고**: `LDS Cold Bin`이 없으면 `LDS Hot Bin`을 대신 사용합니다.

---

## 📊 결과물 확인 (Outputs)

`output/` 폴더에 저장됩니다.

1.  **`results.csv`**
    - 방금 돌린 최신 결과입니다. 스팟파이어 연결용으로 쓰세요.

2.  **`results_{Timestamp}/`**
    - 실행할 때마다 생기는 백업 폴더입니다.
    - `sigma_score_{raw파일명}_{Timestamp}.csv`: 당시 데이터 결과 파일
    - `parameters_{Timestamp}.txt`: 사용된 파라미터 정보

---

## 📈 결과 해석 (Interpretation)

**주요 컬럼 설명**

| 컬럼명 | 설명 | 비고 |
| :--- | :--- | :--- |
| **`MSR`** | 비교 MSR 항목 | - |
| **`Mean_{그룹}`** | 해당 그룹 평균 | - |
| **`SD_{그룹}`** | 해당 그룹 표준편차 | - |
| **`Sigma_Score`** | 두 그룹 간의 차이 (Glass's Delta) | 다중 그룹일 경우, 절댓값이 최대인 조합의 점수 |
| **`Abs_Sigma_Score`** | Sigma Score의 절댓값 | **이 값이 큰 순서대로 정렬됩니다.** |
| **`Direction`** | 방향성 (Up / Down / Stable) | Threshold 기준 |

> **다중 그룹 설정 시 (`run.R`에서 벡터 입력)**
> - 모든 Ref vs Target 조합에 대한 Score가 별도 컬럼으로 추가됩니다.
> - 메인 `Sigma_Score`는 그 조합들 중 **가장 변화가 큰(절댓값 최대)** 값으로 채워집니다.

---

## ❓ FAQ

**Q: Reference 그룹을 제가 직접 정하고 싶어요.**
> 기본적으로는 알파벳 순서입니다.
> 바꾸고 싶으면 `run.R`에서 `GROUP_REF_NAME <- "원하는이름"` 넣으면 됩니다.
> 그룹이 여러 개면 `c("Ref1", "Ref2")` 형식으로 넣으세요.

---

## 🔮 향후 계획

**1. 추가 통계 지표**
- 엔지니어에게 유용한 다른 지표들도 넣어볼 생각입니다.
