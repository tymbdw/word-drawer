param([string]$Exe = "D:\词隙\WordDrawer.App.exe")

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class W32 {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr c);
    public static IntPtr Largest(uint target) {
        IntPtr best = IntPtr.Zero; int area = 0;
        EnumWindows((hh, l) => {
            uint pid; GetWindowThreadProcessId(hh, out pid);
            if (pid == target && IsWindowVisible(hh)) { best = hh; area++; }
            return true;
        }, IntPtr.Zero);
        return best;
    }
}
"@
[W32]::SetThreadDpiAwarenessContext([IntPtr](-4)) | Out-Null

$wav = Join-Path $env:TEMP 'worddrawer-speak.wav'
if (Test-Path $wav) { Remove-Item $wav -Force }

$proc = Start-Process -FilePath $Exe -PassThru
Start-Sleep -Milliseconds 9000
$hwnd = [W32]::Largest([uint32]$proc.Id)
[W32]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 600
$root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)

foreach ($el in $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)) {
    if ($el.Current.ControlType.ProgrammaticName -ne "ControlType.Button") { continue }
    $kids = $el.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
    $names = @()
    foreach ($k in $kids) { if ($k.Current.Name) { $names += $k.Current.Name.Trim() } }
    if ($names -contains "开始学习") {
        $el.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
        break
    }
}
Start-Sleep -Milliseconds 1500

[System.Windows.Forms.SendKeys]::SendWait(" ")
Start-Sleep -Milliseconds 3000

if (Test-Path $wav) { Write-Output ("speech wav bytes: " + (Get-Item $wav).Length) } else { Write-Output "NO SPEECH WAV" }
Stop-Process -Id $proc.Id -Force
