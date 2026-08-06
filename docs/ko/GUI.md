# DRB GUI 사용 및 설계

## 실행

1. RStudio에서 `DRB-Code.Rproj`를 엽니다.
2. `run_gui.R` 전체를 실행합니다.
3. 로컬 브라우저에 `DRB Analysis Studio`가 열리면 옵션을 선택합니다.

GUI는 로컬 Shiny 세션으로 실행됩니다. 입력 데이터와 결과가 외부 서버로 전송되지 않습니다.

## Quick Preview

GUI가 열리면 선택된 Raw와 ROOTID 파일의 헤더·매핑을 자동 검사합니다. 본 데이터는 이 단계에서 읽지 않으며 `Load / Refresh Preview`를 누를 때 처음 읽습니다.

다음 옵션을 바꾼 뒤 `Load / Refresh Preview`를 누르면 대표 composite plot 한 개만 다시 생성합니다.

- 평균선과 평균값 표시 및 평균값 글자 크기
- Radius scatter 이상치 trim 및 IQR 배수
- 상단 Radius scatter, 중단 ROOTID 평균, 하단 CDF/WF Map 높이 비율
- CDF와 WF Map의 가로 비율
- REF/TARGET 컬러 피커와 HEX 색상
- Balance, Scatter, CDF, WF Map 강조 preset

`3. Plot Options`의 `Reset`은 평균 표시·글자 크기, trim, 색상, plot 비율을 모두 기본 PPT 설정으로 복원합니다. `Advanced plot sizing`, `Good-chip limits`, `PPT category settings` 같은 접이식 영역은 ▶/▼ 표시로 열림 상태를 구분합니다.

Preview는 `config/ppt_config.R`을 기반으로 하며 화면에서 선택한 값만 덮어씁니다. 이미지 크기와 DPI도 실제 PPT 상세 plot 슬롯을 계산하는 `calculate_detail_plot_layout()` 결과를 그대로 사용합니다. 따라서 내부 PPT 레이아웃이나 기본 설정 변경도 다음 GUI 실행부터 자동 반영됩니다.

## 입력과 그룹 선택

기본 흐름은 다음과 같습니다.

1. Raw와 ROOTID 파일 선택
2. 자동 검사 결과 확인 또는 `Re-inspect inputs` 실행
3. REF/TARGET 및 대표 MSR 선택
4. `Load / Refresh Preview` 실행

REF와 TARGET은 검색창에서 그룹을 찾은 뒤 오른쪽 `+`로 추가합니다. 선택된 그룹은 별도 목록에 표시되며 각 행의 `×`로 삭제할 수 있습니다. 서로 이미 선택된 그룹은 양쪽 추가 후보에서 제외됩니다. 그룹별 WF 수와 선택된 그룹 수를 바로 확인할 수 있고 `Auto assign`, `Swap REF / TARGET`을 지원합니다.

Preview는 Good-chip 필터 적용 후 Raw와 ROOTID에 모두 존재하는 WF만 사용합니다. 대용량 Raw의 전체 MSR을 메모리에 올리지 않고 현재 선택한 MSR과 `ROOTID`, `LOTID`, `Radius`, `X`, `Y`, Bin 등 plot 필수 컬럼만 유지합니다. 파일·Good-chip 조건·MSR이 같으면 이후 색상과 plot 비율 변경은 메모리 cache를 재사용합니다. MSR을 바꾸면 해당 MSR의 경량 데이터를 다시 읽고 Full Run에서만 전체 MSR을 읽습니다. 좌측 설정 영역은 화면 높이 안에서 독립적으로 스크롤됩니다.

CSV 특성상 MSR을 바꿀 때는 선택 컬럼 수와 무관하게 파일 전체 행을 다시 훑습니다. 수 GB급 Raw에서 여러 MSR을 반복 탐색하는 시간이 문제가 되면, 실제 사내 데이터 benchmark를 기준으로 Raw 파일 크기·수정 시각을 key로 하는 로컬 columnar cache를 다음 단계로 적용합니다. Rev1 GUI는 별도 대용량 임시파일이나 추가 의존성을 자동 생성하지 않습니다.

Rev1의 Quick Preview Radius scatter는 응답성을 위해 Side당 최대 2,000점을 결정론적으로 표시합니다. 실무 PPT는 GUI 전용 상한을 사용하지 않고 trim 후 모든 chip point를 표시합니다. 평균선·평균값·trim 기준은 양쪽 모두 전체 데이터를 사용합니다. CDF는 전체 유효값의 정확한 rank를 계산한 뒤 표시용 knot만 줄입니다. Full PPT 생성시간이 실제 사내 대용량 데이터에서 문제가 되면 raster scatter 또는 밀도 기반 표현을 후속 최적화로 검토합니다.

## Full Run

`Run Full Analysis`는 GUI 전용 계산 코드를 사용하지 않고 별도 실행 환경에 옵션을 넣어 기존 `main.R`을 호출합니다.

- Sigma threshold
- Good-chip Cold → Hot 규칙
- PPT 생성
- Spotfire 데이터 생성 및 DXP 열기
- PPT 제목과 소속명
- Category 순서·범위·Summary/Detail 기준
- Preview에서 확정한 평균선, trim, plot 비율과 색상

버튼을 누르면 바로 실행하지 않고 현재 설정 전체를 확인하는 창을 먼저 표시합니다. `Confirm and Run`을 눌러야 분석을 시작하며 `Cancel`로 돌아가 설정을 수정할 수 있습니다.

PPT 제목과 소속명은 접힌 메뉴가 아니라 좌측 `PPT Report` 영역에 항상 표시됩니다.

실행 로그는 Quick Preview 아래 우측 터미널에 시간순으로 표시되고 새 로그를 자동으로 따라갑니다. 최대 300줄을 유지하며 기존 R 콘솔 로그도 그대로 남습니다.

## 유지보수 원칙

```text
run.R ─────┐
           ├─ main.R 및 기존 분석/PPT 파이프라인
run_gui.R ─┘
```

- 통계, Sigma, PPT 내부 로직 변경은 일반적으로 GUI 수정이 필요하지 않습니다.
- GUI 수정이 필요한 경우는 사용자에게 노출할 새 옵션을 추가하거나 입력 계약을 변경할 때입니다.
- Quick Preview는 `generate_composite_plot_png()`를 공유하므로 최종 상세 plot의 시각화 로직을 복제하지 않습니다.
- GUI는 `run.R`을 수정하거나 임시 R 스크립트를 생성하지 않습니다.

## 제한 및 안전장치

- Full Run 전에 현재 Raw와 ROOTID 파일의 입력 검사가 완료되어야 합니다.
- REF와 TARGET이 비어 있거나 서로 겹치면 실행하지 않습니다.
- ROOTID 파일은 `ROOTID`, `GROUP` 컬럼과 ROOTID별 단일 매핑을 요구합니다.
- Quick Preview는 상세 plot 한 개의 구성 확인용이며 Summary/목차/템플릿 전체 슬라이드 Preview가 아닙니다.
