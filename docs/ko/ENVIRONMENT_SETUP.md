# DRB-Code 실행 환경 안내

이 프로젝트는 `renv`로 R 패키지 버전을 lockfile에 고정합니다. 각자 RStudio에
이미 설치된 패키지를 그대로 쓰지 않고, 프로젝트 전용 라이브러리를 사용하므로
모두 같은 검증된 패키지 조합으로 실행합니다. R 4.1.x와 R 4.5.x는 서로 별도의
`renv` profile과 lockfile을 사용합니다.

## Conda와 비교하기

| Conda | DRB-Code의 RStudio + renv |
|---|---|
| `conda activate drb` | `DRB-Code.Rproj` 열기 |
| `drb` 환경 | 이 프로젝트의 `renv/` 라이브러리 |
| `environment.yml` | R 버전별 `renv/profiles/*/renv.lock` |
| `conda env create -f environment.yml` | `source("00_setup_environment.R")` |
| `conda list` | `renv::status()` |

`DRB-Code.Rproj`를 열면 프로젝트 최상위의 `.Rprofile`이 실행되고, 현재 R 버전에
맞는 `renv` profile이 자동 활성화됩니다. 콘솔에 예를 들어
`[DRB-Code · R 4.1.3 · renv profile r-4.1 active]`가 표시되면 맞는 환경입니다.
별도의 `activate` 명령은 필요 없습니다.

## 새 PC에서 최초 한 번

1. Windows용 R **4.1.x 또는 4.5.x**와 RStudio를 설치합니다. 사내 표준이
   R 4.1.3이면 그대로 사용하면 됩니다.
2. 프로젝트 전체를 내려받고 `DRB-Code.Rproj`를 엽니다.
3. RStudio Console에서 다음을 한 번 실행합니다.

   ```r
   source("00_setup_environment.R")
   ```

4. 설치가 끝나면 RStudio를 다시 열고 `run_gui.R` 전체를 실행합니다.

첫 설치에는 사내망에서 Posit Package Manager의 날짜 고정 package snapshot 다운로드가
가능해야 합니다. 이 저장소는 lockfile과 함께 Windows binary 패키지 조합을 보존하므로
R 4.1/4.5 각각에서 source compile 없이 복원할 수 있습니다. 설치가 실패하면 사내
프록시/방화벽 설정을 먼저 확인하고 같은 setup 파일을 다시 실행합니다.

## 평소 실행

1. 항상 `DRB-Code.Rproj`를 먼저 엽니다.
2. `run_gui.R`를 실행합니다.

패키지 설치 명령은 평소 실행 스크립트에 없습니다. 필요한 패키지가 없다는 오류가
나면 `00_setup_environment.R`을 다시 실행하면 됩니다. 지원하지 않는 R 4.2~4.4
또는 R 5.x는 R 4.1.3 혹은 R 4.5.x로 바꾼 뒤 실행합니다.

## 개발자가 패키지를 바꿨을 때

패키지를 추가·업데이트하고 정상 동작을 확인한 뒤에만 다음을 실행합니다.

```r
renv::snapshot()
```

현재 활성화한 R 버전에 해당하는 profile lockfile 변경을 코드와 함께 커밋합니다.
일반 사용자는 `snapshot()`을 실행하지 않고, 최신 프로젝트를 받은 뒤 setup 파일만
다시 실행합니다.
