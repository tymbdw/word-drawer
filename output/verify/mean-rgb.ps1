param([string]$Src, [string]$Label)

Add-Type -AssemblyName System.Drawing
$bmp = [System.Drawing.Bitmap]::FromFile($Src)
$w = $bmp.Width; $h = $bmp.Height

function Mean([int]$x0, [int]$y0, [int]$x1, [int]$y1) {
    $r = 0.0; $g = 0.0; $b = 0.0; $n = 0
    for ($y = $y0; $y -lt $y1; $y += 7) {
        for ($x = $x0; $x -lt $x1; $x += 7) {
            $c = $bmp.GetPixel($x, $y)
            $r += $c.R; $g += $c.G; $b += $c.B; $n++
        }
    }
    $r = $r / $n; $g = $g / $n; $b = $b / $n
    $l = 0.2126 * $r + 0.7152 * $g + 0.0722 * $b
    return ("{0:0.0},{1:0.0},{2:0.0} L={3:0.0}" -f $r, $g, $b, $l)
}

$pad = [int]([math]::Min($w, $h) * 0.08)
Write-Output ("$Label  size=${w}x${h}")
Write-Output ("  panel_interior: " + (Mean $pad ([int]($h * 0.12)) ($w - $pad) ([int]($h * 0.30))))
Write-Output ("  card_area     : " + (Mean ([int]($w * 0.14)) ([int]($h * 0.34)) ([int]($w * 0.86)) ([int]($h * 0.46))))
Write-Output ("  edge_ring     : " + (Mean 2 ([int]($h * 0.30)) ([int]($w * 0.05)) ([int]($h * 0.70))))
$bmp.Dispose()
