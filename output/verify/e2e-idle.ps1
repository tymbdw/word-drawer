param(
    [string]$Exe = "D:\Window Word\src\WordDrawer.App\bin\Debug\net8.0-windows\WordDrawer.App.exe",
    [string]$DbPath = "D:\Window Word\output\verify\clock-idle.db"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class I32 {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr c);
    [DllImport("user32.dll")] public static extern void mouse_event(uint f, int dx, int dy, uint d, IntPtr e);
    public static void Nudge() {
        mouse_event(0x0001, 1, 0, 0, IntPtr.Zero);
        mouse_event(0x0001, -1, 0, 0, IntPtr.Zero);
    }
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
[I32]::SetThreadDpiAwarenessContext([IntPtr](-4)) | Out-Null

if (Test-Path $DbPath) { Remove-Item $DbPath -Force }
$env:WORDDRAWER_DATA_PATH = $DbPath
$env:WORDDRAWER_IDLE_SECONDS = "5"

$proc = Start-Process -FilePath $Exe -PassThru
Start-Sleep -Milliseconds 6000

$w = 0; $h = 0
$hwnd = [I32]::Largest([uint32]$proc.Id, [ref]$w, [ref]$h)
[I32]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 500

function Press([string]$text) {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
    foreach ($el in $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)) {
        if ($el.Current.ControlType.ProgrammaticName -ne "ControlType.Button") { continue }
        $kids = $el.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
        $names = @()
        foreach ($k in $kids) { if ($k.Current.Name) { $names += $k.Current.Name.Trim() } }
        if ($names -contains $text) {
            $el.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
            Start-Sleep -Milliseconds 900
            return $true
        }
    }
    Write-Output ("MISSING " + $text)
    return $false
}

Press "开始学习" | Out-Null
[I32]::Nudge()

# 12 s of real silence: only the first 5 s may count
Start-Sleep -Seconds 12
[I32]::Nudge()
# 3 s of activity after the resume
Start-Sleep -Seconds 3

Press "←" | Out-Null
Start-Sleep -Milliseconds 1500
Stop-Process -Id $proc.Id -Force
Start-Sleep -Milliseconds 300
Write-Output "done"
