param(
    [string]$Proto = "D:\Window Word\output\playwright\refined-buttons.png",
    [string]$WpfNative = "D:\Window Word\output\wpf\v4-home-real.png"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$p = [System.Drawing.Bitmap]::FromFile($Proto)
$w = [System.Drawing.Bitmap]::FromFile($WpfNative)

Write-Output "--- corner transparency check (WPF 540x780) ---"
foreach ($c in @(@(1,1), @(4,4), @(10,10), @(20,20), @(30,30), @(40,40), @(60,60))) {
    $col = $w.GetPixel($c[0], $c[1])
    Write-Output ("  ({0},{1}) = ({2},{3},{4})" -f $c[0], $c[1], $col.R, $col.G, $col.B)
}

Write-Output "--- native-resolution glyph darkness (no downscale) ---"
function MinL($bmp, $x0, $y0, $x1, $y1) {
    $min = 999.0; $mc = $null
    for ($yy = $y0; $yy -lt $y1; $yy++) {
        for ($xx = $x0; $xx -lt $x1; $xx++) {
            if ($xx -ge $bmp.Width -or $yy -ge $bmp.Height) { continue }
            $c = $bmp.GetPixel($xx, $yy)
            $l = 0.2126 * $c.R + 0.7152 * $c.G + 0.0722 * $c.B
            if ($l -lt $min) { $min = $l; $mc = $c }
        }
    }
    return @([int]$min, $mc.R, $mc.G, $mc.B)
}

$s = 1.5
$regions = @(
    @{n="date text (11px)";   x0=19; y0=74;  x1=130; y1=90},
    @{n="greeting (26px)";    x0=19; y0=94;  x1=210; y1=128},
    @{n="card number (36px)"; x0=38; y0=182; x1=70;  y1=225},
    @{n="card sub (11px)";    x0=38; y0=225; x1=95;  y1=241},
    @{n="nav label (11px)";   x0=38; y0=395; x1=105; y1=415}
)
foreach ($r in $regions) {
    $a = MinL $p $r.x0 $r.y0 $r.x1 $r.y1
    $b = MinL $w ([int]($r.x0*$s)) ([int]($r.y0*$s)) ([int]($r.x1*$s)) ([int]($r.y1*$s))
    Write-Output ("{0,-18} proto L={1,3} ({2},{3},{4})  |  wpf@1.5x L={5,3} ({6},{7},{8})" -f $r.n, $a[0], $a[1], $a[2], $a[3], $b[0], $b[1], $b[2], $b[3])
}

Write-Output "--- effective text colour math ---"
Write-Output "  WPF TextPrimary  #F2293A49 at 95% over ~(205,225,238) => predicted (49,66,81) L=68"
Write-Output "  WPF TextSecondary #B05B7185 at 69% over ~(205,225,238) => predicted (125,148,166) L=145"
Write-Output "  Prototype primary oklch(0.25 0.026 247) = opaque ~#182633 => L=36"
Write-Output "  Prototype secondary oklch(0.50 0.03 244) = opaque ~#5B7185 => L=110"

$p.Dispose()
$w.Dispose()
