param([string]$Out = "D:\Window Word\output\wpf\tray-flyout.png")

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class T32 {
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr c);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint f, int dx, int dy, uint d, IntPtr e);
    [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);
    [DllImport("user32.dll")] public static extern IntPtr FindWindow(string cls, string name);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public static void Click(int x, int y) {
        SetCursorPos(x, y);
        mouse_event(0x0002, 0, 0, 0, IntPtr.Zero);
        mouse_event(0x0004, 0, 0, 0, IntPtr.Zero);
    }
}
"@
[T32]::SetThreadDpiAwarenessContext([IntPtr](-4)) | Out-Null

# the overflow chevron sits just left of the notification icons
$screenW = [T32]::GetSystemMetrics(0)
$screenH = [T32]::GetSystemMetrics(1)
$chevronX = $screenW - 452
$chevronY = $screenH - 30
Write-Output ("clicking chevron at " + $chevronX + "," + $chevronY)
[T32]::Click($chevronX, $chevronY)
Start-Sleep -Milliseconds 1200

$w = 900
$h = 700
$x = $screenW - $w
$y = $screenH - $h
$bmp = New-Object System.Drawing.Bitmap($w, $h)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($x, $y, 0, 0, (New-Object System.Drawing.Size($w, $h)), [System.Drawing.CopyPixelOperation]::SourceCopy)
$g.Dispose()
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output ("SAVED " + $Out)

# close the flyout again
[T32]::Click($chevronX, $chevronY)
Start-Sleep -Milliseconds 300
