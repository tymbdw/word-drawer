param(
    [string]$Exe = "D:\Window Word\src\WordDrawer.App\bin\Debug\net8.0-windows\WordDrawer.App.exe",
    [string]$OutPng = "D:\Window Word\output\wpf\v2-home.png",
    [string]$DbPath = "D:\Window Word\output\verify\v2-home.db",
    [int]$WarmupMs = 3200
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public class WinCap2 {
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
    [DllImport("shcore.dll")] public static extern int SetProcessDpiAwareness(int value);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr ctx);
    [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr hWnd);

    public static void MakeDpiAware() {
        try { SetThreadDpiAwarenessContext(new IntPtr(-4)); } catch {}
        try { SetProcessDpiAwareness(2); } catch {}
    }

    public static List<IntPtr> WindowsOf(uint targetPid) {
        var found = new List<IntPtr>();
        EnumWindows((h, l) => {
            uint pid; GetWindowThreadProcessId(h, out pid);
            if (pid == targetPid && IsWindowVisible(h)) found.Add(h);
            return true;
        }, IntPtr.Zero);
        return found;
    }
}
"@

[WinCap2]::MakeDpiAware()

if (Test-Path $DbPath) { Remove-Item $DbPath -Force }
New-Item -ItemType Directory -Force -Path (Split-Path $DbPath) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path $OutPng) | Out-Null

$env:WORDDRAWER_DATA_PATH = $DbPath
$proc = Start-Process -FilePath $Exe -PassThru
Write-Output ("PID=" + $proc.Id)
Start-Sleep -Milliseconds $WarmupMs
$proc.Refresh()
if ($proc.HasExited) { throw "exited: $($proc.ExitCode)" }

$wins = [WinCap2]::WindowsOf([uint32]$proc.Id)
$hwnd = [IntPtr]::Zero
$best = 0
foreach ($win in $wins) {
    $r = New-Object WinCap2+RECT
    [WinCap2]::GetWindowRect($win, [ref]$r) | Out-Null
    $area = ($r.Right - $r.Left) * ($r.Bottom - $r.Top)
    if ($area -gt $best) { $best = $area; $hwnd = $win }
}
if ($hwnd -eq [IntPtr]::Zero) { throw "no visible window for pid" }

$dpi = [WinCap2]::GetDpiForWindow($hwnd)
Write-Output ("window DPI=" + $dpi + " scale=" + [math]::Round($dpi / 96.0, 2))

$rect = New-Object WinCap2+RECT
[WinCap2]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
$w = $rect.Right - $rect.Left
$h = $rect.Bottom - $rect.Top
Write-Output ("rect=" + $w + "x" + $h + " at " + $rect.Left + "," + $rect.Top)

[WinCap2]::SetCursorPos(($rect.Left + [int]($w / 2)), ($rect.Top + [int]($h / 2))) | Out-Null
Start-Sleep -Milliseconds 400
[WinCap2]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 700

[WinCap2]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
$w = $rect.Right - $rect.Left
$h = $rect.Bottom - $rect.Top

$bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$gfx = [System.Drawing.Graphics]::FromImage($bmp)
$gfx.Clear([System.Drawing.Color]::Transparent)
$hdc = $gfx.GetHdc()
$ok = [WinCap2]::PrintWindow($hwnd, $hdc, 2)
$gfx.ReleaseHdc($hdc)
$gfx.Dispose()
Write-Output ("PrintWindow=" + $ok + " size=" + $w + "x" + $h)
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

# --- UIA text dump ---
try {
    Add-Type -AssemblyName UIAutomationClient
    Add-Type -AssemblyName UIAutomationTypes
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
    $all = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
    Write-Output ("UIA nodes=" + $all.Count)
    foreach ($el in $all) {
        $ct = $el.Current.ControlType.ProgrammaticName -replace "ControlType\.", ""
        $nm = $el.Current.Name
        if ([string]::IsNullOrWhiteSpace($nm)) { continue }
        $b = $el.Current.BoundingRectangle
        Write-Output ("UIA|" + $ct + "|" + $nm + "|x=" + [int]$b.X + ",y=" + [int]$b.Y + ",w=" + [int]$b.Width + ",h=" + [int]$b.Height)
    }
} catch {
    Write-Output ("UIA-ERROR " + $_.Exception.Message)
}

[WinCap2]::SetCursorPos(150, 150) | Out-Null
Stop-Process -Id $proc.Id -Force
Start-Sleep -Milliseconds 400
Write-Output ("SAVED " + $OutPng)
Write-Output ("SAVED " + $cp)
