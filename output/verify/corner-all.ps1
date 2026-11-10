param(
    [string]$Real = "D:\Window Word\output\wpf\alpha98-real.png",
    [string]$Ref = "D:\Window Word\output\wpf\alpha98-backdrop-sharp.png"
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$r = [System.Drawing.Bitmap]::FromFile($Real)
$b = [System.Drawing.Bitmap]::FromFile($Ref)
$w = $r.Width - 1; $h = $r.Height - 1

function DiffAt($x, $y) {
    $c1 = $r.GetPixel($x, $y); $c2 = $b.GetPixel($x, $y)
    return [Math]::Abs($c1.R - $c2.R) + [Math]::Abs($c1.G - $c2.G) + [Math]::Abs($c1.B - $c2.B)
}

function ArcEdge($name, [int]$x0, [int]$y0, [int]$sx, [int]$sy) {
    $firstInside = -1
    for ($t = 0; $t -lt 60; $t++) {
        $d = DiffAt ($x0 + $sx * $t) ($y0 + $sy * $t)
        if ($d -gt 200) { $firstInside = $t; break }
    }
    Write-Output ("{0,-14} first covered pixel on diagonal = {1} px (expected 0.293*R = 8.2 px for R=28 at 1x, 12.3 at 1.5x)" -f $name, $firstInside)
}

ArcEdge "top-left" 0 0 1 1
ArcEdge "top-right" $w 0 -1 1
ArcEdge "bottom-left" 0 $h 1 -1
ArcEdge "bottom-right" $w $h -1 -1
$r.Dispose(); $b.Dispose()
