param(
    [string]$OutDir = "D:\Window Word\src\WordDrawer.App\Assets"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# 96-unit design grid, rendered at 1024 then downsampled.
$S = 1024
[double]$k = $S / 96.0

$bmp = New-Object System.Drawing.Bitmap($S, $S, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.Clear([System.Drawing.Color]::Transparent)

# rounded square
[double]$r = 26 * $k
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$path.AddArc(0, 0, 2 * $r, 2 * $r, 180, 90)
$path.AddArc($S - 2 * $r, 0, 2 * $r, 2 * $r, 270, 90)
$path.AddArc($S - 2 * $r, $S - 2 * $r, 2 * $r, 2 * $r, 0, 90)
$path.AddArc(0, $S - 2 * $r, 2 * $r, 2 * $r, 90, 90)
$path.CloseFigure()

$bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    [System.Drawing.PointF]::new(0, 0),
    [System.Drawing.PointF]::new([single]$S, [single]$S),
    [System.Drawing.Color]::FromArgb(255, 0x22, 0x34, 0x4a),
    [System.Drawing.Color]::FromArgb(255, 0x0e, 0x1b, 0x28))
$g.FillPath($bg, $path)

# the slit: 56,14 -> 40,82 in design units
$p1 = [System.Drawing.PointF]::new([single](56 * $k), [single](14 * $k))
$p2 = [System.Drawing.PointF]::new([single](40 * $k), [single](82 * $k))

$slit = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    [System.Drawing.PointF]::new(0, [single](14 * $k)),
    [System.Drawing.PointF]::new(0, [single](82 * $k)),
    [System.Drawing.Color]::FromArgb(255, 0x7f, 0xe3, 0xff),
    [System.Drawing.Color]::FromArgb(255, 0x28, 0x99, 0xd6))

$pen = New-Object System.Drawing.Pen($slit, (9 * $k))
$pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$g.DrawLine($pen, $p1, $p2)
$pen.Dispose()

# inner highlight
$core = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(230, 0xbf, 0xf0, 0xff), (2.4 * $k))
$core.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$core.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$g.DrawLine($core, $p1, $p2)
$core.Dispose()

$g.Dispose()

$master = Join-Path $OutDir "logo-1024.png"
$bmp.Save($master, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

foreach ($size in 16, 24, 32, 48, 64, 128, 256) {
    $src = [System.Drawing.Image]::FromFile($master)
    $dst = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $dg = [System.Drawing.Graphics]::FromImage($dst)
    $dg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $dg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $dg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $dg.Clear([System.Drawing.Color]::Transparent)
    $dg.DrawImage($src, 0, 0, $size, $size)
    $dg.Dispose()
    $src.Dispose()
    $dst.Save((Join-Path $OutDir ("logo-" + $size + ".png")), [System.Drawing.Imaging.ImageFormat]::Png)
    $dst.Dispose()
}

Write-Output "rendered: $master"
Get-ChildItem $OutDir -Filter "logo-*.png" | ForEach-Object { Write-Output ("  " + $_.Name + " " + $_.Length) }
