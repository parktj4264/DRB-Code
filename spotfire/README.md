# Spotfire DXP 껍데기

사내에서 만든 DXP는 `spotfire/drb_spotfire.dxp`로 저장합니다.

`GENERATE_SPOTFIRE <- TRUE`이면 `output/results.csv` 생성 직후 아래 고정 파일을 모두 이 폴더에 갱신합니다.

- `results.csv`: MSR별 control table
- `<raw 파일명>_spotfire.csv`: Spotfire 전용 chip 단위 wide raw. 예: `raw.csv` → `raw_spotfire.csv`, `data_wow.csv` → `data_wow_spotfire.csv`. 1행은 이름, 2행은 Spotfire 타입이며 `PARTID` 다음 MSR 컬럼은 모두 `Real`
- `rootid.csv`: raw에 REF/TARGET 그룹을 붙이는 `ROOTID`-`GROUP` 매핑
- `goobae.csv`: category, wordline 이름/순서, `MSR`, `GROUP`, `VALUE`를 담은 그룹 평균 long-form table
- `sigma_score_raw.csv`: pair 단위 sigma 고정 스키마 table

권장 DXP table 이름은 `ResultsControl`, `RawWide`, `RootMap`, `GoobaeLong`, `SigmaPairs`입니다. `RawWide.ROOTID`와 `RootMap.ROOTID`를 관계로 연결합니다. `<raw 파일명>_spotfire.csv`를 처음 연결할 때 Spotfire가 자동 인식하지 않으면 1행을 **Name row**, 2행을 **Type row**로 지정합니다. DXP와 다섯 CSV는 계속 이 폴더에 함께 두며, 이후 실행에서는 CSV만 같은 이름으로 교체합니다.

`OPEN_SPOTFIRE <- TRUE`이면 CSV 생성 단계 직후 이 DXP를 운영체제 기본 연결 프로그램으로 열고, R 코드는 PPT 생성을 계속합니다. 이 기능은 DXP를 수정하거나 내부의 절대경로 데이터 연결을 자동으로 바꾸지 않습니다. 파일이 없거나 Spotfire 연결 프로그램이 없으면 경고만 남기고 분석은 중단하지 않습니다.
