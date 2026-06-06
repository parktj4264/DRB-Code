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
- Recommended safe main content box for the 2x4 detail plot/table slides:
  - `left = 0.32`
  - `top = 1.68`
  - `width = 12.69`
  - `height = 5.32`
  - `bottom = 7.00`
- Detail plot/table slides use 8 logical plot slots arranged as 2x4. The editable background table is split into 5x4 visual rows: row 1 is a merged darker-gray header row, rows 2 and 4 are light-gray MSR-label rows, and rows 3 and 5 are plot rows.
- The 2x4 MSR/plot body starts at `top = 2.00` and runs to `bottom = 7.00`; the merged header row above it has height `0.32`.
- Final detail-table row heights are: merged header row `0.32`, MSR-label rows `0.28`, and plot rows `2.22`.
- Final detail plot image box is about `width = 3.0925` and `height = 2.18` inside each plot row.
- Use 10 pt text for the merged header row and 9 pt text for editable MSR-label text boxes.
- Detail slides use a custom small header above the plot/table area: title near `left = 0.50`, `top = 0.26`, about 20 pt; itemized text starts near `top = 0.74`, about 11 pt.
- Use the large square `■` (`\u25A0`) bullet style for corporate itemized lines. Keep the title plus 2-3 itemized lines above `top = 1.68`.
- PPT template behavior is selected lightly in `run.R` with `PPT_LAYOUT_MODE`.
  - `dev`: force the current development header coordinates above.
  - `template`: write title/itemized text into the attached PPT template placeholders first, falling back to development coordinates only when placeholders are unavailable.
- For actual corporate templates, keep `run.R` simple and inspect the template before changing internal placeholder/layout defaults.
- This content box leaves room above for the title and short itemized summary, while leaving room below for the corporate footer area.
- The expanded 2x4 detail plot/table box should not also carry a bottom note.
- If a one-line note is needed below the main content, reduce the main content area first, then use about 10 pt text near `top = 7.00` with a height of about `0.25` to `0.30`.

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
