param(
    [string]$Proto = "D:\Window Word\output\playwright\refined-buttons.png",
    [string]$Wpf = "D:\Window Word\output\wpf\v4-home-real.png"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$p = [System.Drawing.Bitmap]::FromFile($Proto)
$w = [System.Drawing.Bitmap]::FromFile($Wpf)
$scale = $w.Width / 360.0
Write-Output ("scale=" + $scale + " proto=" + $p.Width + "x" + $p.Height + " wpf=" + $w.Width + "x" + $w.Height)

$points = @(
    @{n="window bg (top-right, empty)"; x=250; y=110},
    @{n="window bg (left gutter)";      x=10;  y=280},
    @{n="card fill (empty area)";       x=180; y=245},
    @{n="card fill (near edge)";        x=330; y=160},
    @{n="primary button fill";          x=100; y=318},
    @{n="secondary button fill";        x=280; y=318},
    @{n="progress track";               x=300; y=262},
    @{n="progress fill";                x=45;  y=262},
    @{n="bottom nav (between items)";   x=180; y=430},
    @{n="bottom area below nav";        x=180; y=480},
    @{n="card border top edge";         x=180; y=143},
    @{n="divider in card";              x=180; y=220}
)

foreach ($pt in $points) {
    $px = [int][Math]::Round($pt.x * $scale)
    $py = [int][Math]::Round($pt.y * $scale)
    if ($px -ge $w.Width) { $px = $w.Width - 1 }
    if ($py -ge $w.Height) { $py = $w.Height - 1 }
    $a = $p.GetPixel($pt.x, $pt.y)
    $b = $w.GetPixel($px, $py)
    $dr = [int]$b.R - [int]$a.R
    $dg = [int]$b.G - [int]$a.G
    $db = [int]$b.B - [int]$a.B
    Write-Output ("{0,-30} proto=({1,3},{2,3},{3,3}) wpf=({4,3},{5,3},{6,3})  deltaR={7,4} deltaG={8,4} deltaB={9,4}" -f $pt.n, $a.R, $a.G, $a.B, $b.R, $b.G, $b.B, $dr, $dg, $db)
}

# region averages
function Region-Avg($bmp, $x0, $y0, $x1, $y1) {
    $sr = 0; $sg = 0; $sb = 0; $n = 0
    for ($yy = $y0; $yy -lt $y1; $yy++) {
        for ($xx = $x0; $xx -lt $x1; $xx++) {
            $c = $bmp.GetPixel($xx, $yy)
            $sr += $c.R; $sg += $c.G; $sb += $c.B; $n++
        }
    }
    return @([int]($sr / $n), [int]($sg / $n), [int]($sb / $n))
}

$pr = Region-Avg $p 190 150 340 250
$wr = Region-Avg $w ([int](190 * $scale)) ([int](150 * $scale)) ([int](340 * $scale)) ([int](250 * $scale))
Write-Output ("card region avg  proto=(" + $pr[0] + "," + $pr[1] + "," + $pr[2] + ") wpf=(" + $wr[0] + "," + $wr[1] + "," + $wr[2] + ")")

$pr2 = Region-Avg $p 250 60 350 130
$wr2 = Region-Avg $w ([int](250 * $scale)) ([int](60 * $scale)) ([int](350 * $scale)) ([int](130 * $scale))
Write-Output ("header region avg proto=(" + $pr2[0] + "," + $pr2[1] + "," + $pr2[2] + ") wpf=(" + $wr2[0] + "," + $wr2[1] + "," + $wr2[2] + ")")

$p.Dispose()
$w.Dispose()
