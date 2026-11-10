param(
    [string]$Wpf = "D:\Window Word\output\wpf\v13-real.png"
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$b = [System.Drawing.Bitmap]::FromFile($Wpf)
$s = 1.5

function Stats($bmp, $x0, $y0, $x1, $y1, $sc) {
    $min = 999.0; $max = -1.0; $sum = 0.0; $sum2 = 0.0; $n = 0
    $xa = [int]($x0 * $sc); $ya = [int]($y0 * $sc)
    $xb = [int]($x1 * $sc); $yb = [int]($y1 * $sc)
    for ($y = $ya; $y -lt $yb; $y++) {
        for ($x = $xa; $x -lt $xb; $x++) {
            $c = $bmp.GetPixel($x, $y)
            $l = 0.2126 * $c.R + 0.7152 * $c.G + 0.0722 * $c.B
            if ($l -lt $min) { $min = $l }
            if ($l -gt $max) { $max = $l }
            $sum += $l; $sum2 += $l * $l; $n++
        }
    }
    $mean = $sum / $n
    $sd = [Math]::Sqrt(($sum2 / $n) - ($mean * $mean))
    return @([int]$min, [int]$max, [int][Math]::Round($mean), [Math]::Round($sd, 1))
}

Write-Output "region                 min  max  mean  sd   (L values, window pixels only)"
foreach ($r in @(
    @{n = "header empty";      x0 = 210; y0 = 20;  x1 = 320; y1 = 52},
    @{n = "greeting right";    x0 = 220; y0 = 96;  x1 = 340; y1 = 122},
    @{n = "card right empty";  x0 = 250; y0 = 236; x1 = 336; y1 = 258},
    @{n = "card left empty";   x0 = 44;  y0 = 246; x1 = 170; y1 = 258},
    @{n = "below buttons";     x0 = 24;  y0 = 344; x1 = 336; y1 = 352},
    @{n = "bottom strip";      x0 = 24;  y0 = 444; x1 = 336; y1 = 452}
)) {
    $st = Stats $b $r.x0 $r.y0 $r.x1 $r.y1 $s
    Write-Output ("{0,-22} {1,4} {2,4} {3,5} {4,5}" -f $r.n, $st[0], $st[1], $st[2], $st[3])
}
$b.Dispose()
