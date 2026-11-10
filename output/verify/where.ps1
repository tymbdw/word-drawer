Add-Type -AssemblyName System.Windows.Forms

Add-Type -TypeDefinition @"
using System;
using System.Text;
using System.Runtime.InteropServices;

public class WinDump {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr c);

    public static string Dump(uint target) {
        try { SetThreadDpiAwarenessContext(new IntPtr(-4)); } catch {}
        var sb = new StringBuilder();
        EnumWindows((h, l) => {
            uint pid; GetWindowThreadProcessId(h, out pid);
            if (pid == target && IsWindowVisible(h)) {
                RECT r; GetWindowRect(h, out r);
                sb.AppendLine("window " + (r.Right - r.Left) + "x" + (r.Bottom - r.Top) + " at " + r.Left + "," + r.Top);
            }
            return true;
        }, IntPtr.Zero);
        return sb.ToString();
    }
}
"@

$p = Get-Process WordDrawer.App -ErrorAction SilentlyContinue
if (-not $p) { Write-Output "not running"; exit }
Write-Output ("pid=" + $p.Id + " responding=" + $p.Responding)
Write-Output ([WinDump]::Dump([uint32]$p.Id))

$wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
Write-Output ("primary work area " + $wa.Width + "x" + $wa.Height + " at " + $wa.X + "," + $wa.Y)
Write-Output ("expected docked position: x=" + ($wa.Right - 540) + " y=" + ($wa.Y + [Math]::Max(18, [int](($wa.Height - 780) / 2))))

foreach ($s in [System.Windows.Forms.Screen]::AllScreens) {
    Write-Output ("screen " + $s.DeviceName + " " + $s.Bounds.Width + "x" + $s.Bounds.Height + " primary=" + $s.Primary)
}
