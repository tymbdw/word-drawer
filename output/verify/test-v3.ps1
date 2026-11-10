param(
    [string]$Exe = "D:\Window Word\src\WordDrawer.App\bin\Debug\net8.0-windows\WordDrawer.App.exe",
    [string]$DbPath = "D:\Window Word\output\verify\v3.db"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class V32 {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int idx);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr c);
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
    public static bool IsTopmost(IntPtr h) { return (GetWindowLong(h, -20) & 0x8) != 0; }
}
"@
[V32]::SetThreadDpiAwarenessContext([IntPtr](-4)) | Out-Null

if (Test-Path $DbPath) { Remove-Item $DbPath -Force }
$env:WORDDRAWER_DATA_PATH = $DbPath
$proc = Start-Process -FilePath $Exe -PassThru
Start-Sleep -Milliseconds 14000

$hwnd = [V32]::Largest([uint32]$proc.Id)
[V32+RECT]$wr = New-Object V32+RECT
[V32]::GetWindowRect($hwnd, [ref]$wr) | Out-Null
Write-Output ("window top: " + $wr.Top)
[V32]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 800
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
    if ($hits.Count -eq 0) { return $false }
    $hits[-1].GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
    Start-Sleep -Milliseconds 900
    return $true
}

Write-Output ("topmost at start : " + [V32]::IsTopmost($hwnd))

# second icon button in the header is the pin
$btns = @()
foreach ($el in $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)) {
    if ($el.Current.ControlType.ProgrammaticName -eq "ControlType.Button" -and $el.Current.BoundingRectangle.Top -lt ($wr.Top + 170)) { $btns += $el }
}
if ($btns.Count -eq 0) { Write-Output "NO HEADER BUTTONS"; Stop-Process -Id $proc.Id -Force; exit 1 }
Write-Output ("header buttons: " + $btns.Count)
$btns[0].GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
Start-Sleep -Milliseconds 900
Write-Output ("topmost after pin : " + [V32]::IsTopmost($hwnd))
$btns[0].GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
Start-Sleep -Milliseconds 900
Write-Output ("topmost after unpin: " + [V32]::IsTopmost($hwnd))

Press "开始学习" | Out-Null
Start-Sleep -Milliseconds 700

function HasMeaning() {
    foreach ($el in $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)) {
        if ($el.Current.ControlType.ProgrammaticName -eq "ControlType.Text" -and $el.Current.Name -match "^(n|v|adj|adv|prep|conj|pron|num|art|int|vt|vi)\.") { return $true }
    }
    return $false
}

Write-Output ("meaning visible before toggle: " + (HasMeaning))
Press "释义" | Out-Null
Write-Output ("meaning visible after toggle : " + (HasMeaning))

Stop-Process -Id $proc.Id -Force
Write-Output "done"
