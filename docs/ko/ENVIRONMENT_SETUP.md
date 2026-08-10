# DRB-Code 실행 환경 안내

DRB-Code는 작업 폴더마다 package 환경을 만들지 않습니다. 같은 Windows 사용자와 같은
R minor 버전의 모든 DRB-Code 복사본이 LocalAppData의 한 library를 공유합니다.

```text
%LOCALAPPDATA%/DRB/
├─ R-4.1/
│  └─ library/     # 모든 R 4.1.x DRB-Code 복사본이 공유
└─ R-4.5/
   └─ library/     # 모든 R 4.5.x DRB-Code 복사본이 공유
```

`LOCALAPPDATA`가 비어 있는 예외적인 PC에서는
`%USERPROFILE%/AppData/Local`을 사용합니다. 사용자명이나 R 설치 경로를 하드코딩하지
않으며 관리자 권한도 필요하지 않습니다.

## 사용 방법

### 새 PC 최초 실행

1. Windows용 64-bit R **4.1.x 또는 4.5.x**와 RStudio를 설치합니다.
2. `DRB-Code.Rproj`를 엽니다.
3. `run_gui.R` 또는 `run.R`을 실행합니다.

실행 파일이 다음 순서로 환경을 자동 준비합니다.

```text
현재 R 버전 확인
→ LocalAppData의 DRB shared library 선택 및 생성
→ 필요한 package의 실제 설치 여부 확인
→ 없는 package만 자동 설치
→ GUI 또는 분석 실행
```

첫 실행은 package 다운로드 때문에 수 분 걸릴 수 있습니다. 별도 setup 파일이나 setup
명령은 없습니다. 설치가 실패하면 Console에 남은 package 이름과 설치 오류가 표시됩니다.
사내 proxy 또는 firewall 상태를 확인한 뒤 같은 `run_gui.R` 또는 `run.R`을 다시
실행하면 됩니다.

### 이후 작업 폴더와 새 ZIP

```text
새 물량 폴더 생성
→ 최신 DRB-Code ZIP 압축 해제
→ DRB-Code.Rproj 열기
→ run_gui.R 또는 run.R 실행
```

같은 사용자와 같은 R minor 버전이면 기존 LocalAppData library를 그대로 사용합니다.
필요한 package가 모두 있으면 `install.packages()`를 호출하지 않으므로 새 ZIP마다 package
복사, 링크 또는 재설치가 발생하지 않습니다.

## package 설치 방식

직접 필요한 package 목록은 `src/bootstrap/drb_bootstrap.R` 한 곳에 있습니다. 실행 시
각 package의 다음 파일이 공용 DRB library 안에 실제로 존재하는지 확인합니다.

```text
<DRB library>/<package>/DESCRIPTION
```

없는 package가 있을 때만 다음 방식으로 설치합니다.

```r
install.packages(
  missing_packages,
  lib = drb_library,
  dependencies = TRUE,
  type = "binary"
)
```

지원 환경이 Windows이므로 Rtools가 필요한 source compile 대신 현재 R minor 버전용
Windows binary package를 설치합니다.

별도의 환경 관리 계층은 없으며, 이미 존재하는 package의 버전을 자동으로 변경하거나
다시 설치하지 않습니다.

## 시작 banner와 `drb_env()`

프로젝트를 열면 현재 세션이 사용할 환경을 한 번 표시합니다.

```text
============================================================
 DRB ENVIRONMENT
============================================================
 R       : 4.1.3
 ENV     : DRB-R4.1
 LIBRARY : C:/Users/<user>/AppData/Local/DRB/R-4.1/library
 STATUS  : READY
============================================================
```

최초 설치 전에는 `STATUS : PACKAGES REQUIRED`와 누락된 package 목록이 표시됩니다.
사용자는 별도 명령을 입력하지 않고 `run_gui.R` 또는 `run.R`을 실행하면 됩니다.

Console에서 현재 상태를 다시 확인하려면 다음을 실행합니다.

```r
drb_env()
```

`drb_env()`는 R 버전, 환경 이름, shared library, 상태, 누락 package와 현재
`.libPaths()`를 표시합니다.

## library 검색 경로와 일반 RStudio 세션

DRB 프로젝트 세션은 다음 두 위치만 사용합니다.

1. `%LOCALAPPDATA%/DRB/R-4.1/library` 또는 `R-4.5/library`
2. 현재 R 설치의 base/recommended library

일반 사용자 library에서 우연히 발견한 package로 실행되지 않도록 일반 user/site library는
DRB 세션의 검색 경로에서 제외합니다. 이 설정은 프로젝트의 `.Rprofile` 또는 DRB 실행
파일이 실행된 현재 세션에만 적용됩니다. 다른 RStudio 프로젝트와 사용자의 기존 package
library는 변경하지 않습니다.

## 지원 R 버전

- R 4.1.x → `DRB-R4.1` → `%LOCALAPPDATA%/DRB/R-4.1/library`
- R 4.5.x → `DRB-R4.5` → `%LOCALAPPDATA%/DRB/R-4.5/library`

지원하지 않는 R 버전이나 32-bit R에서는 명확한 오류를 표시하고 실행을 중단합니다.
