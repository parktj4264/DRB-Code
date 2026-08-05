안녕!!! 드디어 방향을 최종적으로 다음과같이 정했다!!!

[최종 PPT 방향]

1. PPT는 하나로 통합한다
2. PPT는 다음과 같은 순서다
    (1) 여기에는 맨 처음에는 제목 장표를 쓰자
        제목은 "DRB Auto PPT Output" 이런느낌 (더 좋은거 있으면 너가 추천좀)
        내용은 여러 파라미터와 로그 등을 써주자 (코드식으로 쓰지 말구, `걸린시간:`, `매수: `이런느낌 ㅇㅋ?) 카테고리별로 몇MSR가 필수고 몇 MSR가 Alarm인지도 있으면 좋을 듯
    (2) 목차
        여기서는 목차를 써주자 그럼 Summary 쩜쩜쩜 3 (페이지) 이런느낌 구배 쩜쩜쩜 몇페이지 그다음 Slide는 Category별로 몇페이지에 있는지 써줘야겠제?
    (3) 그 다음 기존 Summary -> 구배 -> Slide 이렇게 가자
3. 그다음 우리가 고민했었던 옵션으로 필수항목/알람항목 체크해서 막 했었잖아! 이 옵션은 역시 없어도 될듯
    3-1. 포맷은 다음과 같이 통일하면 될듯: 카테고리별로 `Category2: WTC - MSR 1-2 of 2` 이렇게 쓰는 칸 있잖아?
    이걸 다음과 같이 해줘: `WTC (Required)` / `WTC (Alarm)` 즉 `Required` 가 8개로 딱 안 나눠줘도 다 하면 페이지로 넘겨서 Alarm을 따로 빼주면 될 듯 + 추가로  (Required) (Alarm) 이거 이 글짜만 색깔로 구분 지으면 될 것 같다
    3-2. 그리고 슬라이드에 itemize해서 내용 2개 썼잖아?? 
        `Category: Category2: WTC | Showing MSR 1-2 of 2` 이걸 
        `Category: WTC (Required)| Showing MSR 1-2 of 2` 이런식으로 MSR 관련 정보는 여기 쓰면 좋을 듯. 2번쨰는 너 판단하에 쓰면 좋을 정보
    3-3. 아 맞다 Summary는 이것도 Summary (Requried) / Summary (Alarm-all) 이걸 나누구, (Requried)는 최대한 무조건 꾸겨서라도 한 페이지에 해야함. itemize1에 Summary (Requried) / Summary (Alarm-all) 이걸 쓰구, itemzie2에는 `TREND: plot 수동 부착 / 비고: 수동 작성` 이거 씁시다

**최대한 쓸데없는 코드 스파게티로 만들지말구 최대한 이쁘게해주라**


[추가수정사항 및 계획]
* 평균 값 크기 좀 더 크게 하면 좋을 듯
* msrinfo csv SPEC_TYPE에서 U가 망소, D가 망대, N이 망목 잘 되어 있지?
* 헷갈리지 않게, msrinfo csv는 필요 없는건 곧 빼야할듯 (지금 바로는 아니구)
* 추가로 이제 거의 배포 직전이니, spotfire 연동까지 하구 나서 korean readme 다듬어야할듯 (run.R외 옵션만 설명 잘 해줘도 댐 + msrinfo csv)
* 남은건 이제, 가상환경 + spotfire + readme가 끝이다 ㄹㅇ

---

<!-- CODEX IMPLEMENTATION STATUS START: 이 아래는 Codex가 작성했습니다. -->

## 🤖 Codex 구현 기록 (2026-08-05)

> 위 구분선 위의 사용자 원문은 수정하지 않았습니다. 이 구역부터는 구현 결과와 다음 작업을 구분하기 위해 Codex가 작성했습니다.

### 이번에 완료한 구현

- PPT를 **한 파일**로 통합했습니다. 생성 순서는 `Cover → Contents → Summary (Required) → Summary (Alarm-all) → GOOBAE → 카테고리별 Required/Alarm 상세 쌍`입니다.
- Cover 제목은 `DRB Automated Analysis Report`로 정했습니다. 분석 시각·분석 소요시간·총 매수·분석 MSR·Required/Alarm 수·비교 그룹·Sigma 기준·카테고리 범위·입력 파일과 카테고리별 Required/Alarm MSR 수를 사람이 읽는 표 형태로 넣었습니다.
- Contents는 렌더링에 사용하는 동일한 slide plan에서 계산하므로 실제 페이지 번호와 카테고리별 페이지 범위가 일치합니다. 페이지 계획과 실제 렌더 장수가 다르면 저장 전에 오류로 중단합니다.
- `Summary (Required)`는 `summary_category_columns` 조합별 대표 MSR을 표시하며, 항목 수와 관계없이 정확히 한 장에 맞춥니다. 체크 MSR이 있으면 체크된 항목 중 최대 `|Sigma|`, 없으면 해당 카테고리 조합 전체의 최대 `|Sigma|`를 사용합니다.
- `Summary (Alarm-all)`은 finite `abs(Sigma_Score) > SIGMA_THRESHOLD`인 MSR을 모두 표시하고 15행 단위로 페이지를 넘깁니다. Required와 겹치는 MSR도 제외하지 않습니다.
- 두 Summary의 item 2는 `TREND: plot 수동 부착 / 비고: 수동 작성`으로 통일했습니다.
- 상세 장표는 카테고리별로 `WTC (Required) → WTC (Alarm) → 다음 카테고리` 순서입니다. 한쪽이 없더라도 `Showing MSR 0 of 0` 빈 장표를 남겨 쌍을 유지합니다. 상태 접미사만 파랑/빨강으로 표시하고, item 1에는 현재 MSR 범위를, item 2에는 REF/TARGET/Sigma 기준을 표시합니다.
- Contents의 제목·점선·페이지 번호 폭을 줄여 중앙에 모으고, 상위 구역은 굵게 표시해 가독성을 높였습니다.
- `data/cateinfo.csv`의 `Category1`~`Category5` 행 순서를 Summary·표지 집계·Contents·상세 카테고리 쌍에 공통 적용하도록 추가했습니다. `run.R`의 `PPT_CATEGORY_ORDER_FILE`이 `NULL`이거나 파일이 없으면 자동 순서로 복귀하며, 파일에 없는 신규 카테고리는 누락시키지 않고 뒤에 붙입니다.
- Required와 Alarm이 겹치는 MSR은 양쪽 상세 장표에 모두 포함하되, 같은 실행 안에서는 plot/WFMAP 캐시를 공유하여 같은 MSR 이미지를 다시 계산하지 않습니다.
- 공개 PPT 출력은 `output/sigma_summary_latest.pptx`와 실행별 `sigma_summary_<timestamp>.pptx` 하나씩만 생성합니다. 기존 별도 Suggested 옵션과 공개 최신 Suggested PPT는 제거했습니다.
- scatter 평균 숫자 크기를 `2.3`으로 키웠고 기존 글자 halo 정렬 방식은 유지했습니다. 표시는 소수 둘째 자리까지입니다.
- `msrinfo.csv`의 `SPEC_TYPE`은 공백 제거와 대문자 정규화 후 `U=망소`, `D=망대`, `N=망목`만 허용합니다. 다른 값은 조용히 잘못 계산하지 않고 즉시 오류로 알려줍니다.
- Spotfire의 `sigma_score_raw.csv`에도 `SPEC_TYPE`과 `SPEC_TYPE_KO`를 추가했습니다. 현재 `U/D/N`과 `망소/망대/망목`이 함께 출력됩니다.
- `OPEN_SPOTFIRE`를 추가해 CSV 생성 단계 직후 고정 파일 `spotfire/drb_spotfire.dxp`를 단순 오픈할 수 있게 했습니다. DXP가 없거나 연결 프로그램 오류가 있어도 전체 분석은 계속하며, DXP 내부 절대경로 데이터 링크는 변경하지 않습니다.
- `run.R`의 긴 `PPT_CONFIG <- list(...)` 중계 항목을 제거하고, 화면에 보이는 `PPT_*` 사용자 값은 내부 설정으로 자동 매핑했습니다. `PPT_CONFIG`에는 구조를 정하는 `detail_group_by`와 `summary_category_columns`만 남겼습니다.
- `run.R`을 DRB 필수 분석·출력 기능·PPT 표현의 세 구역으로 정리하고, 고정 사내 템플릿을 쓰는 `PPT_LAYOUT_MODE`는 사용자 화면에서 숨겼습니다.
- 통합 Required 상세용 빠른 preview 도구와 통합 PPT·목차·엄격한 Sigma 기준·SPEC_TYPE 계약 회귀 테스트를 함께 갱신했습니다.

### 검증 결과

- `Rscript tests/run_tests.R`: 전체 테스트 통과
- `Rscript run.R`: 정상 완료, 이번 시뮬레이션 데이터 기준 약 26초
- 최종 통합본: 16장(0 MSR 빈 장표 1장 포함), Required Summary 12 MSR / Required 상세 8 MSR / Alarm-all 17 MSR / Alarm 상세 17 MSR
- PowerPoint PNG 재렌더: 16/16장 성공
- 슬라이드 경계 검사: 밖으로 나간 shape 0개

### 다음 구현 순서

1. **Spotfire 연결 마무리**: DXP 파일과 단순 open 흐름은 연결했습니다. 사내 Spotfire에서 고정 CSV 다섯 개의 실제 데이터 링크·refresh 동작만 검증합니다. `spotfire/drb_spotfire.dxp` 내용 자체는 수정하지 않았습니다.
2. **가상환경/배포 묶음**: 사내 PC에서 같은 R·패키지 버전으로 재현되도록 설치 및 실행 절차를 고정합니다.
3. **한글 README 최종 정리**: Spotfire 동작이 확정된 뒤 `run.R` 사용자 옵션과 `msrinfo.csv` 필드 의미를 중심으로 실무용 설명서를 다듬습니다.
4. **msrinfo 컬럼 정리**: 지금은 컬럼을 제거하지 않았습니다. 실제 사용처를 먼저 확인한 뒤 미사용 컬럼만 별도 변경으로 제거합니다.

### 복구 기준

- 통합 PPT 구현 전 기준 커밋은 `e184885`입니다.
- 상세 복구 절차는 `docs/ko/PPT_MAIN_SUGGESTED_ROLLBACK.md`에 기록했습니다. 구현 커밋을 만든 뒤에는 `git revert <통합 PPT 구현 커밋>` 방식으로 이 변경만 되돌리는 것을 기본으로 합니다.
- `cateinfo.csv` 순서 옵션 변경은 사용자가 커밋을 요청하기 전까지 로컬 변경으로 유지합니다.

<!-- CODEX IMPLEMENTATION STATUS END -->
