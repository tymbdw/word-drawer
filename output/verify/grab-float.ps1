param(
    [string]$Exe = "D:\Window Word\src\WordDrawer.App\bin\Debug\net8.0-windows\WordDrawer.App.exe",
    [string]$Db = "D:\Window Word\output\verify\place-free.db",
    [string]$Out = "D:\Window Word\output\wpf\float-look.png"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class F32 {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr c);
    public static IntPtr Largest(uint target, out int w, out int h) {
        IntPtr best = IntPtr.Zero; int area = 0; int bw = 0, bh = 0;
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
[F32]::SetThreadDpiAwarenessContext([IntPtr](-4)) | Out-Null

$env:WORDDRAWER_DATA_PATH = $Db
$proc = Start-Process -FilePath $Exe -PassThru
Start-Sleep -Milliseconds 5200

$w = 0; $h = 0
$hwnd = [F32]::Largest([uint32]$proc.Id, [ref]$w, [ref]$h)
$r = New-Object F32+RECT
[F32]::GetWindowRect($hwnd, [ref]$r) | Out-Null
Write-Output ("panel window at " + $r.Left + "," + $r.Top + " " + ($r.Right - $r.Left) + "x" + ($r.Bottom - $r.Top))

Start-Sleep -Milliseconds 400
$bmp = New-Object System.Drawing.Bitmap(($r.Right - $r.Left), ($r.Bottom - $r.Top))
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($r.Left, $r.Top, 0, 0, $bmp.Size, [System.Drawing.CopyPixelOperation]::SourceCopy)
$g.Dispose()
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output ("SAVED " + $Out)

Stop-Process -Id $proc.Id -Force
