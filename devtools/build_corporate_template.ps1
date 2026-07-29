param(
    [string]$TemplatePath = "data/template_16_9.pptx",
    [string]$SourceTemplatePath = "",
    [string]$LogoPath = ""
)

$ErrorActionPreference = "Stop"

function Convert-CmToPoint {
    param([double]$Centimeters)
    return $Centimeters * 72.0 / 2.54
}

function Get-OleColor {
    param(
        [int]$Red,
        [int]$Green,
        [int]$Blue
    )
    return [System.Drawing.ColorTranslator]::ToOle(
        [System.Drawing.Color]::FromArgb($Red, $Green, $Blue)
    )
}

function Set-TextBoxStyle {
    param(
        $Shape,
        [string]$FontName,
        [double]$FontSize,
        [int]$Color,
        [bool]$Bold,
        [int]$Alignment
    )

    $Shape.TextFrame.MarginLeft = 0
    $Shape.TextFrame.MarginRight = 0
    $Shape.TextFrame.MarginTop = 0
    $Shape.TextFrame.MarginBottom = 0
    $Shape.TextFrame.WordWrap = 0
    $Shape.TextFrame.AutoSize = 0
    $Shape.TextFrame.VerticalAnchor = 3
    $Shape.TextFrame.TextRange.Font.Name = $FontName
    $Shape.TextFrame.TextRange.Font.NameFarEast = $FontName
    $Shape.TextFrame.TextRange.Font.Size = $FontSize
    $Shape.TextFrame.TextRange.Font.Bold = if ($Bold) { -1 } else { 0 }
    $Shape.TextFrame.TextRange.Font.Color.RGB = $Color
    $Shape.TextFrame.TextRange.ParagraphFormat.Alignment = $Alignment
}

function Set-ShapeGeometry {
    param(
        $Shape,
        [double]$Left,
        [double]$Top,
        [double]$Width,
        [double]$Height
    )

    $Shape.Left = $Left
    $Shape.Top = $Top
    $Shape.Width = $Width
    $Shape.Height = $Height
}

function Add-CorporateChrome {
    param(
        $Container,
        [double]$SlideWidth,
        [double]$SlideHeight,
        [string]$CroppedLogoPath
    )

    $lineWidth = Convert-CmToPoint 32
    $lineLeft = ($SlideWidth - $lineWidth) / 2
    $divider = $Container.Shapes.AddLine(
        $lineLeft,
        (Convert-CmToPoint 2.51),
        ($lineLeft + $lineWidth),
        (Convert-CmToPoint 2.51)
    )
    $divider.Name = "DRB_Divider"
    $divider.Line.ForeColor.RGB = Get-OleColor 183 183 183
    $divider.Line.Weight = 0.5
    $divider.Shadow.Visible = 0

    $logoWidth = Convert-CmToPoint 3.23
    $logoHeight = Convert-CmToPoint 0.55
    $logo = $Container.Shapes.AddPicture(
        $CroppedLogoPath,
        $false,
        $true,
        ($SlideWidth - (Convert-CmToPoint 0.87) - $logoWidth),
        (Convert-CmToPoint 1.0),
        $logoWidth,
        $logoHeight
    )
    $logo.Name = "DRB_Samsung_Logo"

    $footerColor = Get-OleColor 166 166 166
    $lightRed = Get-OleColor 225 125 125

    $footerLeft = Convert-CmToPoint 1.22
    $footerTop = (
        $SlideHeight -
        (Convert-CmToPoint 0.55) -
        (Convert-CmToPoint 0.55)
    )
    $footerWidth = Convert-CmToPoint 6.8
    $footerHeight = Convert-CmToPoint 0.55
    $footerMessage = $Container.Shapes.AddTextbox(
        1,
        $footerLeft,
        $footerTop,
        $footerWidth,
        $footerHeight
    )
    $footerMessage.Name = "DRB_Footer_Message"
    $footerMessage.TextFrame.TextRange.Text = "함께 성장하는 행복한 메모리사업부"
    Set-TextBoxStyle $footerMessage "맑은 고딕" 12 $footerColor $false 1
    Set-ShapeGeometry `
        $footerMessage `
        $footerLeft `
        $footerTop `
        $footerWidth `
        $footerHeight

    $confidentialWidth = Convert-CmToPoint 3.2
    $confidentialHeight = Convert-CmToPoint 0.66
    $confidentialLeft = (
        $SlideWidth -
        (Convert-CmToPoint 0.55) -
        $confidentialWidth
    )
    $confidentialTop = (
        $SlideHeight -
        (Convert-CmToPoint 0.55) -
        $confidentialHeight
    )
    $confidential = $Container.Shapes.AddTextbox(
        1,
        $confidentialLeft,
        $confidentialTop,
        $confidentialWidth,
        $confidentialHeight
    )
    $confidential.Name = "DRB_Confidential"
    $confidential.TextFrame.TextRange.Text = "Confidential"
    Set-TextBoxStyle $confidential "맑은 고딕" 12 $lightRed $true 3
    Set-ShapeGeometry `
        $confidential `
        $confidentialLeft `
        $confidentialTop `
        $confidentialWidth `
        $confidentialHeight
}

function Find-Layout {
    param(
        $Presentation,
        [string]$Name
    )

    foreach ($layout in $Presentation.SlideMaster.CustomLayouts) {
        if ($layout.Name -eq $Name) {
            return $layout
        }
    }
    throw "PowerPoint layout not found: $Name"
}

function Find-Placeholder {
    param(
        $Layout,
        [int[]]$Types
    )

    foreach ($shape in $Layout.Shapes.Placeholders) {
        if ($Types -contains [int]$shape.PlaceholderFormat.Type) {
            return $shape
        }
    }
    return $null
}

$corporateChromeNames = @(
    "DRB_Divider",
    "DRB_Samsung_Logo",
    "DRB_Footer_Message",
    "DRB_Confidential"
)

$templateTarget = [System.IO.Path]::GetFullPath(
    (Join-Path (Get-Location) $TemplatePath)
)
$templateSource = if ([string]::IsNullOrWhiteSpace($SourceTemplatePath)) {
    $templateTarget
} else {
    [System.IO.Path]::GetFullPath(
        (Join-Path (Get-Location) $SourceTemplatePath)
    )
}

if (-not (Test-Path -LiteralPath $templateSource)) {
    throw "Template source does not exist: $templateSource"
}

$temporaryFiles = New-Object System.Collections.Generic.List[string]
$powerPoint = $null
$presentation = $null

try {
    Add-Type -AssemblyName System.Drawing

    $resolvedLogoPath = if ([string]::IsNullOrWhiteSpace($LogoPath)) {
        $downloadPath = Join-Path (
            [System.IO.Path]::GetTempPath()
        ) ("drb_samsung_logo_" + [System.IO.Path]::GetRandomFileName() + ".jpg")
        Invoke-WebRequest `
            -Uri "https://img.global.news.samsung.com/es/wp-content/uploads/2017/12/Lettermark-Samsung-01.jpg" `
            -OutFile $downloadPath
        $temporaryFiles.Add($downloadPath)
        $downloadPath
    } else {
        [System.IO.Path]::GetFullPath(
            (Join-Path (Get-Location) $LogoPath)
        )
    }

    if (-not (Test-Path -LiteralPath $resolvedLogoPath)) {
        throw "Logo file does not exist: $resolvedLogoPath"
    }

    $sourceBitmap = [System.Drawing.Bitmap]::FromFile($resolvedLogoPath)
    try {
        $cropLeft = [int][Math]::Round($sourceBitmap.Width * 0.235)
        $cropTop = [int][Math]::Round($sourceBitmap.Height * 0.18)
        $cropWidth = $sourceBitmap.Width - (2 * $cropLeft)
        $cropHeight = $sourceBitmap.Height - (2 * $cropTop)
        $croppedBitmap = New-Object System.Drawing.Bitmap(
            $cropWidth,
            $cropHeight
        )
        try {
            $graphics = [System.Drawing.Graphics]::FromImage($croppedBitmap)
            try {
                $graphics.Clear([System.Drawing.Color]::White)
                $sourceRect = New-Object System.Drawing.Rectangle(
                    $cropLeft,
                    $cropTop,
                    $cropWidth,
                    $cropHeight
                )
                $targetRect = New-Object System.Drawing.Rectangle(
                    0,
                    0,
                    $cropWidth,
                    $cropHeight
                )
                $graphics.DrawImage(
                    $sourceBitmap,
                    $targetRect,
                    $sourceRect,
                    [System.Drawing.GraphicsUnit]::Pixel
                )
            } finally {
                $graphics.Dispose()
            }

            $croppedLogoPath = Join-Path (
                [System.IO.Path]::GetTempPath()
            ) ("drb_samsung_logo_crop_" + [System.IO.Path]::GetRandomFileName() + ".png")
            $croppedBitmap.Save(
                $croppedLogoPath,
                [System.Drawing.Imaging.ImageFormat]::Png
            )
            $temporaryFiles.Add($croppedLogoPath)
        } finally {
            $croppedBitmap.Dispose()
        }
    } finally {
        $sourceBitmap.Dispose()
    }

    $powerPoint = New-Object -ComObject PowerPoint.Application
    $presentation = $powerPoint.Presentations.Open(
        $templateSource,
        $false,
        $false,
        $false
    )

    for ($index = $presentation.Slides.Count; $index -ge 1; $index--) {
        $presentation.Slides.Item($index).Delete()
    }

    $master = $presentation.SlideMaster
    for ($index = $master.Shapes.Count; $index -ge 1; $index--) {
        $shape = $master.Shapes.Item($index)
        if ($corporateChromeNames -contains $shape.Name) {
            $shape.Delete()
        }
    }

    $slideWidth = [double]$presentation.PageSetup.SlideWidth
    $slideHeight = [double]$presentation.PageSetup.SlideHeight

    $titleLeft = Convert-CmToPoint 0.75
    $titleTop = Convert-CmToPoint 0.95
    $titleWidth = $slideWidth - (
        (Convert-CmToPoint 0.75) +
        (Convert-CmToPoint 0.87) +
        (Convert-CmToPoint 3.23) +
        (Convert-CmToPoint 0.4)
    )
    $titleHeight = Convert-CmToPoint 1.35
    $bodyLeft = Convert-CmToPoint 0.75
    $bodyTop = Convert-CmToPoint 2.62
    $bodyWidth = Convert-CmToPoint 32
    $bodyHeight = Convert-CmToPoint 1.62

    $layouts = @(
        (Find-Layout $presentation "Title and Content"),
        (Find-Layout $presentation "Title Only")
    )

    foreach ($layout in $layouts) {
        for ($index = $layout.Shapes.Count; $index -ge 1; $index--) {
            $shape = $layout.Shapes.Item($index)
            if ($corporateChromeNames -contains $shape.Name) {
                $shape.Delete()
            }
        }
        Add-CorporateChrome `
            $layout `
            $slideWidth `
            $slideHeight `
            $croppedLogoPath

        $titlePlaceholder = Find-Placeholder $layout @(1, 3)
        if ($null -eq $titlePlaceholder) {
            throw "Title placeholder missing from layout: $($layout.Name)"
        }
        $titlePlaceholder.Name = "DRB_Title_Placeholder"
        $titlePlaceholder.Left = $titleLeft
        $titlePlaceholder.Top = $titleTop
        $titlePlaceholder.Width = $titleWidth
        $titlePlaceholder.Height = $titleHeight
        $titlePlaceholder.TextFrame.TextRange.Text = "슬라이드 제목"
        Set-TextBoxStyle $titlePlaceholder "맑은 고딕" 28 (
            Get-OleColor 17 17 17
        ) $true 1
        Set-ShapeGeometry `
            $titlePlaceholder `
            $titleLeft `
            $titleTop `
            $titleWidth `
            $titleHeight

        $bodyPlaceholder = Find-Placeholder $layout @(2, 7)
        if ($null -eq $bodyPlaceholder) {
            $bodyPlaceholder = $layout.Shapes.AddPlaceholder(
                7,
                $bodyLeft,
                $bodyTop,
                $bodyWidth,
                $bodyHeight
            )
        }
        $bodyPlaceholder.Name = "DRB_Body_Placeholder"
        $bodyPlaceholder.Left = $bodyLeft
        $bodyPlaceholder.Top = $bodyTop
        $bodyPlaceholder.Width = $bodyWidth
        $bodyPlaceholder.Height = $bodyHeight
        $bodyPlaceholder.TextFrame.TextRange.Text = "■ 본문"
        $bodyPlaceholder.TextFrame.TextRange.ParagraphFormat.Bullet.Visible = 0
        Set-TextBoxStyle $bodyPlaceholder "맑은 고딕" 13 (
            Get-OleColor 51 51 51
        ) $true 1
        Set-ShapeGeometry `
            $bodyPlaceholder `
            $bodyLeft `
            $bodyTop `
            $bodyWidth `
            $bodyHeight
    }

    $sampleLayout = Find-Layout $presentation "Title and Content"
    $sampleSlide = $presentation.Slides.AddSlide(1, $sampleLayout)
    $sampleTitle = Find-Placeholder $sampleSlide @(1, 3)
    $sampleBody = Find-Placeholder $sampleSlide @(2, 7)
    $sampleTitle.TextFrame.TextRange.Text = "[DM] Data Review Board Auto Report"
    $sampleBody.TextFrame.TextRange.Text = (
        "■ REF: Reference / TARGET: Target | Threshold: 0.5`r" +
        "■ Category: Sample | Showing MSR 1-8 of 8"
    )
    $sampleBody.TextFrame.TextRange.ParagraphFormat.Bullet.Visible = 0

    $gray = Get-OleColor 127 127 127
    $confidentialWidth = Convert-CmToPoint 3.2
    $affiliationWidth = Convert-CmToPoint 7
    $affiliationLeft = (
        $slideWidth -
        (Convert-CmToPoint 0.55) -
        $confidentialWidth -
        (Convert-CmToPoint 0.15) -
        $affiliationWidth
    )
    $affiliationTop = (
        $slideHeight -
        (Convert-CmToPoint 0.55) -
        (Convert-CmToPoint 0.66) +
        (Convert-CmToPoint 0.08)
    )
    $affiliationHeight = Convert-CmToPoint 0.66
    $affiliation = $sampleSlide.Shapes.AddTextbox(
        1,
        $affiliationLeft,
        $affiliationTop,
        $affiliationWidth,
        $affiliationHeight
    )
    $affiliation.Name = "DRB_Affiliation_Sample"
    $affiliation.TextFrame.TextRange.Text = "Flash PE / 홍길동"
    Set-TextBoxStyle $affiliation "맑은 고딕" 12 $gray $false 3
    Set-ShapeGeometry `
        $affiliation `
        $affiliationLeft `
        $affiliationTop `
        $affiliationWidth `
        $affiliationHeight

    $sourceNote = (
        "[Sources]`r" +
        "- https://news.samsung.com/es/imagenes-logotipo-samsung " +
        "(Samsung official newsroom wordmark asset)`r" +
        "- Corporate layout measurements supplied by the user`r" +
        "[/Sources]"
    )
    foreach ($noteShape in $sampleSlide.NotesPage.Shapes.Placeholders) {
        if ([int]$noteShape.PlaceholderFormat.Type -eq 2) {
            $noteShape.TextFrame.TextRange.Text = $sourceNote
            break
        }
    }

    $targetDirectory = Split-Path -Parent $templateTarget
    if (-not (Test-Path -LiteralPath $targetDirectory)) {
        New-Item -ItemType Directory -Force -Path $targetDirectory | Out-Null
    }

    if ($templateSource -eq $templateTarget) {
        $presentation.Save()
    } else {
        $presentation.SaveAs($templateTarget, 24)
    }
} finally {
    if ($null -ne $presentation) {
        $presentation.Close()
    }
    if ($null -ne $powerPoint) {
        $powerPoint.Quit()
    }
    foreach ($temporaryFile in $temporaryFiles) {
        if (Test-Path -LiteralPath $temporaryFile) {
            Remove-Item -LiteralPath $temporaryFile -Force
        }
    }
}

Write-Output "Created corporate PowerPoint template: $templateTarget"
