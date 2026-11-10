param(
    [string]$Src = "D:\Window Word\output\wpf\v19-shadow.png",
    [string]$Out = "D:\Window Word\output\wpf\v19-glass.png",
    [int]$X = 66,
    [int]$Y = 66,
    [int]$W = 540,
    [int]$H = 780
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Bitmap]::FromFile($Src)
$crop = New-Object System.Drawing.Bitmap($W, $H)
$g = [System.Drawing.Graphics]::FromImage($crop)
$g.DrawImage($img, (New-Object System.Drawing.Rectangle(0, 0, $W, $H)), (New-Object System.Drawing.Rectangle($X, $Y, $W, $H)), [System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose()
$crop.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$crop.Dispose()
$img.Dispose()
Write-Output ("SAVED " + $Out)
