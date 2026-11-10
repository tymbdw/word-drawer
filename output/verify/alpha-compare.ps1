param(
    [string]$Out = "D:\Window Word\output\wpf\alpha-compare.png"
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$items = @(
    @{ path = "D:\Window Word\output\wpf\alpha72-real.png";  label = "alpha 72  (28%)" },
    @{ path = "D:\Window Word\output\wpf\alpha98-real.png";  label = "alpha 98  (38%)" },
    @{ path = "D:\Window Word\output\wpf\alpha122-real.png"; label = "alpha 122 (48%)" }
)

$w = 360; $h = 520; $gap = 18; $band = 26
$canvas = New-Object System.Drawing.Bitmap((($w + $gap) * 3 - $gap), ($h + $band), [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($canvas)
$g.Clear([System.Drawing.Color]::FromArgb(255, 250, 250, 252))
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
$font = New-Object System.Drawing.Font("Consolas", 10)
$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 30, 34, 40))

$i = 0
foreach ($it in $items) {
    $img = [System.Drawing.Bitmap]::FromFile($it.path)
    $x = $i * ($w + $gap)
    $g.DrawString($it.label, $font, $brush, ($x + 4), 5)
    $g.DrawImage($img, (New-Object System.Drawing.Rectangle($x, $band, $w, $h)))
    $img.Dispose()
    $i++
}

$pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 200, 205, 214), 1)
for ($k = 0; $k -lt 3; $k++) {
    $g.DrawRectangle($pen, ($k * ($w + $gap)), $band, ($w - 1), ($h - 1))
}
$g.Dispose()
$canvas.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$canvas.Dispose()
Write-Output ("SAVED " + $Out)
