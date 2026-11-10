param(
    [string]$Exe = "D:\Window Word\src\WordDrawer.App\bin\Debug\net8.0-windows\WordDrawer.App.exe",
    [string]$OutPng = "D:\Window Word\output\wpf\new-home-verify.png",
    [string]$DbPath = "D:\Window Word\output\verify\home-verify.db",
    [int]$WarmupMs = 2600
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class NativeCapture {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, uint nFlags);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int X, int Y);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    public const uint PW_RENDERFULLCONTENT = 0x00000002;
}
"@

if (Test-Path $DbPath) { Remove-Item $DbPath -Force }
New-Item -ItemType Directory -Force -Path (Split-Path $DbPath) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path $OutPng) | Out-Null

$env:WORDDRAWER_DATA_PATH = $DbPath
$proc = Start-Process -FilePath $Exe -PassThru
Write-Output ("PID=" + $proc.Id)

$hwnd = [IntPtr]::Zero
for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Milliseconds 200
    $proc.Refresh()
    if ($proc.HasExited) { throw "process exited with code $($proc.ExitCode)" }
    if ($proc.MainWindowHandle -ne [IntPtr]::Zero) { $hwnd = $proc.MainWindowHandle; break }
}
if ($hwnd -eq [IntPtr]::Zero) { throw "main window handle not found" }

Start-Sleep -Milliseconds $WarmupMs
$proc.Refresh()

$rect = New-Object NativeCapture+RECT
[NativeCapture]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
$w = $rect.Right - $rect.Left
$h = $rect.Bottom - $rect.Top
Write-Output ("RECT left=" + $rect.Left + " top=" + $rect.Top + " w=" + $w + " h=" + $h)

# keep the pointer inside so the drawer does not auto-hide
[NativeCapture]::SetCursorPos(($rect.Left + [int]($w / 2)), ($rect.Top + [int]($h / 2))) | Out-Null
Start-Sleep -Milliseconds 400

[NativeCapture]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 500

$bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$gfx = [System.Drawing.Graphics]::FromImage($bmp)
$gfx.Clear([System.Drawing.Color]::Transparent)
$hdc = $gfx.GetHdc()
$ok = [NativeCapture]::PrintWindow($hwnd, $hdc, [NativeCapture]::PW_RENDERFULLCONTENT)
$gfx.ReleaseHdc($hdc)
$gfx.Dispose()
Write-Output ("PrintWindow=" + $ok)

$bmp.Save($OutPng, [System.Drawing.Imaging.ImageFormat]::Png)

# composited copy on neutral desktop grey so transparency is readable
$composite = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$cg = [System.Drawing.Graphics]::FromImage($composite)
$cg.Clear([System.Drawing.Color]::FromArgb(255, 236, 238, 242))
$cg.DrawImage($bmp, 0, 0, $w, $h)
$cg.Dispose()
$compositePath = $OutPng -replace "\.png$", "-on-grey.png"
$composite.Save($compositePath, [System.Drawing.Imaging.ImageFormat]::Png)
$composite.Dispose()
$bmp.Dispose()

# restore a neutral cursor position
[NativeCapture]::SetCursorPos(200, 200) | Out-Null

Stop-Process -Id $proc.Id -Force
Start-Sleep -Milliseconds 500
Write-Output ("SAVED " + $OutPng)
Write-Output ("SAVED " + $compositePath)
