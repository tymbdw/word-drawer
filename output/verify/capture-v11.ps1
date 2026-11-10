param(
    [string]$Exe = "D:\Window Word\src\WordDrawer.App\bin\Debug\net8.0-windows\WordDrawer.App.exe",
    [string]$OutDir = "D:\Window Word\output\wpf",
    [string]$DbPath = "D:\Window Word\output\verify\v20.db",
    [int]$WarmupMs = 3600,
    [string]$Tag = "v20"
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class WC11 {
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
[WC11]::Dpi()
if (Test-Path $DbPath) { Remove-Item $DbPath -Force }
New-Item -ItemType Directory -Force -Path (Split-Path $DbPath) | Out-Null

$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$back = New-Object System.Drawing.Bitmap($screen.Width, $screen.Height)
$g = [System.Drawing.Graphics]::FromImage($back)
$g.Clear([System.Drawing.Color]::FromArgb(255, 10, 13, 17))
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
$hwnd = [WC11]::Largest([uint32]$proc.Id, [ref]$w, [ref]$h)
[WC11]::SetWindowPos($hwnd, [WC11]::TOPMOST, 0, 0, 0, 0, 3) | Out-Null
Start-Sleep -Milliseconds 200

# hover the drawer first, then leave: the hide timer only starts on MouseLeave
$r = New-Object WC11+RECT
[WC11]::GetWindowRect($hwnd, [ref]$r) | Out-Null
[WC11]::SetCursorPos(($r.Left + 66 + 270), ($r.Top + 66 + 390)) | Out-Null
Start-Sleep -Milliseconds 500
[WC11]::SetCursorPos(200, 700) | Out-Null
Start-Sleep -Milliseconds 1800

$r = New-Object WC11+RECT
[WC11]::GetWindowRect($hwnd, [ref]$r) | Out-Null
Write-Output ("collapsed window at " + $r.Left + "," + $r.Top + " size " + ($r.Right - $r.Left) + "x" + ($r.Bottom - $r.Top))
$glassLeft = $r.Left + 66
Write-Output ("glass left edge should sit at " + ($screen.Width - 12) + " and is at " + $glassLeft)

$stripX = $screen.Width - 60
$stripY = 500
$shot = New-Object System.Drawing.Bitmap(60, 300)
$sg = [System.Drawing.Graphics]::FromImage($shot)
$sg.CopyFromScreen($stripX, $stripY, 0, 0, (New-Object System.Drawing.Size(60, 300)), [System.Drawing.CopyPixelOperation]::SourceCopy)
$sg.Dispose()
$p = Join-Path $OutDir ($Tag + "-collapsed.png")
$shot.Save($p, [System.Drawing.Imaging.ImageFormat]::Png)

$line = ""
for ($i = 0; $i -lt 60; $i += 4) {
    $c = $shot.GetPixel($i, 150)
    $l = [int](0.2126 * $c.R + 0.7152 * $c.G + 0.0722 * $c.B)
    $line += ("{0,4}" -f $l)
}
$shot.Dispose()
Write-Output ("luminance across x=" + $stripX + ".." + ($stripX + 59) + " (screen edge is the last pixel):")
Write-Output $line

# now hover the trigger strip and confirm it slides back out with the shadow restored
[WC11]::SetCursorPos(($screen.Width - 4), ($r.Top + 66 + 390)) | Out-Null
Start-Sleep -Milliseconds 1200
$r2 = New-Object WC11+RECT
[WC11]::GetWindowRect($hwnd, [ref]$r2) | Out-Null
Write-Output ("after hovering the strip: window at " + $r2.Left + "," + $r2.Top + " (expected 1912 for the open position)")

[WC11]::SetWindowPos($hwnd, [WC11]::NOTOPMOST, 0, 0, 0, 0, 3) | Out-Null
[WC11]::SetCursorPos(150, 150) | Out-Null
Stop-Process -Id $proc.Id -Force
Start-Sleep -Milliseconds 400
$form.Close(); $form.Dispose(); $back.Dispose()
Write-Output ("SAVED " + $p)
