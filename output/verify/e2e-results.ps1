param(
    [string]$Exe = "D:\Window Word\src\WordDrawer.App\bin\Debug\net8.0-windows\WordDrawer.App.exe",
    [string]$DbPath = "D:\Window Word\output\verify\clock.db"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class R32 {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
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
[R32]::SetThreadDpiAwarenessContext([IntPtr](-4)) | Out-Null

$env:WORDDRAWER_DATA_PATH = $DbPath
$proc = Start-Process -FilePath $Exe -PassThru
Start-Sleep -Milliseconds 6000

$w = 0; $h = 0
$hwnd = [R32]::Largest([uint32]$proc.Id, [ref]$w, [ref]$h)
[R32]::SetForegroundWindow($hwnd) | Out-Null
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
            Start-Sleep -Milliseconds 1200
            return $true
        }
    }
    return $false
}

Press "学习成果" | Out-Null

$root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
$texts = @()
foreach ($el in $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)) {
    if ($el.Current.Name -and $el.Current.ControlType.ProgrammaticName -eq "ControlType.Text") { $texts += $el.Current.Name.Trim() }
}
Write-Output ("TEXTS: " + ($texts -join " | "))

Stop-Process -Id $proc.Id -Force
