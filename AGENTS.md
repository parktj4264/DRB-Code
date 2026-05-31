# AGENTS.md

## 목적
- PPT 작업 완료 후, 사용자가 로컬에서 PPT를 직접 열어 확인하지 않아도 되도록 슬라이드 미리보기 이미지를 채팅에 바로 첨부한다.

## PPT 작업 완료 시 필수 후처리
1. 최종 PPTX가 생성되면 아래 PowerShell 명령으로 슬라이드를 PNG로 일괄 export 한다.
2. export된 PNG를 채팅에 첨부해 사용자에게 즉시 미리보기를 제공한다.
3. 기본 출력 폴더는 PPT 파일과 같은 위치의 `preview_chat` 디렉터리로 한다.

## PowerShell 명령 (기본 템플릿)
```powershell
$pptPath = Resolve-Path "output/Sigma_Summary_Latest.pptx"; $outDir = Join-Path (Split-Path $pptPath -Parent) "preview_chat"; New-Item -ItemType Directory -Path $outDir -Force | Out-Null; $pp = New-Object -ComObject PowerPoint.Application; $pres = $pp.Presentations.Open($pptPath.Path, $false, $true, $false); $pres.Export($outDir, "PNG", 1920, 1080); $pres.Close(); $pp.Quit()
```

## 운영 메모
- 실제 산출물 파일명에 맞게 `Resolve-Path` 대상 PPTX 경로를 바꿔 실행한다.
- 미리보기는 기본적으로 전체 슬라이드를 export하고, 채팅에는 전체 또는 핵심 슬라이드를 상황에 맞게 표시한다.
