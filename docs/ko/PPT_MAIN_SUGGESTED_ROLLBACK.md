# Main/Suggested PPT 변경 및 복구 안내

## 기준점

- 구현 전 기준 커밋: `d6131aa` (`Simplify output and Spotfire exports`)
- `data/template_16_9.pptx`는 이번 변경에서 수정하지 않는다.
- 아이디어 원본 `20260804_practical_workflow_ideas.md`도 수정하거나 커밋하지 않는다.
- 이번 구현은 하나의 로컬 Git 커밋으로 묶고 원격에는 자동으로 push하지 않는다.

## 출력 계약

| 구분 | 최신 파일 | 실행별 아카이브 | 내용 |
|---|---|---|---|
| Main | `output/sigma_summary_latest.pptx` | `sigma_summary_<timestamp>.pptx` | 카테고리별 대표 Summary와 `SLIDE_REQUIRED_YN` 상세 |
| Suggested | `output/sigma_suggested_latest.pptx` | `sigma_suggested_<timestamp>.pptx` | Sigma 초과 전체 Summary와 Sigma 초과 상세 |

Main Summary는 `summary_category_columns` 조합마다 대표 MSR 한 개를 선택한다. `SUMMARY_REQUIRED_YN`이 체크된 MSR이 있으면 그중 `|Sigma|`가 가장 큰 MSR을 사용하고, 체크가 없으면 해당 카테고리 전체에서 `|Sigma|`가 가장 큰 MSR을 사용한다.

Suggested Summary는 지정된 PPT 카테고리 범위 안에서 Sigma를 초과한 MSR을 카테고리별로 전부 페이지화한다. Suggested 상세는 Main 상세에 이미 포함된 MSR도 의도적으로 포함한다.

## 게시 안전성

Main과 Suggested 아카이브가 모두 정상 생성된 뒤 최신 파일 두 개를 함께 교체한다. 최신 파일 게시 중 하나가 실패하면 이전 최신 파일들을 복원하도록 구성한다.

PowerPoint에서 최신 PPT를 열어둔 상태라 교체할 수 없으면 다음 순서로 처리한다.

1. 열려 있는 Main/Suggested PPT를 닫는다.
2. 임시 `.tmp` 또는 `.bak` 파일이 남지 않았는지 확인한다.
3. `run.R`을 다시 실행한다.
4. 계속 실패하면 실행별 아카이브 PPT가 정상인지 먼저 확인한 뒤 아래 수동 복원을 사용한다.

## 산출물만 수동 복원

정상 실행된 이전 아카이브 폴더를 정확히 지정한 뒤 PowerShell에서 실행한다.

```powershell
$archiveDir = Resolve-Path "output/results_YYMMDD_HHMMSS"
Copy-Item -LiteralPath (Join-Path $archiveDir "sigma_summary_YYMMDD_HHMMSS.pptx") -Destination "output/sigma_summary_latest.pptx" -Force
Copy-Item -LiteralPath (Join-Path $archiveDir "sigma_suggested_YYMMDD_HHMMSS.pptx") -Destination "output/sigma_suggested_latest.pptx" -Force
```

`YYMMDD_HHMMSS`는 선택한 폴더와 파일의 실제 timestamp로 바꾼다. 복사 전에 경로와 파일 크기를 확인한다.

## 코드 전체 복구

이번 구현 커밋만 되돌리는 것을 우선한다. 작업 중인 다른 변경을 지울 수 있는 `git reset --hard`는 사용하지 않는다.

```powershell
git log -5 --oneline
git revert <Main/Suggested PPT 구현 커밋>
```

revert 후 다음 검증을 실행한다.

```powershell
Rscript tests/run_tests.R
```

구현 커밋을 아직 공유하지 않았고 폐기해도 되는지 확실하지 않다면 파일을 임의로 restore하지 말고, 먼저 `git status -sb`와 `git diff --name-only`로 범위를 확인한다.

## 설정 문제별 확인

| 증상 | 확인 사항 |
|---|---|
| Main Summary 대표가 예상과 다름 | `summary_category_columns`, `SUMMARY_REQUIRED_YN`, `Sigma_Score` 확인 |
| Main 상세가 비어 있음 | 범위 안의 `SLIDE_REQUIRED_YN` 값 확인 (`Y`, `YES`, `TRUE`, `1`) |
| Suggested가 비어 있음 | `SIGMA_THRESHOLD`, `Direction`, `PPT_CATEGORY_SCOPE` 확인 |
| 일부 카테고리가 모두 제외됨 | `PPT_CATEGORY_SCOPE` 값의 공백과 정확한 대소문자 확인 |
| Suggested 생성 시간이 김 | `PPT_CATEGORY_SCOPE`로 이번 보고 대상 카테고리만 좁혔는지 확인 |
| `msrinfo.csv` 병합 실패 | 중복 `FIELD`를 제거하고 체크한 FIELD가 raw 분석 MSR에 존재하는지 확인 |

## 검증 기준

- `Rscript tests/run_tests.R` 전체 통과
- Main/Suggested 두 PPT가 같은 실행 timestamp로 아카이브됨
- `GENERATE_PPT <- FALSE`에서 두 최신 PPT의 hash와 수정 시각이 유지됨
- Suggested Summary의 Sigma 초과 MSR이 페이지가 넘어가도 누락되지 않음
- Suggested 상세에 Sigma 초과 Main MSR도 포함됨
- PPT 카테고리 범위는 PPT에만 적용되고 `results.csv`와 Spotfire 데이터는 전체 유지
