param(
    [string]$Proto = "D:\Window Word\output\playwright\refined-buttons.png",
    [string]$Wpf = "D:\Window Word\output\wpf\v4-home-real.png"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$p = [System.Drawing.Bitmap]::FromFile($Proto)
$w = [System.Drawing.Bitmap]::FromFile($Wpf)
$scale = $w.Width / 360.0

function Region-Extremes($bmp, $x0, $y0, $x1, $y1, $s) {
    $minL = 999.0; $maxL = -1.0; $minC = $null; $maxC = $null
    $xa = [int][Math]::Round($x0 * $s); $ya = [int][Math]::Round($y0 * $s)
    $xb = [int][Math]::Round($x1 * $s); $yb = [int][Math]::Round($y1 * $s)
    if ($xb -gt $bmp.Width) { $xb = $bmp.Width }
    if ($yb -gt $bmp.Height) { $yb = $bmp.Height }
    for ($yy = $ya; $yy -lt $yb; $yy++) {
        for ($xx = $xa; $xx -lt $xb; $xx++) {
            $c = $bmp.GetPixel($xx, $yy)
            $l = 0.2126 * $c.R + 0.7152 * $c.G + 0.0722 * $c.B
            if ($l -lt $minL) { $minL = $l; $minC = $c }
            if ($l -gt $maxL) { $maxL = $l; $maxC = $c }
        }
    }
    return @{ minL = [int]$minL; minC = $minC; maxL = [int]$maxL; maxC = $maxC }
}

$regions = @(
    @{n="date text";        x0=19; y0=74;  x1=130; y1=90},
    @{n="greeting title";   x0=19; y0=94;  x1=210; y1=128},
    @{n="card label";       x0=38; y0=160; x1=90;  y1=177},
    @{n="card big number";  x0=38; y0=182; x1=70;  y1=225},
    @{n="card sub label";   x0=38; y0=225; x1=95;  y1=241},
    @{n="primary btn text"; x0=120;y0=300; x1=165; y1=318},
    @{n="secondary btn txt";x0=228;y0=300; x1=290; y1=318},
    @{n="nav label";        x0=38; y0=395; x1=105; y1=415},
    @{n="nav subtitle";     x0=38; y0=418; x1=112; y1=432},
    @{n="brand name";       x0=54; y0=12;  x1=90;  y1=32}
)

foreach ($r in $regions) {
    $a = Region-Extremes $p $r.x0 $r.y0 $r.x1 $r.y1 1.0
    $b = Region-Extremes $w $r.x0 $r.y0 $r.x1 $r.y1 $scale
    Write-Output ("{0,-18} proto darkest L={1,3} rgb=({2},{3},{4})  |  wpf darkest L={5,3} rgb=({6},{7},{8})   contrastDelta={9}" -f `
        $r.n, $a.minL, $a.minC.R, $a.minC.G, $a.minC.B, $b.minL, $b.minC.R, $b.minC.G, $b.minC.B, ($a.minL - $b.minL))
}

$p.Dispose()
$w.Dispose()
