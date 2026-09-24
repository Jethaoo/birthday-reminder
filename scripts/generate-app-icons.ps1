<#
.SYNOPSIS
    Regenerates the legacy launcher icon PNGs for the Flutter app.

.DESCRIPTION
    Android 26+ uses the adaptive icon in mipmap-anydpi-v26 (a vector, so it stays
    crisp at any size). Older devices fall back to these rasterised PNGs, drawn
    from the same geometry at every density.

    Run with Windows PowerShell (System.Drawing is not available in every
    PowerShell 7 install):

        powershell -ExecutionPolicy Bypass -File scripts/generate-app-icons.ps1
#>
param(
    [string]$ResourceRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) 'app\android\app\src\main\res')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$background = [System.Drawing.ColorTranslator]::FromHtml('#293D32')
$cream = [System.Drawing.ColorTranslator]::FromHtml('#F8F8F4')
$coral = [System.Drawing.ColorTranslator]::FromHtml('#FB8269')
$flame = [System.Drawing.ColorTranslator]::FromHtml('#FFC08F')

function New-RoundedRectPath {
    param([single]$X, [single]$Y, [single]$Width, [single]$Height, [single]$Radius)

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $diameter = $Radius * 2
    $path.AddArc($X, $Y, $diameter, $diameter, 180, 90)
    $path.AddArc($X + $Width - $diameter, $Y, $diameter, $diameter, 270, 90)
    $path.AddArc($X + $Width - $diameter, $Y + $Height - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($X, $Y + $Height - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

# Density bucket -> icon size in pixels (48dp base).
$densities = [ordered]@{ mdpi = 48; hdpi = 72; xhdpi = 96; xxhdpi = 144; xxxhdpi = 192 }

foreach ($density in $densities.Keys) {
    $size = $densities[$density]
    $scale = $size / 108.0

    # Coordinates below are in the 108x108 space used by the adaptive icon.
    function To-Px([double]$value) { [single]($value * $scale) }

    $bitmap = New-Object System.Drawing.Bitmap -ArgumentList $size, $size
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([System.Drawing.Color]::Transparent)

    $backgroundBrush = New-Object System.Drawing.SolidBrush -ArgumentList $background
    $creamBrush = New-Object System.Drawing.SolidBrush -ArgumentList $cream
    $coralBrush = New-Object System.Drawing.SolidBrush -ArgumentList $coral
    $flameBrush = New-Object System.Drawing.SolidBrush -ArgumentList $flame

    # Rounded square background covering the full canvas.
    $backgroundPath = New-RoundedRectPath -X 0 -Y 0 -Width $size -Height $size -Radius (To-Px 24)
    $graphics.FillPath($backgroundBrush, $backgroundPath)
    $backgroundPath.Dispose()

    # Cake body.
    $path = New-RoundedRectPath -X (To-Px 30) -Y (To-Px 60) -Width (To-Px 48) -Height (To-Px 18) -Radius (To-Px 9)
    $graphics.FillPath($creamBrush, $path)
    $path.Dispose()

    # Candles, drawn before the frosting so it overlaps their bases.
    foreach ($candleX in 42, 51, 60) {
        $graphics.FillRectangle($creamBrush, (To-Px $candleX), (To-Px 40), (To-Px 5), (To-Px 18))
    }

    # Frosting.
    $path = New-RoundedRectPath -X (To-Px 30) -Y (To-Px 54) -Width (To-Px 48) -Height (To-Px 8) -Radius (To-Px 4)
    $graphics.FillPath($coralBrush, $path)
    $path.Dispose()

    # Flames.
    foreach ($flameCenterX in 44.5, 53.5, 62.5) {
        $diameter = To-Px 6
        $graphics.FillEllipse(
            $flameBrush,
            (To-Px $flameCenterX) - ($diameter / 2),
            (To-Px 36.5) - ($diameter / 2),
            $diameter,
            $diameter
        )
    }

    $targetDirectory = Join-Path $ResourceRoot "mipmap-$density"
    if (-not (Test-Path -LiteralPath $targetDirectory)) {
        New-Item -ItemType Directory -Path $targetDirectory | Out-Null
    }
    $target = Join-Path $targetDirectory 'ic_launcher.png'
    $bitmap.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)

    $graphics.Dispose()
    $bitmap.Dispose()
    $backgroundBrush.Dispose()
    $creamBrush.Dispose()
    $coralBrush.Dispose()
    $flameBrush.Dispose()

    Write-Host "Wrote $target (${size}x${size})"
}

