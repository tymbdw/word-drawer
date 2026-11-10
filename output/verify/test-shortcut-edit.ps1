param(
    [string]$Exe = "D:\Window Word\src\WordDrawer.App\bin\Debug\net8.0-windows\WordDrawer.App.exe",
    [string]$DbPath = "D:\Window Word\output\verify\keys.db"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class K32 {
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
[K32]::SetThreadDpiAwarenessContext([IntPtr](-4)) | Out-Null

if (Test-Path $DbPath) { Remove-Item $DbPath -Force }
$env:WORDDRAWER_DATA_PATH = $DbPath
$proc = Start-Process -FilePath $Exe -PassThru
Start-Sleep -Milliseconds 14000

[K32+RECT]$wr = New-Object K32+RECT
$hwnd = [K32]::Largest([uint32]$proc.Id, [ref]$wr)
[K32]::SetForegroundWindow($hwnd) | Out-Null
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
    if ($hits.Count -eq 0) { Write-Output ("MISSING " + $text); return $false }
    $hits[-1].GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
    Start-Sleep -Milliseconds 900
    return $true
}

function Labels() {
    $out = @()
    foreach ($el in $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)) {
        if ($el.Current.ControlType.ProgrammaticName -eq "ControlType.Button" -and $el.Current.Name) { $out += $el.Current.Name.Trim() }
        if ($el.Current.ControlType.ProgrammaticName -eq "ControlType.Button") {
            foreach ($k in $el.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)) {
                if ($k.Current.Name) { $out += ("[" + $k.Current.Name.Trim() + "]") }
            }
        }
    }
    return ($out -join " ")
}

# open settings (right-most header button is the close; the gear is second from right)
Press "设置" | Out-Null
Start-Sleep -Milliseconds 500
Write-Output ("settings opened: " + (Labels).Contains("快捷键"))

# scroll to the shortcut row is not needed: buttons exist even when off-screen
Write-Output ("before: " + (Labels))
Press "Right" | Out-Null
Start-Sleep -Milliseconds 400
Write-Output ("after clicking the Right shortcut: " + (Labels))

[System.Windows.Forms.SendKeys]::SendWait("k")
Start-Sleep -Milliseconds 900
Write-Output ("after pressing K: " + (Labels))

Stop-Process -Id $proc.Id -Force
