# 통합 PPT 변경 및 복구 안내

> 파일 경로는 기존 작업 기록과의 연결을 위해 유지하지만, 아래 내용은 단일 통합 PPT 기준이다.

## 기준점

- 통합 PPT 구현 전 기준 커밋: `e184885` (`Split Main and Suggested PPT workflows`)
- `data/template_16_9.pptx`는 이번 변경에서 수정하지 않는다.
- 사용자 작성 방향 문서와 아이디어 메모는 수정하지 않는다.
- 통합 PPT 구현은 별도 Git 커밋으로 묶고, 요청 전에는 원격에 push하지 않는다.

## 출력 계약

| 최신 파일 | 실행별 아카이브 | 내용 |
|---|---|---|
| `output/sigma_summary_latest.pptx` | `output/results_<timestamp>/sigma_summary_<timestamp>.pptx` | Required와 Alarm을 순서대로 담은 단일 통합 PPT |

슬라이드 순서는 다음과 같다.

1. Cover
2. Contents: 실제 슬라이드 번호와 상세 구역의 페이지 범위를 표시
3. `Summary (Required)`: `summary_category_columns` 조합별 대표 MSR을 정확히 한 장에 표시
4. `Summary (Alarm-all)`: finite `|Sigma_Score| > SIGMA_THRESHOLD`인 MSR을 모두 페이지화
5. GOOBAE
6. 카테고리별 상세 쌍: 각 카테고리에서 Required(`SLIDE_REQUIRED_YN`) 다음에 Alarm(Sigma 초과 전체)을 배치하며, 한쪽이 없으면 0 MSR 빈 장표 유지

Required Summary는 각 카테고리 조합에서 `SUMMARY_REQUIRED_YN`이 체크된 MSR이 있으면 그중 `|Sigma|`가 가장 큰 항목을 사용하고, 체크 항목이 없으면 해당 조합 전체에서 `|Sigma|`가 가장 큰 항목을 사용한다.

기존 `PPT_SUGGESTED_ENABLED` 옵션과 `output/sigma_suggested_latest.pptx` 출력은 더 이상 사용하지 않는다.

## 게시 안전성

통합 PPT 아카이브가 정상 생성된 뒤 `output/sigma_summary_latest.pptx` 하나만 원자적으로 교체한다. PowerPoint에서 최신 PPT를 열어둔 상태라 교체할 수 없으면 다음 순서로 처리한다.

1. 열려 있는 `sigma_summary_latest.pptx`를 닫는다.
2. 임시 `.tmp` 또는 `.bak` 파일이 남지 않았는지 확인한다.
3. `run.R`을 다시 실행한다.
4. 계속 실패하면 실행별 아카이브 PPT가 정상인지 먼저 확인한 뒤 아래 수동 복원을 사용한다.

## 산출물만 수동 복원

정상 실행된 이전 아카이브 폴더를 정확히 지정한 뒤 PowerShell에서 실행한다.

```powershell
$archiveDir = Resolve-Path "output/results_YYMMDD_HHMMSS"
Copy-Item -LiteralPath (Join-Path $archiveDir "sigma_summary_YYMMDD_HHMMSS.pptx") -Destination "output/sigma_summary_latest.pptx" -Force
```

`YYMMDD_HHMMSS`는 선택한 폴더와 파일의 실제 timestamp로 바꾼다. 복사 전에 경로와 파일 크기를 확인한다.

## 코드 전체 복구

통합 PPT 구현 커밋만 되돌리는 것을 우선한다. 작업 중인 다른 변경을 지울 수 있는 `git reset --hard`는 사용하지 않는다.

```powershell
git log -5 --oneline
git revert <통합 PPT 구현 커밋>
```

구현 커밋을 만들기 전 로컬 변경 상태에서 파일 단위 복구가 꼭 필요하면 먼저 변경 범위를 확인하고, 기준 커밋 `e184885`와 비교한다.

```powershell
git status -sb
git diff --name-only e184885
git diff e184885 -- src/03_create_ppt.R src/05_finalize_outputs.R run.R config/ppt_config.R
```

다른 사용자 변경과 겹치지 않는 것이 확인된 경우에만 필요한 파일을 기준 커밋에서 복구한다. 전체 작업 폴더를 한 번에 덮어쓰지 않는다.

복구 후 다음 검증을 실행한다.

```powershell
Rscript tests/run_tests.R
```

## 설정 문제별 확인

| 증상 | 확인 사항 |
|---|---|
| Required Summary 대표가 예상과 다름 | `summary_category_columns`, `SUMMARY_REQUIRED_YN`, `Sigma_Score` 확인 |
| Required 상세가 비어 있음 | 범위 안의 `SLIDE_REQUIRED_YN` 값 확인 (`Y`, `YES`, `TRUE`, `1`) |
| Alarm Summary/상세가 비어 있음 | `SIGMA_THRESHOLD`, `Sigma_Score`, `PPT_CATEGORY_SCOPE` 확인 |
| 임계값과 같은 항목이 Alarm에 없음 | 정상 동작이다. Alarm 조건은 `|Sigma_Score| > SIGMA_THRESHOLD`인 엄격 초과이다. |
| 일부 카테고리가 모두 제외됨 | `PPT_CATEGORY_SCOPE` 값의 공백과 정확한 대소문자 확인 |
| Alarm 상세 생성 시간이 김 | `PPT_CATEGORY_SCOPE`로 이번 보고 대상 카테고리만 좁혔는지 확인 |
| `msrinfo.csv` 병합 실패 | 중복 `FIELD`를 제거하고 체크한 FIELD가 raw 분석 MSR에 존재하는지 확인 |

## 검증 기준

- `Rscript tests/run_tests.R` 전체 통과
- 최신 PPT 하나와 실행별 아카이브 하나가 동일 실행에서 생성됨
- `GENERATE_PPT <- FALSE`에서 최신 PPT의 hash와 수정 시각이 유지됨
- Contents의 페이지 번호와 실제 슬라이드 번호가 일치함
- Required Summary가 항목 수와 관계없이 정확히 한 장으로 생성됨
- Alarm-all Summary의 Sigma 초과 MSR이 페이지가 넘어가도 누락되지 않음
- Alarm 상세에 Sigma 초과 Required MSR도 포함됨
- PPT 카테고리 범위는 PPT에만 적용되고 `results.csv`와 Spotfire 데이터는 전체 유지
