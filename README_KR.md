# 반도체 불량 분석 (DRB-Code)

이 R 프로젝트는 대규모 반도체 계측 데이터(~4GB)의 고성능 이상 탐지를 위해 설계되었습니다. 병렬 처리를 사용하여 Reference 그룹과 Target 그룹 간의 **Sigma Score (Glass's Delta)**를 계산합니다.

[🇺🇸 English README](README.md)

## 🚀 실행 방법

1.  **데이터 준비**:
    *   대용량 원시 데이터 파일을 `data/` 폴더에 위치시킵니다 (예: `data/raw.csv`).
    *   매핑 파일을 `data/` 폴더에 위치시킵니다 (예: `data/ROOTID.csv`).
    *   *참고: `ROOTID.csv` 파일은 반드시 `ROOTID`와 `GROUP` 컬럼을 포함해야 합니다.*

2.  **설정 및 실행**:
    *   **`run.R`** 파일을 엽니다.
    *   필요한 경우 파일명(`RAW_FILENAME`, `ROOT_FILENAME`)을 수정합니다.
    *   그룹 기본값(`GROUP_REF_NAME`, `GROUP_TARGET_NAME`)을 설정하거나, 자동 감지를 위해 `NULL`로 둡니다.
    *   스크립트를 실행합니다!

3.  **결과 확인**:
    *   결과는 `output/results.csv`에 저장됩니다 (설정 가능).
    *   결과 컬럼에는 `Mean_<Ref>`, `Mean_<Tgt>`, `SD_<Ref>`, `Sigma_Score`, `Direction` 등이 포함됩니다.

## 📂 프로젝트 구조

```bash
DRB-Code/
├── run.R                # [사용자] 진입점 (Entry point). 여기서 파라미터를 설정합니다.
├── main.R               # [핵심] 조율자 (Orchestrator). 모듈을 로드하고 로직을 실행합니다.
├── data/                # [입력] 입력 CSV 파일들.
├── output/              # [출력] 생성된 결과 CSV 파일들.
└── src/
    ├── 00_libs.R        # 패키지 로더 ("무적 버전")
    ├── 00_utils.R       # 유틸리티 함수 (로깅, 안전한 코어 수 계산)
    ├── 01_load_data.R   # 데이터 수집 (메모리 최적화된 필터링)
    └── 02_calc_sigma.R  # 병렬 Sigma Score 계산
```

## ✨ 주요 기능

*   **⚡ 병렬 처리**: 최대 속도를 위해 `future`와 `data.table`을 사용합니다.
*   **🛡️ 메모리 안전성**: 파일 크기에 따라 코어 사용량을 자동으로 조절합니다.
*   **📊 강력한 필터링**: 무거운 처리 작업을 하기 전에 빠른 `LDS Hot Bin` 필터링을 수행합니다.
*   **📦 스마트한 의존성 관리**: `src/00_libs.R`을 통해 필요한 패키지를 자동으로 설치하고 로드합니다.
