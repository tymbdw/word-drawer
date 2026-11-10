param(
    [string]$Src = "D:\Window Word\output\wpf\v16-real.png"
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$b = [System.Drawing.Bitmap]::FromFile($Src)
Write-Output ("size " + $b.Width + "x" + $b.Height)
Write-Output ""
Write-Output "top-left corner: luminance along y=6, x=14..44  (backdrop is black; a smooth ramp = antialiased arc)"
$line = ""
for ($x = 14; $x -le 44; $x++) {
    $c = $b.GetPixel($x, 6)
    $l = [int](0.2126 * $c.R + 0.7152 * $c.G + 0.0722 * $c.B)
    $line += ("{0,4}" -f $l)
}
Write-Output $line
Write-Output ""
Write-Output "top-left corner: luminance along x=6, y=14..44"
$line2 = ""
for ($y = 14; $y -le 44; $y++) {
    $c = $b.GetPixel(6, $y)
    $l = [int](0.2126 * $c.R + 0.7152 * $c.G + 0.0722 * $c.B)
    $line2 += ("{0,4}" -f $l)
}
Write-Output $line2
$b.Dispose()
