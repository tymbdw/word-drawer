param(
    [string]$Exe = "D:\Window Word\src\WordDrawer.App\bin\Debug\net8.0-windows\WordDrawer.App.exe",
    [string]$OutDir = "D:\Window Word\output\wpf",
    [string]$DbPath = "D:\Window Word\output\verify\v19.db",
    [int]$WarmupMs = 3600,
    [string]$Tag = "v19"
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class WC10 {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr c);
    [DllImport("shcore.dll")] public static extern int SetProcessDpiAwareness(int v);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    public static readonly IntPtr TOPMOST = new IntPtr(-1);
    public static readonly IntPtr NOTOPMOST = new IntPtr(-2);
    public static void Dpi() {
        try { SetThreadDpiAwarenessContext(new IntPtr(-4)); } catch {}
        try { SetProcessDpiAwareness(2); } catch {}
    }
    public static IntPtr Largest(uint target, out int w, out int h) {
        IntPtr best = IntPtr.Zero; int area = 0; int bw = 0; int bh = 0;
        EnumWindows((hh, l) => {
            uint pid; GetWindowThreadProcessId(hh, out pid);
            if (pid == target && IsWindowVisible(hh)) {
                RECT r; GetWindowRect(hh, out r);
                int a = (r.Right - r.Left) * (r.Bottom - r.Top);
                if (a > area) { area = a; best = hh; bw = r.Right - r.Left; bh = r.Bottom - r.Top; }
            }
            return true;
        }, IntPtr.Zero);
        w = bw; h = bh;
        return best;
    }
}
"@
[WC10]::Dpi()
if (Test-Path $DbPath) { Remove-Item $DbPath -Force }
New-Item -ItemType Directory -Force -Path (Split-Path $DbPath) | Out-Null

$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$back = New-Object System.Drawing.Bitmap($screen.Width, $screen.Height)
$g = [System.Drawing.Graphics]::FromImage($back)
$rectAll = New-Object System.Drawing.Rectangle(0, 0, $screen.Width, $screen.Height)
$grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rectAll, [System.Drawing.Color]::FromArgb(255, 205, 219, 226), [System.Drawing.Color]::FromArgb(255, 158, 176, 191), 45.0)
$g.FillRectangle($grad, $rectAll)
$grad.Dispose()
$g.Dispose()

$form = New-Object System.Windows.Forms.Form
$form.FormBorderStyle = "None"
$form.StartPosition = "Manual"
$form.Bounds = New-Object System.Drawing.Rectangle(0, 0, $screen.Width, $screen.Height)
$form.BackgroundImage = $back
$form.BackgroundImageLayout = "Stretch"
$form.ShowInTaskbar = $false
$form.TopMost = $true
$form.Show(); $form.Activate()
[System.Windows.Forms.Application]::DoEvents()
Start-Sleep -Milliseconds 600

$env:WORDDRAWER_DATA_PATH = $DbPath
$proc = Start-Process -FilePath $Exe -PassThru
Start-Sleep -Milliseconds $WarmupMs
$proc.Refresh()
if ($proc.HasExited) { throw "exited" }

$w = 0; $h = 0
$hwnd = [WC10]::Largest([uint32]$proc.Id, [ref]$w, [ref]$h)
[WC10]::SetWindowPos($hwnd, [WC10]::TOPMOST, 0, 0, 0, 0, 3) | Out-Null
[WC10]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 300

$r = New-Object WC10+RECT
[WC10]::GetWindowRect($hwnd, [ref]$r) | Out-Null
$w = $r.Right - $r.Left; $h = $r.Bottom - $r.Top
Write-Output ("window " + $w + "x" + $h + " at " + $r.Left + "," + $r.Top)
Write-Output ("glass panel should be at " + ($r.Left + 66) + "," + ($r.Top + 66) + " size 540x780")

[WC10]::SetCursorPos(($r.Left + 66 + 270), ($r.Top + 66 + 390)) | Out-Null
Start-Sleep -Milliseconds 900
[WC10]::GetWindowRect($hwnd, [ref]$r) | Out-Null
$w = $r.Right - $r.Left; $h = $r.Bottom - $r.Top

$cw = [Math]::Min($w, $screen.Width - $r.Left)
$ch = [Math]::Min($h, $screen.Height - $r.Top)
$shot = New-Object System.Drawing.Bitmap($cw, $ch)
$sg = [System.Drawing.Graphics]::FromImage($shot)
$sg.CopyFromScreen($r.Left, $r.Top, 0, 0, (New-Object System.Drawing.Size($cw, $ch)), [System.Drawing.CopyPixelOperation]::SourceCopy)
$sg.Dispose()
$p = Join-Path $OutDir ($Tag + "-shadow.png")
$shot.Save($p, [System.Drawing.Imaging.ImageFormat]::Png)
$shot.Dispose()

[WC10]::SetWindowPos($hwnd, [WC10]::NOTOPMOST, 0, 0, 0, 0, 3) | Out-Null
[WC10]::SetCursorPos(150, 150) | Out-Null
Stop-Process -Id $proc.Id -Force
Start-Sleep -Milliseconds 400
$form.Close(); $form.Dispose(); $back.Dispose()
Write-Output ("SAVED " + $p)
