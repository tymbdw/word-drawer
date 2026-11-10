param(
    [string]$Src = "D:\Window Word\output\wpf\alpha98-real.png",
    [string]$Out = "D:\Window Word\output\wpf\corner-zoom.png",
    [int]$Size = 80,
    [double]$Zoom = 5.0
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Bitmap]::FromFile($Src)
$w = $img.Width; $h = $img.Height
$corners = @(
    @{ n = "top-left";     x = 0;       y = 0 },
    @{ n = "top-right";    x = $w - $Size; y = 0 },
    @{ n = "bottom-left";  x = 0;       y = $h - $Size },
    @{ n = "bottom-right"; x = $w - $Size; y = $h - $Size }
)
$cell = [int]($Size * $Zoom)
$canvas = New-Object System.Drawing.Bitmap(($cell * 2 + 24), ($cell * 2 + 48), [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($canvas)
$g.Clear([System.Drawing.Color]::FromArgb(255, 30, 32, 36))
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
$font = New-Object System.Drawing.Font("Consolas", 9)
$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$i = 0
foreach ($c in $corners) {
    $col = $i % 2; $row = [int]($i / 2)
    $dx = $col * ($cell + 24)
    $dy = $row * ($cell + 24) + 20
    $srcRect = New-Object System.Drawing.Rectangle($c.x, $c.y, $Size, $Size)
    $dstRect = New-Object System.Drawing.Rectangle($dx, $dy, $cell, $cell)
    $g.DrawImage($img, $dstRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    $g.DrawString($c.n, $font, $brush, $dx, ($dy - 16))
    $i++
}
$g.Dispose()
$canvas.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$canvas.Dispose()
$img.Dispose()
Write-Output ("SAVED " + $Out)
