param(
    [string]$Exe = "D:\Window Word\src\WordDrawer.App\bin\Debug\net8.0-windows\WordDrawer.App.exe",
    [string]$OutDir = "D:\Window Word\output\wpf"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class D32 {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint f, int dx, int dy, uint d, IntPtr e);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr c);
    public static void Down() { mouse_event(0x0002, 0, 0, 0, IntPtr.Zero); }
    public static void Up() { mouse_event(0x0004, 0, 0, 0, IntPtr.Zero); }
    public static IntPtr Largest(uint target, out RECT rect) {
        IntPtr best = IntPtr.Zero; int area = 0; RECT br = new RECT();
        EnumWindows((hh, l) => {
            uint pid; GetWindowThreadProcessId(hh, out pid);
            if (pid == target && IsWindowVisible(hh)) {
                RECT r; GetWindowRect(hh, out r);
                int a = (r.Right - r.Left) * (r.Bottom - r.Top);
                if (a > area) { area = a; best = hh; br = r; }
            }
            return true;
        }, IntPtr.Zero);
        rect = br;
        return best;
    }
}
"@
[D32]::SetThreadDpiAwarenessContext([IntPtr](-4)) | Out-Null

$proc = Start-Process -FilePath $Exe -PassThru
Start-Sleep -Milliseconds 5500

[D32+RECT]$r = New-Object D32+RECT
$hwnd = [D32]::Largest([uint32]$proc.Id, [ref]$r)
[D32]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 600

# grab the header and drag it towards the middle of the screen
$x0 = $r.Left + 300
$y0 = $r.Top + 112
[D32]::SetCursorPos($x0, $y0) | Out-Null
Start-Sleep -Milliseconds 250
[D32]::Down()
Start-Sleep -Milliseconds 150

$tx = 780
$ty = 420
for ($i = 1; $i -le 24; $i++) {
    $x = [int]($x0 + ($tx - $x0) * $i / 24)
    $y = [int]($y0 + ($ty - $y0) * $i / 24)
    [D32]::SetCursorPos($x, $y) | Out-Null
    Start-Sleep -Milliseconds 28
}

[D32+RECT]$mid = New-Object D32+RECT
[D32]::GetWindowRect($hwnd, [ref]$mid) | Out-Null
Write-Output ("mid-drag window at " + $mid.Left + "," + $mid.Top)
$w = $mid.Right - $mid.Left
$h = $mid.Bottom - $mid.Top
$bmp = New-Object System.Drawing.Bitmap($w, $h)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($mid.Left, $mid.Top, 0, 0, $bmp.Size, [System.Drawing.CopyPixelOperation]::SourceCopy)
$g.Dispose()
$bmp.Save((Join-Path $OutDir "drag-mid.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

Start-Sleep -Milliseconds 300
[D32]::Up()
Start-Sleep -Milliseconds 1200

[D32+RECT]$end = New-Object D32+RECT
[D32]::GetWindowRect($hwnd, [ref]$end) | Out-Null
Write-Output ("after drop at " + $end.Left + "," + $end.Top)

$bmp2 = New-Object System.Drawing.Bitmap(($end.Right - $end.Left), ($end.Bottom - $end.Top))
$g2 = [System.Drawing.Graphics]::FromImage($bmp2)
$g2.CopyFromScreen($end.Left, $end.Top, 0, 0, $bmp2.Size, [System.Drawing.CopyPixelOperation]::SourceCopy)
$g2.Dispose()
$bmp2.Save((Join-Path $OutDir "drag-end.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$bmp2.Dispose()
Write-Output "SAVED drag-mid.png / drag-end.png"
