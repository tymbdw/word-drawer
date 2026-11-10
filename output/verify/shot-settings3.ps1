param(
    [string]$Exe = "D:\Window Word\src\WordDrawer.App\bin\Debug\net8.0-windows\WordDrawer.App.exe",
    [string]$OutDir = "D:\Window Word\output\wpf"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class S32 {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr c);
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
[S32]::SetThreadDpiAwarenessContext([IntPtr](-4)) | Out-Null

$proc = Start-Process -FilePath $Exe -PassThru
Start-Sleep -Milliseconds 5500

[S32+RECT]$r = New-Object S32+RECT
$hwnd = [S32]::Largest([uint32]$proc.Id, [ref]$r)
[S32]::SetForegroundWindow($hwnd) | Out-Null
[S32]::SetCursorPos(($r.Left + 200), ($r.Top + 300)) | Out-Null
Start-Sleep -Milliseconds 700

$root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
$buttons = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
$candidates = @()
foreach ($el in $buttons) {
    if ($el.Current.ControlType.ProgrammaticName -ne "ControlType.Button") { continue }
    $b = $el.Current.BoundingRectangle
    Write-Output ("button '" + $el.Current.Name + "' at " + [int]$b.Left + "," + [int]$b.Top + " " + [int]$b.Width + "x" + [int]$b.Height)
    if ($b.Top -lt ($r.Top + 160) -and $b.Width -gt 0) { $candidates += ,@($b.Left, $el) }
}

if ($candidates.Count -eq 0) { Write-Output "NO HEADER BUTTON"; exit 1 }
$pick = $candidates | Sort-Object { $_[0] } -Descending | Select-Object -First 1
Write-Output ("invoking header button at x=" + [int]$pick[0])
$pick[1].GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
Start-Sleep -Milliseconds 1000

$bmp = New-Object System.Drawing.Bitmap(($r.Right - $r.Left), ($r.Bottom - $r.Top))
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($r.Left, $r.Top, 0, 0, $bmp.Size, [System.Drawing.CopyPixelOperation]::SourceCopy)
$g.Dispose()
$bmp.Save((Join-Path $OutDir "settings-verify.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output "SAVED settings-verify.png"
