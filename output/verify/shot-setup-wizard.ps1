param(
    [string]$Setup = "D:\Window Word\build\dist\WordDrawer-Setup-0.1.0.exe",
    [string]$OutDir = "D:\Window Word\output\wpf"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$p = Start-Process -FilePath $Setup -PassThru
Start-Sleep -Milliseconds 3500

function Get-Shot([string]$name) {
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($bounds.X, $bounds.Y, 0, 0, $bmp.Size, [System.Drawing.CopyPixelOperation]::SourceCopy)
    $g.Dispose()
    $bmp.Save((Join-Path $OutDir $name), [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output ("SAVED " + $name)
}

$p.Refresh()
$handle = $p.MainWindowHandle
Write-Output ("setup window: " + $handle)

Start-Sleep -Milliseconds 600

# welcome -> next
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
Start-Sleep -Milliseconds 1200
Get-Shot "setup-dirpage.png"

# cancel out
[System.Windows.Forms.SendKeys]::SendWait("{ESC}")
Start-Sleep -Milliseconds 900
if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force }
Write-Output "setup closed"
