# DRB-Code

DRB-Code는 기준 그룹(REF)과 비교 그룹(TARGET)의 측정값 변화를 분석하고, Sigma 결과·검토용 PowerPoint·Spotfire 데이터를 한 번에 생성하는 R 기반 자동화 코드입니다.

## 실행 방법

### 새 PC 최초 실행

```text
DRB-Code.Rproj 열기
→ run_gui.R 또는 run.R 실행
→ 공용 DRB library 생성 및 누락 package 자동 설치
→ GUI 또는 분석 실행
```

### 이후 매번 / 새 물량 폴더의 새 ZIP

```text
DRB-Code.Rproj 열기
→ run_gui.R 실행
```

지원 환경은 **Windows 64bit + R 4.1.x 또는 R 4.5.x + RStudio**입니다. 프로젝트를
열면 R 버전에 맞는 Windows 사용자 전용 공용 DRB library가 자동 선택됩니다. 같은 사용자와
같은 R minor 버전의 모든 DRB-Code 복사본은 `%LOCALAPPDATA%/DRB/R-4.x/library`를
재사용합니다. `run.R`과 `run_gui.R`은 이 위치에 없는 package만 자동 설치하며, 이미
설치된 package는 다시 설치하지 않습니다. 현재 상태는 Console의 environment banner 또는
`drb_env()`로 확인할 수 있습니다. 자세한 최초 설치·오류 대응은
[새 PC 환경 준비](docs/ko/ENVIRONMENT_SETUP.md)를 참고합니다.

일반 사용자는 `data/`에 입력 파일을 넣은 뒤 다음 두 실행 방식 중 하나를 선택할 수 있습니다.

- **GUI 실행:** [`run_gui.R`](run_gui.R)을 실행하고 화면에서 옵션 선택 → Quick Preview → Full Run
- **스크립트 실행:** [`run.R`](run.R)의 파라미터를 수정하고 전체 실행

두 방식 모두 같은 `main.R` 분석 파이프라인을 사용하므로 계산 결과와 최종 출력 로직은 동일합니다.

## 가장 쉬운 실행: `run_gui.R`

1. RStudio에서 [`DRB-Code.Rproj`](DRB-Code.Rproj)를 엽니다.
2. [`run_gui.R`](run_gui.R) 전체를 실행합니다(`Ctrl+A`, `Ctrl+Enter`).
3. 자동 검사된 Raw/ROOTID 파일과 REF·TARGET 자동 배정 결과를 확인합니다.
4. 검색창에서 그룹을 고른 뒤 `+`로 추가하고, 선택된 그룹의 `×`로 삭제하거나 `Swap REF / TARGET`으로 조정합니다.
5. `Load / Refresh Preview`로 대표 MSR 한 개를 확인하고 `Run Full Analysis`를 실행합니다.

GUI 시작 시에는 필요한 package를 공용 DRB library에서 확인하고, 없는 package만 자동 설치한 뒤 헤더·ROOTID 매핑을 가볍게 검사합니다. Preview는 전체 MSR을 올리지 않고 선택한 MSR과 plot 필수 컬럼만 읽으며, 이후 평균값 글자 크기·색상·plot 크기 등 시각화 옵션 변경에서는 메모리 cache를 재사용합니다. Plot Options는 `Reset`으로 기본값을 복원할 수 있습니다. MSR을 바꾸면 해당 MSR용 경량 데이터를 다시 읽고, Full Run에서만 전체 MSR을 읽습니다.

GUI는 분석 코드를 별도로 복제하지 않습니다. Full Run은 기존 [`main.R`](main.R)을 그대로 호출하고, Quick Preview도 최종 PPT에서 사용하는 composite plot 함수를 공유합니다. 세부 사용법은 [GUI 사용 및 설계](docs/ko/GUI.md)를 참고합니다.

## 재현 가능한 스크립트 실행: `run.R`

1. RStudio에서 [`DRB-Code.Rproj`](DRB-Code.Rproj)를 열어 프로젝트를 시작합니다.
2. `data/`에 `raw.csv`, `ROOTID.csv`와 필요한 선택 파일을 넣습니다.
3. `run.R`의 세 구역만 확인합니다.
4. `run.R` 전체를 실행합니다(`Ctrl+A`, `Ctrl+Enter`).

### 1. DRB Analysis

| 파라미터 | 기본값 | 역할 |
|---|---:|---|
| `RAW_FILENAME` | `"raw.csv"` | `data/`에서 읽을 원본 측정 데이터 파일명 |
| `ROOT_FILENAME` | `"ROOTID.csv"` | `ROOTID`별 그룹 매핑 파일명 |
| `GOOD_CHIP_RULE_HOT` | `< 130` | Hot Bin의 Good-chip 조건 함수 |
| `GOOD_CHIP_RULE_COLD` | `< 130` 또는 `790~800 미만` | Cold Bin의 Good-chip 조건 함수 |
| `GROUP_REF_NAME` | `NULL` | REF 그룹 지정. `NULL`이면 자동 선택하며 여러 그룹은 `c(...)`로 지정 |
| `GROUP_TARGET_NAME` | `NULL` | TARGET 그룹 지정. `NULL`이면 자동 선택하며 여러 그룹은 `c(...)`로 지정 |
| `SIGMA_THRESHOLD` | `0.5` | Up/Down 및 Alarm 판정에 사용할 `one_sigma` 기준값 |

그룹을 직접 지정하려면 다음처럼 작성합니다.

```r
GROUP_REF_NAME    <- "Reference_A"
GROUP_TARGET_NAME <- c("Target_B", "Target_C")
```

### 2. Output Controls

| 파라미터 | 기본값 | 역할 |
|---|---:|---|
| `GENERATE_SPOTFIRE` | `TRUE` | `spotfire/`의 연동 CSV를 최신 결과로 덮어쓰기 |
| `OPEN_SPOTFIRE` | `TRUE` | 데이터 생성 후 `spotfire/drb_spotfire.dxp` 열기 요청 |
| `GENERATE_PPT` | `TRUE` | 최신 통합 PPT 생성 여부 |

`OPEN_SPOTFIRE`는 DXP를 단순히 여는 기능입니다. DXP 파일이나 연결 프로그램이 없으면 경고만 남기며, 분석과 PPT 생성은 계속됩니다. DXP 내부 데이터 경로는 사내 환경에서 연결합니다.

### 3. PPT Presentation

| 파라미터 | 기본값 | 역할 |
|---|---:|---|
| `PPT_SLIDE_TITLE` | 보고서 제목 | 모든 슬라이드의 공통 제목 |
| `PPT_AFFILIATION` | `"Flash PE / 홍길동"` | 우측 하단 소속명·작성자 |
| `PPT_SCATTER_TRIM_IQR` | `6` | Radius scatter의 극단 이상치 표시 제거. `FALSE`면 해제 |
| `PPT_SCATTER_SHOW_MEAN` | `TRUE` | 그룹별 평균선과 평균값 표시 |
| `PPT_CATEGORY_SCOPE` | `NULL` | PPT에 포함할 Category 범위. `NULL`이면 전체 |
| `PPT_CATEGORY_ORDER_FILE` | `"cateinfo.csv"` | PPT Category 순서 파일. 파일이 없거나 `NULL`이면 자동 정렬 |
| `PPT_DETAIL_GROUP_BY` | `"Category2"` | 상세 슬라이드를 묶는 Category 단계 |
| `PPT_SUMMARY_GROUP_BY` | `Category1~3` | Summary 표에서 사용할 Category 계층 |

일부 Category만 PPT에 포함하려면 다음처럼 작성합니다. 이 설정은 PPT에만 적용되며 `results.csv`와 Spotfire 데이터는 전체를 유지합니다.

```r
PPT_CATEGORY_SCOPE <- list(
  Category1 = "PERI",
  Category2 = c("PB", "BL")
)
```

PPT는 [`data/template_16_9.pptx`](data/template_16_9.pptx)를 자동으로 사용하므로 별도의 레이아웃 모드를 설정할 필요가 없습니다.

## 앞으로 할 일

- 현재 REF 1개와 TARGET 1개의 1:1 비교 Plot을 다수 REF와 다수 TARGET을 함께 비교하는 다:다 구조로 확장합니다.

## 상세 기술 문서

- [전체 프로젝트 코드 골격 설명서 (HTML)](docs/ko/PROJECT_CODE_ARCHITECTURE.html)
- [전체 설정 및 내부 동작](docs/ko/README.md)
- [메트릭 확장 규격](docs/ko/METRIC_CONTRACT.md)
- [PPT 템플릿 디자인 명세](docs/ko/PPT_TEMPLATE_DESIGN.md)
- [통합 PPT 변경·복구 안내](docs/ko/PPT_MAIN_SUGGESTED_ROLLBACK.md)
- [브랜치 운영 전략](docs/ko/BRANCH_STRATEGY.md)

일반적인 실행에서는 `run.R`만 수정하고, `config/`와 `src/`는 고급 설정 또는 코드 확장이 필요한 경우에만 확인합니다.

## Appendix A. 입력 데이터

모든 입력 파일은 `data/`에 둡니다.

| 파일 | 구분 | 역할 |
|---|---|---|
| `raw.csv` 또는 지정한 CSV | 필수 | Chip 단위 원본 측정값 |
| `ROOTID.csv` | 필수 | Wafer/ROOTID를 REF·TARGET 그룹에 연결 |
| `msrinfo.csv` | 선택 | MSR 이름, Category, Required 항목, 구배 정보를 연결 |
| `cateinfo.csv` | 선택 | PPT Category 출력 순서를 행 순서대로 지정 |

### Raw 데이터 주요 컬럼

| 컬럼 | 역할 |
|---|---|
| `ROOTID` | `ROOTID.csv`와 연결되는 Wafer 식별자 |
| `LOTID`, `WF`, `Chip` | Lot·Wafer·Chip 식별 정보 |
| `X`, `Y` | WFMAP 좌표 |
| `Radius`, `EDGE` | Radius scatter 및 위치 분석용 정보 |
| `LDS Cold Bin`, `LDS Hot Bin` | `run.R`의 Good-chip 조건에 사용. Cold를 우선하고 값이 없으면 Hot을 사용 |
| `PARTID` | 메타데이터와 MSR 측정 컬럼의 경계 |
| `PARTID` 다음 컬럼들 | `msrinfo.csv`가 없을 때만 사용하는 MSR fallback 범위 |

`msrinfo.csv`가 있으면 `FIELD`와 Raw 헤더의 교집합만 MSR로 분석합니다. 파일이 없으면 `PARTID` 다음 컬럼을 사용합니다. `PARTID` 앞의 컬럼은 분석 메타데이터로 보존되며, WFMAP이나 Radius scatter를 사용하려면 해당 좌표 컬럼이 원본 데이터에 있어야 합니다. MSR이 문자형으로 읽히더라도 숫자 문자열이면 double로 변환하고, 숫자가 아닌 값이 있으면 컬럼명과 예시값을 표시하고 중단합니다.

Good-chip 필터는 `run.R`에서 수동 설정합니다. 현재 조건은 Cold가 `< 130` 또는 `790 이상 800 미만`, Hot이 `< 130`입니다. Cold와 Hot이 모두 `NA`이면 해당 행은 good chip으로 유지됩니다.

### `ROOTID.csv`

| 컬럼 | 역할 |
|---|---|
| `ROOTID` | Raw 데이터와 연결할 식별자 |
| `GROUP` | REF/TARGET 선택에 사용할 그룹명 |

Raw와 `ROOTID.csv` 양쪽에 존재하는 `ROOTID`만 분석에 포함됩니다.

### `msrinfo.csv`

| 컬럼 | 역할 |
|---|---|
| `FIELD` | Raw의 MSR 컬럼명과 연결되는 키 |
| `ITEM_NAME`, `ITEM_GROUP_ID`, `ITEM_ID` 등 | 결과표와 PPT에 표시할 MSR 정보 |
| `SPEC_TYPE` | 방향 속성: `U`(망소), `D`(망대), `N`(망목), 또는 공란 |
| `Category1`~`Category5` | Summary·목차·상세 슬라이드 분류 계층 |
| `SLIDE_REQUIRED_YN` | Required 상세 PPT에 반드시 포함할 MSR |
| `SUMMARY_REQUIRED_YN` | Required Summary 대표 항목 후보 |
| `GOOBAE_Category1`, `GOOBAE_Category2` | 구배 표·그래프의 분류 |
| `GOOBAE_NAME`, `GOOBAE_ORDER` | Wordline 표시명과 출력 순서 |

Required 컬럼은 `Y`, `YES`, `TRUE`, `1`을 체크값으로 인식합니다.

### `cateinfo.csv`

`Category1`부터 `Category5`까지 작성하고 원하는 순서대로 행을 배치합니다. 파일에 없는 실제 Category는 제거하지 않고 지정된 항목 뒤에 자동으로 추가됩니다.

## Appendix B. 출력 데이터

### `output/`: 최신 분석 결과와 PPT

| 파일 | 역할 |
|---|---|
| `results.csv` | MSR별 최신 통계·Sigma·Category 결과 |
| `metric_issues_latest.csv` | 메트릭 계산 이슈 요약. 이슈가 없으면 헤더만 존재 |
| `sigma_summary_latest.pptx` | 보고용 최신 통합 PPT |
| `results_<timestamp>/` | 실행 당시 CSV·파라미터·PPT를 보관하는 로컬 이력 |

`results.csv`의 핵심 컬럼은 다음과 같습니다.

| 컬럼 | 역할 |
|---|---|
| `MSR` | 측정 항목명 |
| `Mean_<GROUP>`, `SD_<GROUP>` | 그룹별 평균과 표준편차 |
| `N_valid_<GROUP>` | MSR별 유효 측정값 개수 |
| `metric_one_sigma`, `abs_metric_one_sigma` | 기본 Sigma 메트릭과 절댓값 |
| `Sigma_Score`, `Abs_Sigma_Score` | 최종 판단에 사용하는 Sigma 결과 |
| `Direction` | `Up`, `Down`, `Stable` 판정 |
| Category·Required·GOOBAE 컬럼 | `msrinfo.csv`에서 연결된 검토 정보 |

통합 PPT는 `Cover → Contents → Required Summary → Alarm-all Summary → GOOBAE → Category별 Required/Alarm 상세` 순서로 생성됩니다.

### `spotfire/`: Spotfire 연동 데이터

| 파일 | 역할 |
|---|---|
| `drb_spotfire.dxp` | 사내에서 세부 대시보드를 구성할 Spotfire 껍데기 |
| `results.csv` | MSR marking과 선택에 사용할 control table |
| `<raw 파일명>_spotfire.csv` | Chip 단위 원본. 두 번째 행에 Spotfire 타입 정보를 추가하고 MSR을 `Real`로 고정 |
| `rootid.csv` | `ROOTID`와 `GROUP` 매핑 |
| `goobae.csv` | Wordline 순서·MSR·GROUP·평균값을 담은 long-form 구배 데이터 |
| `sigma_score_raw.csv` | MSR별 그룹 평균·표준편차·개수·Sigma의 고정 스키마 데이터 |

Spotfire 데이터는 `GENERATE_SPOTFIRE <- TRUE`일 때마다 같은 파일명으로 갱신됩니다. 대용량 Raw는 원본 경로·크기·수정 시각이 같으면 불필요한 재복사를 건너뜁니다.
