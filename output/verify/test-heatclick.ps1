param(
    [string]$Exe = "D:\Window Word\src\WordDrawer.App\bin\Debug\net8.0-windows\WordDrawer.App.exe"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class H32 {
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
    public static void Click(int x, int y) {
        SetCursorPos(x, y);
        mouse_event(2, 0, 0, 0, IntPtr.Zero);
        mouse_event(4, 0, 0, 0, IntPtr.Zero);
    }
    public static IntPtr Largest(uint target) {
        IntPtr best = IntPtr.Zero; int area = 0;
        EnumWindows((hh, l) => {
            uint pid; GetWindowThreadProcessId(hh, out pid);
            if (pid == target && IsWindowVisible(hh)) {
                RECT r; GetWindowRect(hh, out r);
                int a = (r.Right - r.Left) * (r.Bottom - r.Top);
                if (a > area) { area = a; best = hh; }
            }
            return true;
        }, IntPtr.Zero);
        return best;
    }
}
"@
[H32]::SetThreadDpiAwarenessContext([IntPtr](-4)) | Out-Null

$proc = Start-Process -FilePath $Exe -PassThru
Start-Sleep -Milliseconds 8000
$hwnd = [H32]::Largest([uint32]$proc.Id)
[H32]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 700

$root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)

function Press([string]$text) {
    $hits = @()
    foreach ($el in $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)) {
        if ($el.Current.ControlType.ProgrammaticName -ne "ControlType.Button") { continue }
        $kids = $el.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
        $names = @()
        foreach ($k in $kids) { if ($k.Current.Name) { $names += $k.Current.Name.Trim() } }
        if ($names -contains $text) { $hits += $el }
    }
    if ($hits.Count -gt 0) { $hits[-1].GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke(); Start-Sleep -Milliseconds 1200 }
}

Press "学习成果"

function Detail() {
    foreach ($el in $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)) {
        if ($el.Current.ControlType.ProgrammaticName -eq "ControlType.Text" -and $el.Current.Name -like "*词*") {
            if ($el.Current.Name -match "^\d+ 月 \d+ 日") { return $el.Current.Name.Trim() }
        }
    }
    return "<none>"
}

Write-Output ("before click: " + (Detail))

# heatmap cells are small square custom elements
$cells = @()
foreach ($el in $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)) {
    $b = $el.Current.BoundingRectangle
    if ($b.Width -gt 12 -and $b.Width -lt 26 -and [math]::Abs($b.Width - $b.Height) -lt 4) {
        $cells += ,@($b.Left, $b.Top, $b.Width, $el)
    }
}
Write-Output ("cell candidates: " + $cells.Count)

if ($cells.Count -gt 0) {
    $target = $cells | Sort-Object { $_[0] } -Descending | Select-Object -First 3 | Select-Object -Last 1
    $cx = [int]($target[0] + $target[2] / 2)
    $cy = [int]($target[1] + $target[2] / 2)
    Write-Output ("clicking cell at " + $cx + "," + $cy)
    [H32]::Click($cx, $cy)
    Start-Sleep -Milliseconds 900
    Write-Output ("after click: " + (Detail))
}

Stop-Process -Id $proc.Id -Force
