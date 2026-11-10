param([string]$Exe = "D:\Window Word\src\WordDrawer.App\bin\Debug\net8.0-windows\WordDrawer.App.exe")

$ErrorActionPreference = "Stop"

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class P32 {
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
[P32]::SetThreadDpiAwarenessContext([IntPtr](-4)) | Out-Null

function Report([string]$label, [string]$dbPath) {
    $env:WORDDRAWER_DATA_PATH = $dbPath
    $proc = Start-Process -FilePath $Exe -PassThru
    Start-Sleep -Milliseconds 5000

    $w = 0; $h = 0
    $hwnd = [P32]::Largest([uint32]$proc.Id, [ref]$w, [ref]$h)
    $r = New-Object P32+RECT
    [P32]::GetWindowRect($hwnd, [ref]$r) | Out-Null

    # park the pointer on the panel so a docked drawer does not auto-hide mid-measurement
    [P32]::SetCursorPos([int](($r.Left + $r.Right) / 2), [int](($r.Top + $r.Bottom) / 2)) | Out-Null
    Start-Sleep -Milliseconds 900
    [P32]::GetWindowRect($hwnd, [ref]$r) | Out-Null

    Write-Output ("$label -> window at " + $r.Left + "," + $r.Top + " size " + ($r.Right - $r.Left) + "x" + ($r.Bottom - $r.Top))
    Stop-Process -Id $proc.Id -Force
    Start-Sleep -Milliseconds 500
}

Report "DEFAULT" "D:\Window Word\output\verify\place-default.db"
Report "FREE_700_300" "D:\Window Word\output\verify\place-free.db"
