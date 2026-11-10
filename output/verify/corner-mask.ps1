param(
    [string]$Real = "D:\Window Word\output\wpf\alpha98-real.png",
    [string]$Ref = "D:\Window Word\output\wpf\alpha98-backdrop-sharp.png"
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$r = [System.Drawing.Bitmap]::FromFile($Real)
$b = [System.Drawing.Bitmap]::FromFile($Ref)
Write-Output ("sizes " + $r.Width + "x" + $r.Height + " vs " + $b.Width + "x" + $b.Height)

function DiffAt($x, $y) {
    $c1 = $r.GetPixel($x, $y)
    $c2 = $b.GetPixel($x, $y)
    return [Math]::Abs($c1.R - $c2.R) + [Math]::Abs($c1.G - $c2.G) + [Math]::Abs($c1.B - $c2.B)
}

Write-Output ""
Write-Output "top-left corner: diff(real, backdrop) - small means the window is transparent there"
for ($y = 0; $y -le 44; $y += 4) {
    $line = ""
    for ($x = 0; $x -le 44; $x += 4) {
        $d = DiffAt $x $y
        $ch = if ($d -lt 12) { "." } elseif ($d -lt 60) { ":" } elseif ($d -lt 150) { "+" } else { "#" }
        $line += $ch
    }
    Write-Output ("y=" + $y.ToString().PadLeft(3) + "  " + $line)
}

Write-Output ""
Write-Output "corner pixel values along the diagonal"
for ($i = 0; $i -le 40; $i += 4) {
    $c1 = $r.GetPixel($i, $i)
    $d = DiffAt $i $i
    Write-Output ("(" + $i + "," + $i + ") real=(" + $c1.R + "," + $c1.G + "," + $c1.B + ") diff=" + $d)
}
$r.Dispose(); $b.Dispose()
