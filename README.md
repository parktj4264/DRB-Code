# DRB 분석 자동화 (DRB Analysis) 🚀

Reference와 Target 그룹 간의 Sigma Score (Glass's Delta)를 병렬 처리로 계산하는 R 스크립트입니다.

## 📂 프로젝트 구조 (Project Structure)
```text
DRB-Code/
├── data/              # 분석할 파일(raw.csv, ROOTID.csv)을 여기에 넣어주세요.
├── output/            # 분석 결과가 저장되는 곳입니다.
├── src/               # 소스 코드 모음 (수정 금지)
├── run.R              # [실행용] 사용자는 이 파일만 열어서 실행하면 됩니다.
└── main.R             # 전체 프로세스를 조율하는 파일
```

## 🏃 실행 가이드 (How to Run)

### 1. 준비하기
`data/` 폴더에 아래 두 파일을 넣어주세요.
- **`raw.csv`**: 원본 데이터 (`PARTID` 이후 `MSR`로 취급)
- **`ROOTID.csv`**: `ROOTID`와 `GROUP` 정보가 매핑된 파일

### 2. 실행하기
**⚠️ 반드시 아래 순서대로 실행해주세요!**
1. **`DRB-Code.Rproj`** 파일을 더블 클릭해 RStudio를 실행합니다. (경로 자동 설정을 위해 **필수**)
2. RStudio 내에서 **`run.R`** 파일을 엽니다.
3. 필요하다면 **User Parameters** 수치를 조정합니다. (아래 설명 참고)
4. 전체 코드를 선택(`Ctrl + A`)하고 실행(`Ctrl + Enter`)하거나, `Ctrl + Shift + Enter`를 눌러 한번에 실행합니다.

---

## ⚙️ 설정 안내 (`run.R`)

| 변수명 | 기본값 | 설명 |
| :--- | :--- | :--- |
| **`GOOD_CHIP_LIMIT`** | `130` | `LDS Cold Bin` 값이 이보다 작은 칩만 남깁니다. |
| **`SIGMA_THRESHOLD`** | `0.5` | Up/Down 방향을 정하는 기준입니다. (±0.5 이내면 Stable) |
| **`N_CORES`** | `2` | 사용할 CPU 코어 개수입니다. **메모리 오류 나면 이 숫자를 줄이세요.** |
| **`CHUNK_SIZE`** | `100` | 한 번에 처리할 MSR 묶음 단위입니다. 작을수록 메모리를 덜 씁니다. |

> **참고**: `N_CORES`는 안전하게 `2`로 설정되어 있습니다. 늘려도 되지만, 램(RAM)이 부족하면 멈출 수 있으니 주의하세요!

---

## 📊 결과물 확인 (Outputs)

`output/` 폴더에 두 가지 방식으로 저장됩니다.

1.  **최신 결과 파일** (`output/results.csv`)
    - 방금 돌린 분석 결과가 여기에 덮어씌워집니다.
    - Spotfire 툴에 연결해두면 편합니다.

2.  **히스토리 아카이브** (`output/results_YYMMDD_HHMMSS/`)
    - 실행할 때마다 날짜/시간 이름으로 폴더가 따로 생깁니다.
    - **`results_....csv`**: 당시 분석 데이터 백업
    - **`parameters.txt`**: 분석에 쓴 설정값 기록 (어떤 파일 썼지? Ref 그룹은 뭐였지? 등등 확인용)

---

## ❓ FAQ

**Q: "future.globals.maxSize" 에러가 뜨면서 멈춰요!**
> **해결책**: `run.R`에서 **`N_CORES`** 숫자를 줄이세요.
> 데이터가 크면 코어 2개로 돌리는 게 제일 안전합니다.

**Q: Reference 그룹을 제가 직접 정하고 싶어요.**
> 기본적으로는 알파벳 순서로 자동 감지합니다.
> 수동으로 정하고 싶다면 `run.R`에서 `GROUP_REF_NAME <- "내가원하는그룹명"` 이렇게 적어주면 됩니다.

---

## 🔮 향후 계획 (Future Work)

**1. 다표본 분석 확장 (Multi-sample Analysis)**
- 현재는 2개 그룹(Target vs Ref)만 비교 가능하지만, 앞으로는 3개 이상의 다중 그룹을 비교할 수 있도록 기능을 확장할 예정입니다.

**2. 다양한 통계 지표 개발 (Advanced Verification)**
- Sigma Score 외에도 엔지니어 분석에 도움을 줄 수 있는 통계적 검증 지표를 생각해 볼 계획입니다.
