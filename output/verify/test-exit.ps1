param(
    [string]$Exe = "D:\Window Word\src\WordDrawer.App\bin\Debug\net8.0-windows\WordDrawer.App.exe",
    [string]$DbPath = "D:\Window Word\output\verify\exit.db"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class X32 {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
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
[X32]::SetThreadDpiAwarenessContext([IntPtr](-4)) | Out-Null

if (Test-Path $DbPath) { Remove-Item $DbPath -Force }
$env:WORDDRAWER_DATA_PATH = $DbPath
$proc = Start-Process -FilePath $Exe -PassThru
Start-Sleep -Milliseconds 12000

[X32+RECT]$wr = New-Object X32+RECT
$hwnd = [X32]::Largest([uint32]$proc.Id, [ref]$wr)
[X32]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 700

$root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
$btns = @()
foreach ($el in $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)) {
    if ($el.Current.ControlType.ProgrammaticName -eq "ControlType.Button" -and $el.Current.BoundingRectangle.Top -lt ($wr.Top + 170)) {
        $btns += $el
    }
}
Write-Output ("header buttons: " + $btns.Count)
$btns[$btns.Count - 1].GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
Start-Sleep -Milliseconds 2500

$alive = -not $proc.HasExited
Write-Output ("process alive after close: " + $alive)
if ($alive) { Stop-Process -Id $proc.Id -Force }
Write-Output "done"
