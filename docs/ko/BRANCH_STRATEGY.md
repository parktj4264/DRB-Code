# 브랜치 전략

## 브랜치 역할
- `main`: 최종 릴리즈 코드 전용 브랜치.
- `develop`: 통합용 클린 베이스라인 브랜치. 직접 push는 허용하지 않음.
- `feature/<slug>`: 시스템 엔지니어링 및 인프라 작업 브랜치.
- `stats/<slug>`: 신규 통계 로직, 수학적 모델링, 지표 함수 작업 브랜치(one-sigma 관련 변경 포함).
- `exp/<YYMMDD>-<slug>`: 혼합 테스트용 일회성 통합 샌드박스 브랜치.
- `backup/<slug>`: 고위험 구조 변경(예: rebase, 대규모 리팩터링) 전 임시 안전 스냅샷 브랜치.

## 명명 규칙
- 소문자와 하이픈(`-`) 기반 slug를 사용한다.
- `exp/*`는 정리/폐기를 쉽게 하기 위해 날짜 접두어를 사용한다.
- 권장 `feature/*` 패턴: `feature/<domain>-<change>`
- 권장 `stats/*` 패턴: `stats/<metric>-<change>`
- 권장 `exp/*` 패턴: `exp/<YYMMDD>-<test-desc>`
- 권장 `backup/*` 패턴: `backup/<topic>-<YYYYMMDD>`

## 핵심 워크플로우
1. 모든 작업 브랜치(`feature/*`, `stats/*`)는 최신 `develop`에서 생성한다.
2. 통합 테스트가 필요하면 `develop`에서 `exp/*`를 생성한다.
3. 검증 대상 `feature/*`, `stats/*` 브랜치를 `exp/*`에 선택적으로 merge해 샌드박스 검증을 수행한다.
4. `exp/*`를 `develop`으로 merge하지 않는다.
5. 검증 완료 후, 원본 `feature/*` 또는 `stats/*` 브랜치에서 `develop`으로 PR을 생성한다.
6. 확정 릴리즈만 `develop`에서 `main`으로 merge한다.

## 가드레일
- `develop` 보호: 직접 push 금지, PR 필수, CI/테스트 통과 필수.
- `develop`은 항상 릴리즈 가능한 버그 없는 상태를 유지한다.
- `exp/*`는 소모성 브랜치로 취급하여 실험 종료 후 close/delete한다.
- `backup/*`는 임시 보험 브랜치로 취급하여 고위험 작업 완료 후 삭제한다.

## 명령어 템플릿
```bash
# 로컬 develop 동기화
git switch develop
git pull origin develop

# develop에서 작업 브랜치 생성
git switch -c feature/<slug> develop
git switch -c stats/<slug> develop

# develop에서 실험 브랜치 생성
git switch -c exp/<YYMMDD>-<desc> develop

# 실험 브랜치로 후보 작업 브랜치 병합
git switch exp/<YYMMDD>-<desc>
git merge feature/<slug>
git merge stats/<slug>

# exp/*는 develop으로 병합 금지
# 대신 feature/* -> develop 또는 stats/* -> develop PR 생성
```
