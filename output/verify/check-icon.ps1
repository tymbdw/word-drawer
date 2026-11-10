param(
    [string]$Exe = "D:\Window Word\src\WordDrawer.App\bin\Debug\net8.0-windows\WordDrawer.App.exe",
    [string]$OutDir = "D:\Window Word\output\wpf"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class D32 {
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr c);
    [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);
}
"@
[D32]::SetThreadDpiAwarenessContext([IntPtr](-4)) | Out-Null

# 1. icon embedded in the exe (this is what Explorer, shortcuts and the taskbar use)
$ico = [System.Drawing.Icon]::ExtractAssociatedIcon($Exe)
$big = New-Object System.Drawing.Bitmap(256, 256)
$g = [System.Drawing.Graphics]::FromImage($big)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.Clear([System.Drawing.Color]::FromArgb(255, 30, 40, 52))
$g.DrawIcon($ico, (New-Object System.Drawing.Rectangle(0, 0, 256, 256)))
$g.Dispose()
$embedded = Join-Path $OutDir "icon-embedded.png"
$big.Save($embedded, [System.Drawing.Imaging.ImageFormat]::Png)
$big.Dispose()
Write-Output ("embedded icon: " + $ico.Width + "x" + $ico.Height + " -> " + $embedded)

# 2. the taskbar strip, with the app running
$proc = Start-Process -FilePath $Exe -PassThru
Start-Sleep -Milliseconds 6000

$screenW = [D32]::GetSystemMetrics(0)
$screenH = [D32]::GetSystemMetrics(1)
$stripH = 90
$bmp = New-Object System.Drawing.Bitmap($screenW, $stripH)
$g2 = [System.Drawing.Graphics]::FromImage($bmp)
$g2.CopyFromScreen(0, $screenH - $stripH, 0, 0, (New-Object System.Drawing.Size($screenW, $stripH)), [System.Drawing.CopyPixelOperation]::SourceCopy)
$g2.Dispose()
$taskbar = Join-Path $OutDir "taskbar.png"
$bmp.Save($taskbar, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output ("taskbar: " + $screenW + "x" + $screenH + " strip -> " + $taskbar)
