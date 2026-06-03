# AGENTS.md

## Purpose
- Keep PPT workflows fast and reviewable inside chat without forcing local manual opening.

## Default Rule
- Do not show PPT preview images by default.
- Show preview images only when the user explicitly requests a preview.

## PPT Layout Guardrails
- PowerPoint/officer coordinates are in inches. Treat `left`, `top`, `width`, and `height` as inch values, not pixels or centimeters.
- Standard slide size is 16:9 widescreen: `13.33333 in x 7.50000 in`.
- Preserve the corporate template's fixed system placeholders. Do not cover or edit date, footer, or slide number placeholders.
- Use balanced horizontal margins for main content. The corporate benchmark content area starts near `left = 0.9167` and leaves a similar right margin.
- For slides with a title plus 2-3 short bullet lines at about 13 pt, keep the main table/chart content below the bullets.
- Recommended safe main content box:
  - `left = 0.95`
  - `top = 2.45`
  - `width = 11.43`
  - `height = 4.40`
  - `bottom = 6.85`
- This content box leaves room above for the title and short itemized summary, while leaving room below for the corporate footer area.
- If a one-line note is needed below the main content, use about 10 pt text near `top = 7.00` with a height of about `0.25` to `0.30`.
- Keep any bottom note to one concise line unless the user explicitly approves reducing the main content area.

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
