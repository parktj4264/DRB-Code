# Spotfire DXP 껍데기

사내에서 만든 DXP는 `spotfire/DRB_Analysis.dxp`로 저장합니다. DXP 자동 열기는 실제 Spotfire 경로 동작을 확인한 뒤 추가합니다.

`GENERATE_SPOTFIRE <- TRUE`이면 `output/results.csv` 생성 직후 아래 고정 파일을 모두 이 폴더에 갱신합니다.

- `results.csv`: MSR별 control table
- `raw.csv`: chip 단위 wide raw. 1행은 이름, 2행은 Spotfire 타입이며 `PARTID` 다음 MSR 컬럼은 모두 `Real`
- `rootid.csv`: raw에 REF/TARGET 그룹을 붙이는 `ROOTID`-`GROUP` 매핑
- `goobae.csv`: category, wordline 이름/순서, `MSR`, `GROUP`, `VALUE`를 담은 그룹 평균 long-form table
- `sigma_score_raw.csv`: pair 단위 sigma 고정 스키마 table

권장 DXP table 이름은 `ResultsControl`, `RawWide`, `RootMap`, `GoobaeLong`, `SigmaPairs`입니다. `RawWide.ROOTID`와 `RootMap.ROOTID`를 관계로 연결합니다. `raw.csv`를 처음 연결할 때 Spotfire가 자동 인식하지 않으면 1행을 **Name row**, 2행을 **Type row**로 지정합니다. DXP와 다섯 CSV는 계속 이 폴더에 함께 두며, 이후 실행에서는 CSV만 같은 이름으로 교체합니다.
