param(
    [string]$Left = "D:\Window Word\output\playwright\refined-buttons.png",
    [string]$Right = "D:\Window Word\output\wpf\v2-home-on-grey.png",
    [string]$Out = "D:\Window Word\output\wpf\compare-home.png"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$l = [System.Drawing.Image]::FromFile($Left)
$r = [System.Drawing.Image]::FromFile($Right)

$w = 360
$h = 520
$gap = 20
$band = 26

$canvas = New-Object System.Drawing.Bitmap(($w * 2 + $gap), ($h + $band), [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($canvas)
$g.Clear([System.Drawing.Color]::FromArgb(255, 250, 250, 252))
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

$font = New-Object System.Drawing.Font("Consolas", 10)
$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 40, 44, 52))
$g.DrawString("HTML prototype (360x520)", $font, $brush, 4, 4)
$g.DrawString("WPF native (downscaled 540->360)", $font, $brush, ($w + $gap + 4), 4)

$g.DrawImage($l, (New-Object System.Drawing.Rectangle(0, $band, $w, $h)))
$g.DrawImage($r, (New-Object System.Drawing.Rectangle(($w + $gap), $band, $w, $h)))

$pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 200, 205, 214), 1)
$g.DrawRectangle($pen, 0, $band, $w - 1, $h - 1)
$g.DrawRectangle($pen, ($w + $gap), $band, $w - 1, $h - 1)

$g.Dispose()
$canvas.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$canvas.Dispose()
$pen.Dispose()
$font.Dispose()
$brush.Dispose()
$l.Dispose()
$r.Dispose()
Write-Output ("SAVED " + $Out)
