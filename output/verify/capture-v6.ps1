param(
    [string]$Exe = "D:\Window Word\src\WordDrawer.App\bin\Debug\net8.0-windows\WordDrawer.App.exe",
    [string]$RefPng = "D:\Window Word\output\playwright\refined-buttons.png",
    [string]$OutDir = "D:\Window Word\output\wpf",
    [string]$DbPath = "D:\Window Word\output\verify\v11-home.db",
    [int]$WarmupMs = 3400,
    [string]$Tag = "v11-home"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public class WinCap6 {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr ctx);
    [DllImport("shcore.dll")] public static extern int SetProcessDpiAwareness(int value);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr after, int x, int y, int cx, int cy, uint flags);

    public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
    public static readonly IntPtr HWND_NOTOPMOST = new IntPtr(-2);
    public const uint SWP_NOSIZE = 0x0001;
    public const uint SWP_NOMOVE = 0x0002;

    public static void MakeDpiAware() {
        try { SetThreadDpiAwarenessContext(new IntPtr(-4)); } catch {}
        try { SetProcessDpiAwareness(2); } catch {}
    }

    public static IntPtr LargestOf(uint targetPid, out int w, out int h) {
        IntPtr best = IntPtr.Zero; int bestArea = 0; int bw = 0; int bh = 0;
        EnumWindows((hh, l) => {
            uint pid; GetWindowThreadProcessId(hh, out pid);
            if (pid == targetPid && IsWindowVisible(hh)) {
                RECT r; GetWindowRect(hh, out r);
                int area = (r.Right - r.Left) * (r.Bottom - r.Top);
                if (area > bestArea) { bestArea = area; best = hh; bw = r.Right - r.Left; bh = r.Bottom - r.Top; }
            }
            return true;
        }, IntPtr.Zero);
        w = bw; h = bh;
        return best;
    }
}
"@

[WinCap6]::MakeDpiAware()

if (Test-Path $DbPath) { Remove-Item $DbPath -Force }
New-Item -ItemType Directory -Force -Path (Split-Path $DbPath) | Out-Null
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$ref = [System.Drawing.Bitmap]::FromFile($RefPng)
$c1 = $ref.GetPixel(6, 6)
$c2 = $ref.GetPixel($ref.Width - 7, $ref.Height - 7)
$ref.Dispose()

$bw = 700
$bh = 940
$back = New-Object System.Drawing.Bitmap($bw, $bh, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$bgfx = [System.Drawing.Graphics]::FromImage($back)
$rectF = New-Object System.Drawing.Rectangle(0, 0, $bw, $bh)
$grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rectF, $c1, $c2, 45.0)
$bgfx.FillRectangle($grad, $rectF)
$bgfx.Dispose()

$wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
# physical pixels: the window is 540x780 at 150%, and it floats 28 DIP (42 px) off the edge
$wantX = $wa.Right - 540 - 42
$wantY = $wa.Top + [int][Math]::Max(18, (($wa.Height - 780) / 2))

$fx = [Math]::Max(0, $wantX - 80)
$fy = [Math]::Max(0, $wantY - 100)

$form = New-Object System.Windows.Forms.Form
$form.FormBorderStyle = "None"
$form.StartPosition = "Manual"
$form.Bounds = New-Object System.Drawing.Rectangle($fx, $fy, $bw, $bh)
$form.BackgroundImage = $back
$form.BackgroundImageLayout = "Stretch"
$form.ShowInTaskbar = $false
$form.TopMost = $true
$form.Show()
$form.Activate()
[System.Windows.Forms.Application]::DoEvents()
Start-Sleep -Milliseconds 500

$env:WORDDRAWER_DATA_PATH = $DbPath
$proc = Start-Process -FilePath $Exe -PassThru
Write-Output ("PID=" + $proc.Id)
Start-Sleep -Milliseconds $WarmupMs
$proc.Refresh()
if ($proc.HasExited) { throw "exited: $($proc.ExitCode)" }

$w = 0; $h = 0
$hwnd = [WinCap6]::LargestOf([uint32]$proc.Id, [ref]$w, [ref]$h)
if ($hwnd -eq [IntPtr]::Zero) { throw "no window" }

$rect = New-Object WinCap6+RECT
[WinCap6]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
Write-Output ("initial window at " + $rect.Left + "," + $rect.Top + " size " + ($rect.Right - $rect.Left) + "x" + ($rect.Bottom - $rect.Top))

# force onto the primary monitor's right edge so the capture is deterministic
if ($rect.Left -ne $wantX -or $rect.Top -ne $wantY) {
    [WinCap6]::SetWindowPos($hwnd, [IntPtr]::Zero, $wantX, $wantY, 0, 0, [WinCap6]::SWP_NOSIZE) | Out-Null
    Start-Sleep -Milliseconds 400
    Write-Output ("moved to " + $wantX + "," + $wantY)
}

[WinCap6]::SetWindowPos($hwnd, [WinCap6]::HWND_TOPMOST, 0, 0, 0, 0, ([WinCap6]::SWP_NOMOVE -bor [WinCap6]::SWP_NOSIZE)) | Out-Null
[WinCap6]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 300

[WinCap6]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
$w = $rect.Right - $rect.Left; $h = $rect.Bottom - $rect.Top

[WinCap6]::SetCursorPos(($rect.Left + [int]($w / 2)), ($rect.Top + [int]($h / 2))) | Out-Null
Start-Sleep -Milliseconds 900

[WinCap6]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
$w = $rect.Right - $rect.Left; $h = $rect.Bottom - $rect.Top
Write-Output ("capture rect " + $w + "x" + $h + " at " + $rect.Left + "," + $rect.Top)

$real = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$rg = [System.Drawing.Graphics]::FromImage($real)
$rg.CopyFromScreen($rect.Left, $rect.Top, 0, 0, (New-Object System.Drawing.Size($w, $h)), [System.Drawing.CopyPixelOperation]::SourceCopy)
$rg.Dispose()
$realPath = Join-Path $OutDir ($Tag + "-real.png")
$real.Save($realPath, [System.Drawing.Imaging.ImageFormat]::Png)
$real.Dispose()

[WinCap6]::SetWindowPos($hwnd, [WinCap6]::HWND_NOTOPMOST, 0, 0, 0, 0, ([WinCap6]::SWP_NOMOVE -bor [WinCap6]::SWP_NOSIZE)) | Out-Null
[WinCap6]::SetCursorPos(150, 150) | Out-Null
Stop-Process -Id $proc.Id -Force
Start-Sleep -Milliseconds 400
$form.Close()
$form.Dispose()
$back.Dispose()
Write-Output ("SAVED " + $realPath)
