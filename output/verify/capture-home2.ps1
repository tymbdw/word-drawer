param(
    [string]$Exe = "D:\Window Word\src\WordDrawer.App\bin\Debug\net8.0-windows\WordDrawer.App.exe",
    [string]$OutPng = "D:\Window Word\output\wpf\new-home-verify.png",
    [string]$DbPath = "D:\Window Word\output\verify\home-verify.db",
    [int]$WarmupMs = 3000
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public class WinCap {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }

    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr hWnd, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder s, int n);

    public static List<IntPtr> WindowsOf(uint targetPid) {
        var found = new List<IntPtr>();
        EnumWindows((h, l) => {
            uint pid; GetWindowThreadProcessId(h, out pid);
            if (pid == targetPid && IsWindowVisible(h)) found.Add(h);
            return true;
        }, IntPtr.Zero);
        return found;
    }

    public static string Describe(IntPtr h) {
        var cls = new StringBuilder(256); GetClassName(h, cls, 256);
        var txt = new StringBuilder(512); GetWindowText(h, txt, 512);
        RECT r; GetWindowRect(h, out r);
        return string.Format("{0} [{1}x{2} at {3},{4}] class={5} title={6}",
            h.ToString(), r.Right - r.Left, r.Bottom - r.Top, r.Left, r.Top, cls, txt);
    }
}
"@

if (Test-Path $DbPath) { Remove-Item $DbPath -Force }
New-Item -ItemType Directory -Force -Path (Split-Path $DbPath) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path $OutPng) | Out-Null

$env:WORDDRAWER_DATA_PATH = $DbPath
$proc = Start-Process -FilePath $Exe -PassThru
Write-Output ("PID=" + $proc.Id)
Start-Sleep -Milliseconds $WarmupMs
$proc.Refresh()
if ($proc.HasExited) { throw "exited: $($proc.ExitCode)" }

$wins = [WinCap]::WindowsOf([uint32]$proc.Id)
Write-Output ("visible windows: " + $wins.Count)
foreach ($win in $wins) { Write-Output ("  " + [WinCap]::Describe($win)) }

$hwnd = [IntPtr]::Zero
$best = 0
foreach ($win in $wins) {
    $r = New-Object WinCap+RECT
    [WinCap]::GetWindowRect($win, [ref]$r) | Out-Null
    $area = ($r.Right - $r.Left) * ($r.Bottom - $r.Top)
    if ($area -gt $best) { $best = $area; $hwnd = $win }
}
if ($hwnd -eq [IntPtr]::Zero) { throw "no visible window for pid" }

$rect = New-Object WinCap+RECT
[WinCap]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
$w = $rect.Right - $rect.Left
$h = $rect.Bottom - $rect.Top
Write-Output ("TARGET " + [WinCap]::Describe($hwnd))

[WinCap]::SetCursorPos(($rect.Left + [int]($w / 2)), ($rect.Top + [int]($h / 2))) | Out-Null
Start-Sleep -Milliseconds 500
[WinCap]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 600

[WinCap]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
$w = $rect.Right - $rect.Left
$h = $rect.Bottom - $rect.Top
Write-Output ("AFTER-FOCUS rect w=" + $w + " h=" + $h + " left=" + $rect.Left)

$bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$gfx = [System.Drawing.Graphics]::FromImage($bmp)
$gfx.Clear([System.Drawing.Color]::Transparent)
$hdc = $gfx.GetHdc()
$ok = [WinCap]::PrintWindow($hwnd, $hdc, 2)
$gfx.ReleaseHdc($hdc)
$gfx.Dispose()
Write-Output ("PrintWindow=" + $ok)
$bmp.Save($OutPng, [System.Drawing.Imaging.ImageFormat]::Png)

$composite = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$cg = [System.Drawing.Graphics]::FromImage($composite)
$cg.Clear([System.Drawing.Color]::FromArgb(255, 233, 236, 241))
$cg.DrawImage($bmp, 0, 0, $w, $h)
$cg.Dispose()
$cp = $OutPng -replace "\.png$", "-on-grey.png"
$composite.Save($cp, [System.Drawing.Imaging.ImageFormat]::Png)
$composite.Dispose()
$bmp.Dispose()

[WinCap]::SetCursorPos(120, 120) | Out-Null
Stop-Process -Id $proc.Id -Force
Start-Sleep -Milliseconds 400
Write-Output ("SAVED " + $OutPng)
Write-Output ("SAVED " + $cp)
