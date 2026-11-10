param(
    [string]$Proto = "D:\Window Word\output\playwright\refined-buttons.png",
    [string]$Wpf = "D:\Window Word\output\wpf\v4-home-real.png",
    [string]$Out = "D:\Window Word\output\wpf\compare-zoom.png",
    [int]$Y0 = 60,
    [int]$Y1 = 250,
    [double]$Zoom = 2.0
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$p = [System.Drawing.Bitmap]::FromFile($Proto)
$w = [System.Drawing.Bitmap]::FromFile($Wpf)
$scale = $w.Width / 360.0

$cropH = $Y1 - $Y0
$outW = [int](360 * $Zoom)
$outH = [int]($cropH * $Zoom)
$gap = 16
$band = 24

$canvas = New-Object System.Drawing.Bitmap(($outW * 2 + $gap), ($outH + $band), [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($canvas)
$g.Clear([System.Drawing.Color]::FromArgb(255, 250, 250, 252))
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

$font = New-Object System.Drawing.Font("Consolas", 10)
$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 40, 44, 52))
$g.DrawString("HTML prototype", $font, $brush, 4, 3)
$g.DrawString("WPF (same region, 2x nearest)", $font, $brush, ($outW + $gap + 4), 3)

$srcRect = New-Object System.Drawing.Rectangle(0, $Y0, 360, $cropH)
$dstRect = New-Object System.Drawing.Rectangle(0, $band, $outW, $outH)
$g.DrawImage($p, $dstRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)

$srcRect2 = New-Object System.Drawing.Rectangle(0, [int]($Y0 * $scale), $w.Width, [int]($cropH * $scale))
$dstRect2 = New-Object System.Drawing.Rectangle(($outW + $gap), $band, $outW, $outH)
$g.DrawImage($w, $dstRect2, $srcRect2, [System.Drawing.GraphicsUnit]::Pixel)

$g.Dispose()
$canvas.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$canvas.Dispose()
$font.Dispose()
$brush.Dispose()
$p.Dispose()
$w.Dispose()
Write-Output ("SAVED " + $Out + " " + $canvas.Width + "x" + $canvas.Height)
