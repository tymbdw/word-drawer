param([string]$Out = "D:\Window Word\output\wpf\live-now.png")

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class G32 {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr c);

    public static IntPtr Pick(out RECT rect) {
        IntPtr best = IntPtr.Zero; int area = 0; RECT br = new RECT();
        EnumWindows((hh, l) => {
            uint pid; GetWindowThreadProcessId(hh, out pid);
            if (!IsWindowVisible(hh)) return true;
            RECT r; GetWindowRect(hh, out r);
            int a = (r.Right - r.Left) * (r.Bottom - r.Top);
            if (a > area) { area = a; best = hh; br = r; }
        }, IntPtr.Zero);
        rect = br;
        return best;
    }
}
"@
[G32]::SetThreadDpiAwarenessContext([IntPtr](-4)) | Out-Null

$procs = Get-Process WordDrawer.App -ErrorAction SilentlyContinue
if (-not $procs) { Write-Output "NOT RUNNING"; exit 1 }

[G32+RECT]$r = New-Object G32+RECT
$hwnd = [G32]::Pick([ref]$r)
$w = $r.Right - $r.Left
$h = $r.Bottom - $r.Top
$bmp = New-Object System.Drawing.Bitmap($w, $h)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($r.Left, $r.Top, 0, 0, (New-Object System.Drawing.Size($w, $h)), [System.Drawing.CopyPixelOperation]::SourceCopy)
$g.Dispose()
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output ("SAVED " + $Out + " " + $w + "x" + $h + " at " + $r.Left + "," + $r.Top)
