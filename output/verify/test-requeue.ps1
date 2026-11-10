param(
    [string]$Exe = "D:\Window Word\src\WordDrawer.App\bin\Debug\net8.0-windows\WordDrawer.App.exe",
    [string]$DbPath = "D:\Window Word\output\verify\requeue.db"
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
[R32]::SetThreadDpiAwarenessContext([IntPtr](-4)) | Out-Null

if (Test-Path $DbPath) { Remove-Item $DbPath -Force }
$env:WORDDRAWER_DATA_PATH = $DbPath
$proc = Start-Process -FilePath $Exe -PassThru
Start-Sleep -Milliseconds 14000

$hwnd = [R32]::Largest([uint32]$proc.Id)
[R32]::SetForegroundWindow($hwnd) | Out-Null
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
    if ($hits.Count -eq 0) { return $false }
    $hits[-1].GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
    Start-Sleep -Milliseconds 900
    return $true
}

function Snapshot([string]$label) {
    $word = "?"
    $prog = "?"
    $status = ""
    foreach ($el in $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)) {
        if ($el.Current.ControlType.ProgrammaticName -ne "ControlType.Text") { continue }
        $t = $el.Current.Name
        if (-not $t) { continue }
        $t = $t.Trim()
        if ($t -match "^[a-zA-Z][a-zA-Z\-' ]{2,24}$") { $word = $t }
        if ($t -match "^\d+ / \d+$") { $prog = $t }
        if ($t -match "^(不认识|已保存|仅返回|已经是)") { $status = $t }
    }
    Write-Output ("$label -> word=$word  progress=$prog  status=$status")
}

Press "开始学习" | Out-Null
Snapshot "1 start"
Press "不认识" | Out-Null
Snapshot "2 after-unknown"
Press "认识" | Out-Null
Snapshot "3 known-1"
Press "认识" | Out-Null
Snapshot "4 known-2"
Press "认识" | Out-Null
Snapshot "5 known-3"
Press "认识" | Out-Null
Snapshot "6 known-4"

Stop-Process -Id $proc.Id -Force
Write-Output "done"
