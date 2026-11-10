param(
    [string]$Exe = "D:\Window Word\src\WordDrawer.App\bin\Debug\net8.0-windows\WordDrawer.App.exe",
    [string]$DbPath = "D:\Window Word\output\verify\prev.db"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class N32 {
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
[N32]::SetThreadDpiAwarenessContext([IntPtr](-4)) | Out-Null

if (Test-Path $DbPath) { Remove-Item $DbPath -Force }
$env:WORDDRAWER_DATA_PATH = $DbPath
$proc = Start-Process -FilePath $Exe -PassThru
Start-Sleep -Milliseconds 13000

$hwnd = [N32]::Largest([uint32]$proc.Id)
[N32]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 700

$root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)

function Find-ById([string]$id) {
    $cond = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::AutomationIdProperty, $id)
    return $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $cond)
}

function Press([string]$text) {
    $matches = @()
    foreach ($el in $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)) {
        if ($el.Current.ControlType.ProgrammaticName -ne "ControlType.Button") { continue }
        $kids = $el.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
        $names = @()
        foreach ($k in $kids) { if ($k.Current.Name) { $names += $k.Current.Name.Trim() } }
        $hit = ($names -contains $text) -or ($el.Current.Name.Trim() -eq $text)
        if ($hit) { $matches += $el }
    }

    if ($matches.Count -eq 0) {
        Write-Output ("MISSING " + $text)
        return $false
    }

    # the study page has two "←" buttons; the word one sits lower on screen
    $matches[-1].GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
    Start-Sleep -Milliseconds 900
    return $true
}

function Word() {
    $names = @()
    foreach ($el in $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)) {
        if ($el.Current.ControlType.ProgrammaticName -eq "ControlType.Text" -and $el.Current.Name) {
            $names += $el.Current.Name.Trim()
        }
    }
    return ($names -join " / ")
}

Write-Output ("press start: " + (Press "开始学习"))
$w1 = Word
Write-Output ("start           : " + $w1)

Write-Output ("press known: " + (Press "认识"))
$w2 = Word
Write-Output ("after 认识      : " + $w2)

Write-Output ("press left: " + (Press "←"))
$w3 = Word
Write-Output ("after 左箭头    : " + $w3 + "   (should equal first: " + ($w3 -eq $w1) + ")")

Write-Output ("press right: " + (Press "→"))
$w4 = Word
Write-Output ("after 右箭头    : " + $w4)

Stop-Process -Id $proc.Id -Force
Write-Output "done"
