param(
    [string]$Exe = "D:\Window Word\src\WordDrawer.App\bin\Debug\net8.0-windows\WordDrawer.App.exe",
    [string]$DbPath = "D:\Window Word\output\verify\e2e.db",
    [string]$Mode = "study",
    [int]$Rounds = 2
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class E2E {
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
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extra);

    public const uint LEFTDOWN = 0x0002;
    public const uint LEFTUP = 0x0004;

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

    public static void Click(int x, int y) {
        SetCursorPos(x, y);
        System.Threading.Thread.Sleep(120);
        mouse_event(LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
        System.Threading.Thread.Sleep(60);
        mouse_event(LEFTUP, 0, 0, 0, UIntPtr.Zero);
    }
}
"@

[E2E]::Dpi()

$env:WORDDRAWER_DATA_PATH = $DbPath
$proc = Start-Process -FilePath $Exe -PassThru
Start-Sleep -Milliseconds 4200

$w = 0; $h = 0
$hwnd = [E2E]::Largest([uint32]$proc.Id, [ref]$w, [ref]$h)
[E2E]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 300

$root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
$all = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)

function Get-Label($element) {
    $texts = $element.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
    $sb = ""
    foreach ($t in $texts) { if ($t.Current.Name) { $sb += $t.Current.Name + "|" } }
    return $sb
}

Write-Output "--- buttons ---"
$targets = @{}
foreach ($el in $all) {
    if ($el.Current.ControlType.ProgrammaticName -ne "ControlType.Button") { continue }
    $label = Get-Label $el
    $r = $el.Current.BoundingRectangle
    Write-Output ("button [" + $label + "] at " + [int]$r.X + "," + [int]$r.Y + " " + [int]$r.Width + "x" + [int]$r.Height)
    foreach ($key in @("开始学习", "去复习", "认识", "不认识", "返回")) {
        if ($label -like "*$key*" -and -not $targets.ContainsKey($key)) {
            $targets[$key] = @{ x = [int]($r.X + $r.Width / 2); y = [int]($r.Y + $r.Height / 2) }
        }
    }
}

function Click-Label([string]$text) {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
    $buttons = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
    foreach ($el in $buttons) {
        if ($el.Current.ControlType.ProgrammaticName -ne "ControlType.Button") { continue }
        $label = Get-Label $el
        $segments = $label.Split("|") | ForEach-Object { $_.Trim() }
        if ($segments -contains $text) {
            $r = $el.Current.BoundingRectangle
            Write-Output ("INVOKE " + $text + " at " + [int]($r.X + $r.Width / 2) + "," + [int]($r.Y + $r.Height / 2))
            $invoke = $el.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
            $invoke.Invoke()
            Start-Sleep -Milliseconds 900
            return $true
        }
    }

    Write-Output ("MISSING BUTTON: " + $text)
    return $false
}

if ($Mode -eq "study") { Click-Label "开始学习" | Out-Null }
if ($Mode -eq "review") { Click-Label "去复习" | Out-Null }

Write-Output "--- after opening the session ---"
$texts = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
$dump = @()
foreach ($t in $texts) { if ($t.Current.Name) { $dump += $t.Current.Name } }
Write-Output ($dump -join " / ")

for ($i = 0; $i -lt $Rounds; $i++) {
    $key = if ($i % 2 -eq 0) { "认识" } else { "不认识" }
    Write-Output ("--- click " + $key + " ---")
    Click-Label $key | Out-Null

    $texts = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
    $dump = @()
    foreach ($t in $texts) { if ($t.Current.Name) { $dump += $t.Current.Name } }
    Write-Output ($dump -join " / ")
}

[E2E]::SetCursorPos(150, 150) | Out-Null
Stop-Process -Id $proc.Id -Force
Start-Sleep -Milliseconds 500
Write-Output "--- done ---"
