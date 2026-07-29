# DRB PowerPoint 공통 템플릿 명세

## 목적

`data/template_16_9.pptx`는 사내 원본 PPT 파일이나 원본의 placeholder
구조에 의존하지 않고, 동일한 디자인을 재현하기 위한 DRB 전용
PowerPoint 템플릿이다.

생성 코드는 템플릿의 샘플 슬라이드를 제거한 뒤 `Title and Content` 또는
`Title Only` 레이아웃으로 새 슬라이드를 추가한다. 구분선, 로고, 하단
고정 문구는 두 레이아웃의 배경 요소이므로 일반 슬라이드 편집 화면에서는
선택되지 않는다. 이 방식은 `officer`로 생성한 PPT에서도 고정 요소를
안정적으로 보존한다.

## 기준 화면

- 화면비: 16:9
- 크기: `33.8667 cm × 19.05 cm`
- PowerPoint/officer 좌표: inch
- 기본 글꼴: 맑은 고딕

## 공통 요소

| 요소 | 위치 및 크기 | 스타일 |
|---|---|---|
| 제목 | 왼쪽 `0.75 cm`, 위 `0.95 cm` | 맑은 고딕 Bold `28 pt` |
| 제목 구분선 | 위 `2.51 cm`, 폭 `32 cm`, 가로 중앙 | 회색 `#B7B7B7`, `0.5 pt`, 그림자 없음 |
| 본문 | 왼쪽 `0.75 cm`, 위 `2.62 cm`, 폭 `32 cm` | 맑은 고딕 Bold `13 pt`, 정보 item 2개 |
| Samsung 로고 | 오른쪽 `0.87 cm`, 위 `1.00 cm`, `3.23 × 0.55 cm` | 공식 Samsung 레터마크 |
| 좌측 하단 문구 | 왼쪽 `1.22 cm`, 아래 `0.55 cm`, `6.80 × 0.55 cm` | 맑은 고딕 `12 pt`, 연한 회색 `#A6A6A6` |
| 소속명 | `7.00 × 0.66 cm`, Confidential 바로 왼쪽 | 맑은 고딕 `12 pt`, 회색, 오른쪽 정렬 |
| Confidential | 오른쪽과 아래 `0.55 cm` | 맑은 고딕 Bold `12 pt`, 연한 빨강 |

좌측 하단 고정 문구는 `함께 성장하는 행복한 메모리사업부`이다.

## 구현상 보정값

사용자 측정으로 직접 확인되지 않은 값은 다음처럼 최소 보정했다.

- Confidential 상자 폭: `3.20 cm`
- 소속명과 Confidential 간격: `0.15 cm`
- 소속명 세로 오프셋: Confidential보다 아래로 `0.08 cm`
- 제목 오른쪽 끝: 로고와 `0.40 cm` 간격 확보
- 제목 상자 높이: `1.35 cm`로 확보해 28 pt 글자 잘림 방지

## 실행 설정

`run.R`의 기본 모드는 다음과 같다.

```r
PPT_LAYOUT_MODE <- "template"
PPT_AFFILIATION <- "Flash PE / 홍길동"
```

- `PPT_LAYOUT_MODE = "template"`: `data/template_16_9.pptx`를 사용한다.
- `PPT_AFFILIATION`: 모든 생성 슬라이드 우측 하단에 들어갈 소속명이다.
- `PPT_LAYOUT_MODE = "dev"`: 템플릿 없이 개발 좌표 오버레이를 사용하는
  비상용 모드다.

## 템플릿 재생성

PowerPoint가 설치된 Windows 환경에서 다음 명령으로 템플릿의 공통
마스터 디자인을 다시 만들 수 있다.

```powershell
.\devtools\build_corporate_template.ps1
```

사내 공식 로고 파일을 사용할 경우:

```powershell
.\devtools\build_corporate_template.ps1 -LogoPath "C:\path\to\samsung_logo.png"
```

빌더는 템플릿 안에 디자인 확인용 샘플 슬라이드 한 장을 둔다. 실제 DRB
PPT 생성 시 이 샘플 슬라이드는 자동으로 제거된다.

## 로고 출처

기본 템플릿의 로고는
[Samsung 공식 Newsroom 로고 자료](https://news.samsung.com/es/imagenes-logotipo-samsung)의
레터마크 이미지를 사용한다.
