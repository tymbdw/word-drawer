param(
    [string]$Proto = "D:\Window Word\output\playwright\refined-buttons.png",
    [string]$Wpf = "D:\Window Word\output\wpf\v8-home-real.png"
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$p = [System.Drawing.Bitmap]::FromFile($Proto)
$w = [System.Drawing.Bitmap]::FromFile($Wpf)
$scale = 1.5
Write-Output "vertical strip through card top edge, x=180 (logical)"
for ($y = 136; $y -le 150; $y++) {
    $a = $p.GetPixel(180, $y)
    $py = [int][Math]::Round($y * $scale)
    $b = $w.GetPixel([int](180 * $scale), $py)
    Write-Output ("y={0,3} (wpf y={1,3})  proto=({2},{3},{4})  wpf=({5},{6},{7})" -f $y, $py, $a.R, $a.G, $a.B, $b.R, $b.G, $b.B)
}
Write-Output "horizontal strip through card left edge, y=200"
for ($x = 14; $x -le 26; $x++) {
    $a = $p.GetPixel($x, 200)
    $b = $w.GetPixel([int][Math]::Round($x * $scale), [int](200 * $scale))
    Write-Output ("x={0,3}  proto=({1},{2},{3})  wpf=({4},{5},{6})" -f $x, $a.R, $a.G, $a.B, $b.R, $b.G, $b.B)
}
$p.Dispose(); $w.Dispose()
