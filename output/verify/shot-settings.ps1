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
public class UI2 {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr c);
    [DllImport("shcore.dll")] public static extern int SetProcessDpiAwareness(int v);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    public static void Dpi() {
        try { SetThreadDpiAwarenessContext(new IntPtr(-4)); } catch {}
        try { SetProcessDpiAwareness(2); } catch {}
    }
    public static IntPtr Largest(uint target, out int w, out int h) {
        IntPtr best = IntPtr.Zero; int area = 0; int bw = 0; int bh = 0;
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
[UI2]::Dpi()

$proc = Start-Process -FilePath $Exe -PassThru
Start-Sleep -Milliseconds 4500
$w = 0; $h = 0
$hwnd = [UI2]::Largest([uint32]$proc.Id, [ref]$w, [ref]$h)
[UI2]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 400

function Get-Root { [System.Windows.Automation.AutomationElement]::FromHandle($hwnd) }

function Get-Label($element) {
    $kids = $element.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
    $sb = ""
    foreach ($k in $kids) { if ($k.Current.Name) { $sb += $k.Current.Name + "|" } }
    return $sb
}

function Invoke-Button([string]$text) {
    foreach ($el in (Get-Root).FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)) {
        if ($el.Current.ControlType.ProgrammaticName -ne "ControlType.Button") { continue }
        $segments = (Get-Label $el).Split("|") | ForEach-Object { $_.Trim() }
        if ($segments -contains $text) {
            $el.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
            Start-Sleep -Milliseconds 900
            return $true
        }
    }
    Write-Output ("MISSING " + $text)
    return $false
}

function Save-Shot([string]$name) {
    $r = New-Object UI2+RECT
    [UI2]::GetWindowRect($hwnd, [ref]$r) | Out-Null
    $width = $r.Right - $r.Left; $height = $r.Bottom - $r.Top
    $bmp = New-Object System.Drawing.Bitmap($width, $height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($r.Left, $r.Top, 0, 0, (New-Object System.Drawing.Size($width, $height)), [System.Drawing.CopyPixelOperation]::SourceCopy)
    $g.Dispose()
    $p = Join-Path $OutDir $name
    $bmp.Save($p, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output ("SAVED " + $p)
}

# the gear is the right-most button in the header row (top ~140px of the window)
$r0 = New-Object UI2+RECT
[UI2]::GetWindowRect($hwnd, [ref]$r0) | Out-Null
$headerButtons = @()
foreach ($el in (Get-Root).FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)) {
    if ($el.Current.ControlType.ProgrammaticName -ne "ControlType.Button") { continue }
    $r = $el.Current.BoundingRectangle
    if ($r.Y -lt ($r0.Top + 140) -and $r.Width -gt 40) { $headerButtons += $el }
}
$gear = $headerButtons | Sort-Object { $_.Current.BoundingRectangle.X } | Select-Object -Last 1
if ($gear) {
    $gear.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
    Start-Sleep -Milliseconds 800
    Write-Output "opened settings"
}

Save-Shot "settings-page.png"
Invoke-Button "夜蓝" | Out-Null
Save-Shot "night-settings.png"
Invoke-Button "←" | Out-Null
Start-Sleep -Milliseconds 600
Save-Shot "night-home.png"
Invoke-Button "冰蓝" | Out-Null
Save-Shot "settings-ice.png"
Invoke-Button "+" | Out-Null
Invoke-Button "左侧" | Out-Null
Start-Sleep -Milliseconds 600
Save-Shot "settings-left.png"

Invoke-Button "←" | Out-Null
Invoke-Button "学习计划" | Out-Null
Save-Shot "plan-page.png"

[UI2]::SetCursorPos(150, 150) | Out-Null
Stop-Process -Id $proc.Id -Force
Start-Sleep -Milliseconds 400
Write-Output "done"
