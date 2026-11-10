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
public class UIX {
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
[UIX]::Dpi()

$proc = Start-Process -FilePath $Exe -PassThru
Start-Sleep -Milliseconds 4500
$w = 0; $h = 0
$hwnd = [UIX]::Largest([uint32]$proc.Id, [ref]$w, [ref]$h)
[UIX]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 400

function Get-Label($element) {
    $kids = $element.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
    $sb = ""
    foreach ($k in $kids) { if ($k.Current.Name) { $sb += $k.Current.Name + "|" } }
    return $sb
}

function Invoke-Button([string]$text) {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
    foreach ($el in $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)) {
        if ($el.Current.ControlType.ProgrammaticName -ne "ControlType.Button") { continue }
        $segments = (Get-Label $el).Split("|") | ForEach-Object { $_.Trim() }
        if ($segments -contains $text) {
            $el.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
            Start-Sleep -Milliseconds 1000
            return $true
        }
    }
    Write-Output ("MISSING " + $text)
    return $false
}

function Save-Shot([string]$name) {
    $r = New-Object UIX+RECT
    [UIX]::GetWindowRect($hwnd, [ref]$r) | Out-Null
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

Invoke-Button "词书" | Out-Null
Save-Shot "books.png"
Invoke-Button "←" | Out-Null
Start-Sleep -Milliseconds 500
$r = New-Object UIX+RECT
[UIX]::GetWindowRect($hwnd, [ref]$r) | Out-Null
[UIX]::SetCursorPos([int](($r.Right - 40)), [int]($r.Top + 105)) | Out-Null
Start-Sleep -Milliseconds 250
Add-Type -TypeDefinition "using System;using System.Runtime.InteropServices;public class Ck{[DllImport(\"user32.dll\")]public static extern void mouse_event(uint f,int x,int y,uint d,IntPtr e);public static void Click(){mouse_event(2,0,0,0,IntPtr.Zero);mouse_event(4,0,0,0,IntPtr.Zero);}}"
[Ck]::Click()
Start-Sleep -Milliseconds 900
Save-Shot "settings-rebuilt.png"

[UIX]::SetCursorPos(150, 150) | Out-Null
Stop-Process -Id $proc.Id -Force
Start-Sleep -Milliseconds 400
Write-Output "done"
