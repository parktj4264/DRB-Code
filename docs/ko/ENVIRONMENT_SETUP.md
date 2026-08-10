# DRB-Code 실행 환경 안내

DRB-Code는 작업 폴더와 R 패키지 환경의 수명을 분리합니다. 같은 Windows 사용자와
같은 R minor 버전으로 실행하는 모든 DRB-Code 복사본은 한 개의 공용 DRB library를
사용합니다.

```text
%LOCALAPPDATA%/DRB/
├─ R-4.1/
│  ├─ library/          # 모든 R 4.1.x DRB-Code 복사본이 재사용
│  └─ lock_hash.txt
└─ R-4.5/
   ├─ library/          # 모든 R 4.5.x DRB-Code 복사본이 재사용
   └─ lock_hash.txt
```

`LOCALAPPDATA`가 비어 있는 예외적인 PC에서는
`%USERPROFILE%/AppData/Local`을 사용합니다. 사용자명이나 R 설치 경로를 코드에
하드코딩하지 않으며, 관리자 권한과 `C:/Program Files/R/...` 쓰기 권한은 필요하지
않습니다.

## 사용자가 기억할 것

### 새 PC에서 최초 한 번

1. Windows용 64-bit R **4.1.x 또는 4.5.x**와 RStudio를 설치합니다.
2. `DRB-Code.Rproj`를 엽니다.
3. Console banner가 `SETUP REQUIRED`라고 표시되면 다음 한 줄을 실행합니다.

   ```r
   source("00_setup_environment.R")
   ```

4. `STATUS : READY`를 확인한 뒤 `run_gui.R`을 실행합니다.

첫 setup만 lockfile의 Windows package를 내려받기 때문에 수 분 걸릴 수 있습니다.
Console의 `[1/4]`부터 `[4/4]`까지 진행 단계를 확인하고 완료될 때까지 RStudio를
닫지 않습니다. 사내 proxy 또는 firewall로 다운로드가 실패하면 오류에 표시된 단계와
원인을 확인한 뒤 같은 setup 파일을 다시 실행합니다.

### 이후 작업 폴더와 새 ZIP

```text
새 물량 폴더 생성
→ 최신 DRB-Code ZIP 압축 해제
→ DRB-Code.Rproj 열기
→ STATUS : READY 확인
→ run_gui.R 실행
```

새 복사본의 lockfile hash가 설치된 hash와 같으면 restore와 전체 package version
검사를 수행하지 않고 필수 package 파일의 존재만 빠르게 확인합니다. 새 폴더 아래에
`renv/library`를 만들지 않고 이미 존재하는 LocalAppData의 library를 바로 사용하므로
package cache에서 수십 개 package를 다시 copy/link하지 않습니다.

## 시작 banner와 `drb_env()`

프로젝트를 열면 현재 세션에서 선택된 환경을 한 번 표시합니다.

```text
============================================================
 DRB ENVIRONMENT
============================================================
 R       : 4.1.3
 ENV     : DRB-R4.1
 LIBRARY : C:/Users/<user>/AppData/Local/DRB/R-4.1/library
 LOCK    : MATCHED
 STATUS  : READY
============================================================
```

언제든 Console에서 다음을 실행하면 lockfile 경로와 전체 `.libPaths()`까지 다시 볼 수
있습니다.

```r
drb_env()
```

상태 의미는 다음과 같습니다.

| LOCK / STATUS | 의미 | 조치 |
|---|---|---|
| `NOT INSTALLED / SETUP REQUIRED` | 이 R minor용 환경을 아직 설치하지 않음 | setup 한 번 실행 |
| `CHANGED / UPDATE REQUIRED` | 새 ZIP의 lockfile이 설치된 환경과 다름 | setup 한 번 실행 |
| `MATCHED / REPAIR REQUIRED` | hash는 같지만 필수 package 파일이 손상·삭제됨 | setup 다시 실행 |
| `MATCHED / READY` | 현재 lockfile과 공용 환경이 일치함 | 바로 실행 |

## 재현성과 library 검색 경로

DRB 프로젝트 세션은 다음 두 위치만 검색합니다.

1. `%LOCALAPPDATA%/DRB/R-4.1/library` 또는 `R-4.5/library`
2. 현재 R 설치에 포함된 base/recommended library

일반 사용자 library와 site library는 DRB 세션의 `.libPaths()`에서 제외합니다.
따라서 우연히 일반 library에 설치된 package 때문에 DRB가 성공하지 않습니다. 이 변경은
프로젝트의 `.Rprofile`이 실행된 현재 R 세션에만 적용되며, 일반 RStudio 프로젝트와
사용자의 기존 package library를 수정하지 않습니다.

## lockfile이 바뀐 경우

R 4.1과 R 4.5는 각각 다음 lockfile을 사용합니다.

- `renv/profiles/r-4.1/renv.lock`
- `renv/profiles/r-4.5/renv.lock`

프로젝트를 열 때 lockfile의 MD5 fingerprint와 LocalAppData의 `lock_hash.txt`만 먼저
비교합니다. 같으면 restore를 호출하지 않습니다. 다르면 banner에 `UPDATE REQUIRED`가
표시되며 setup 실행 시에만 다음 작업을 합니다.

1. 변경·삭제 대상 package만 같은 LocalAppData 환경 안의 rollback 폴더로 잠시 이동
2. 현재 RStudio의 package 상태와 분리된 `Rscript --vanilla` 프로세스에서 명시적인
   `lockfile`과 공용 `library`를 대상으로 `renv::restore()` 실행
3. 공용 library 안의 실제 `DESCRIPTION` 파일로 모든 locked package version과
   필수 runtime package 검증
4. 성공한 뒤에만 `lock_hash.txt` 갱신

package 설치는 회사 PC의 staging-folder rename 문제를 피하도록 staged install과
transactional restore를 사용하지 않습니다. 대신 변경 대상의 기존 package만 별도로
보관했다가 restore 또는 검증이 실패하면 되돌립니다. 실패한 경우 기존 hash를 갱신하지
않으므로 다음 setup에서 안전하게 다시 시도할 수 있습니다.

두 RStudio 세션에서 같은 R minor 환경을 동시에 update하지 않도록 setup lock도
사용합니다. 다른 setup이 진행 중이라는 메시지가 나오면 먼저 실행한 setup이 끝난 뒤
다시 실행합니다.

## project-local renv를 사용하지 않음

배포본의 `renv.lock`은 package version 명세일 뿐입니다. `.Rprofile`은
`renv/activate.R`을 실행하지 않으며 다음 경로를 package library로 생성하거나
활성화하지 않습니다.

```text
<project>/renv/library
<project>/renv/profiles/.../renv/library
```

환경 관리 package는 setup 내부 구현으로만 공용 DRB library에 설치됩니다. 일반
사용자는 `renv`, restore, cache, profile 또는 `.libPaths()`를 알 필요가 없습니다.

## 개발자가 package 버전을 바꿀 때

일반 사용자는 이 절차를 실행하지 않습니다. 개발자는 변경할 R minor 환경에서
`drb_env()`로 target을 확인한 뒤 공용 DRB library에 package를 설치하고, 동일한
library와 해당 profile lockfile을 명시해 snapshot합니다.

```r
env <- drb_env()

renv::snapshot(
  project = env$project_dir,
  library = env$library,
  lockfile = env$lockfile,
  prompt = FALSE
)
```

R 4.1용과 R 4.5용 lockfile을 각각 해당 R 버전에서 검증한 뒤 코드와 함께 배포합니다.
