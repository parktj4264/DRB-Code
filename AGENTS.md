# AGENTS.md

## Purpose
- Keep PPT workflows fast and reviewable inside chat without forcing local manual opening.

## Default Rule
- Do not show PPT preview images by default.
- Show preview images only when the user explicitly requests a preview.

## On-Demand PPT Preview Flow
1. When the user asks for a preview, export slides from the final PPTX to PNG.
2. Attach exported PNG slides in chat (all slides or key slides based on request).
3. Use `output/.preview_chat` as the default output directory.

## PowerShell Command (Base Template)
```powershell
$pptPath = Resolve-Path "output/Sigma_Summary_Latest.pptx"; $outDir = Join-Path (Split-Path $pptPath -Parent) ".preview_chat"; New-Item -ItemType Directory -Path $outDir -Force | Out-Null; attrib +h $outDir; $pp = New-Object -ComObject PowerPoint.Application; $pres = $pp.Presentations.Open($pptPath.Path, $false, $true, $false); $pres.Export($outDir, "PNG", 1920, 1080); $pres.Close(); $pp.Quit()
```

## Notes
- Update the `Resolve-Path` target to match the actual final PPTX filename.
- If the user requests full preview, attach all exported slides in order.
- If the user requests a quick check, attach representative key slides.
