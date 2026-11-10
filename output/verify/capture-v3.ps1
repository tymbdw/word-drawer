param(
    [string]$Exe = "D:\Window Word\src\WordDrawer.App\bin\Debug\net8.0-windows\WordDrawer.App.exe",
    [string]$RefPng = "D:\Window Word\output\playwright\refined-buttons.png",
    [string]$OutDir = "D:\Window Word\output\wpf",
    [string]$DbPath = "D:\Window Word\output\verify\v3-home.db",
    [int]$WarmupMs = 3400
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public class WinCap3 {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }

    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr ctx);
    [DllImport("shcore.dll")] public static extern int SetProcessDpiAwareness(int value);
    [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr hWnd);

    public static void MakeDpiAware() {
        try { SetThreadDpiAwarenessContext(new IntPtr(-4)); } catch {}
        try { SetProcessDpiAwareness(2); } catch {}
    }

    public static List<IntPtr> WindowsOf(uint targetPid) {
        var found = new List<IntPtr>();
        EnumWindows((h, l) => {
            uint pid; GetWindowThreadProcessId(h, out pid);
            if (pid == targetPid && IsWindowVisible(h)) found.Add(h);
            return true;
        }, IntPtr.Zero);
        return found;
    }

    public static IntPtr LargestOf(uint targetPid, out int w, out int h) {
        IntPtr best = IntPtr.Zero; int bestArea = 0; w = 0; h = 0;
        foreach (var win in WindowsOf(targetPid)) {
            RECT r; GetWindowRect(win, out r);
            int area = (r.Right - r.Left) * (r.Bottom - r.Top);
            if (area > bestArea) { bestArea = area; best = win; w = r.Right - r.Left; h = r.Bottom - r.Top; }
        }
        return best;
    }
}
"@

[WinCap3]::MakeDpiAware()

if (Test-Path $DbPath) { Remove-Item $DbPath -Force }
New-Item -ItemType Directory -Force -Path (Split-Path $DbPath) | Out-Null
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# --- sample the prototype backdrop colours ---
$ref = [System.Drawing.Bitmap]::FromFile($RefPng)
$c1 = $ref.GetPixel(6, 6)
$c2 = $ref.GetPixel($ref.Width - 7, $ref.Height - 7)
$c3 = $ref.GetPixel([int]($ref.Width / 2), 470)
Write-Output ("prototype bg top-left=" + $c1 + " bottom-right=" + $c2 + " bottom-mid=" + $c3)
$ref.Dispose()

# --- build a matching backdrop image ---
$bw = 680
$bh = 900
$back = New-Object System.Drawing.Bitmap($bw, $bh, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$bg = [System.Drawing.Graphics]::FromImage($back)
$rectF = New-Object System.Drawing.Rectangle(0, 0, $bw, $bh)
$grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rectF, $c1, $c2, 45.0)
$bg.FillRectangle($grad, $rectF)
$bg.Dispose()

$wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$drawerTop = $wa.Top + [int][Math]::Max(12, (($wa.Height - 520) / 2))
$drawerLeft = $wa.Right - 540
$fx = [Math]::Max(0, $drawerLeft - 70)
$fy = [Math]::Max(0, $drawerTop - 80)

$form = New-Object System.Windows.Forms.Form
$form.FormBorderStyle = "None"
$form.StartPosition = "Manual"
$form.Bounds = New-Object System.Drawing.Rectangle($fx, $fy, $bw, $bh)
$form.BackgroundImage = $back
$form.BackgroundImageLayout = "Stretch"
$form.ShowInTaskbar = $false
$form.TopMost = $false
$form.Show()
[System.Windows.Forms.Application]::DoEvents()
Start-Sleep -Milliseconds 250

$env:WORDDRAWER_DATA_PATH = $DbPath
$proc = Start-Process -FilePath $Exe -PassThru
Write-Output ("PID=" + $proc.Id)
Start-Sleep -Milliseconds $WarmupMs
$proc.Refresh()
if ($proc.HasExited) { throw "exited: $($proc.ExitCode)" }

$w = 0; $h = 0
$hwnd = [WinCap3]::LargestOf([uint32]$proc.Id, [ref]$w, [ref]$h)
if ($hwnd -eq [IntPtr]::Zero) { throw "no window" }
$rect = New-Object WinCap3+RECT
[WinCap3]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
$w = $rect.Right - $rect.Left; $h = $rect.Bottom - $rect.Top
Write-Output ("window " + $w + "x" + $h + " at " + $rect.Left + "," + $rect.Top + " dpiScale=" + ([WinCap3]::GetDpiForWindow($hwnd) / 96.0))

[WinCap3]::SetCursorPos(($rect.Left + [int]($w / 2)), ($rect.Top + [int]($h / 2))) | Out-Null
Start-Sleep -Milliseconds 350
[WinCap3]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 800

[WinCap3]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
$w = $rect.Right - $rect.Left; $h = $rect.Bottom - $rect.Top
Write-Output ("after focus " + $w + "x" + $h + " at " + $rect.Left + "," + $rect.Top)

# real composited capture from the screen (true transparency)
$real = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$rg = [System.Drawing.Graphics]::FromImage($real)
$rg.CopyFromScreen($rect.Left, $rect.Top, 0, 0, (New-Object System.Drawing.Size($w, $h)), [System.Drawing.CopyPixelOperation]::SourceCopy)
$rg.Dispose()
$realPath = Join-Path $OutDir "v3-home-real.png"
$real.Save($realPath, [System.Drawing.Imaging.ImageFormat]::Png)
$real.Dispose()

# layered-window capture (structure only, alpha flattened)
$lay = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$lg = [System.Drawing.Graphics]::FromImage($lay)
$lg.Clear([System.Drawing.Color]::Transparent)
$hdc = $lg.GetHdc()
$ok = [WinCap3]::PrintWindow($hwnd, $hdc, 2)
$lg.ReleaseHdc($hdc)
$lg.Dispose()
$layPath = Join-Path $OutDir "v3-home-printwindow.png"
$lay.Save($layPath, [System.Drawing.Imaging.ImageFormat]::Png)
$lay.Dispose()
Write-Output ("PrintWindow=" + $ok)

# --- UIA dump to UTF-8 file ---
try {
    Add-Type -AssemblyName UIAutomationClient
    Add-Type -AssemblyName UIAutomationTypes
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
    $all = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("nodes=" + $all.Count)
    foreach ($el in $all) {
        $ct = $el.Current.ControlType.ProgrammaticName -replace "ControlType\.", ""
        $nm = $el.Current.Name
        $b = $el.Current.BoundingRectangle
        $lines.Add(("{0}`t{1}`tx={2}`ty={3}`tw={4}`th={5}`tenabled={6}" -f $ct, $nm, [int]$b.X, [int]$b.Y, [int]$b.Width, [int]$b.Height, $el.Current.IsEnabled))
    }
    $uiaPath = Join-Path $OutDir "v3-home-uia.txt"
    [System.IO.File]::WriteAllLines($uiaPath, $lines, (New-Object System.Text.UTF8Encoding($false)))
    Write-Output ("UIA " + $uiaPath)
} catch {
    Write-Output ("UIA-ERROR " + $_.Exception.Message)
}

[WinCap3]::SetCursorPos(150, 150) | Out-Null
Stop-Process -Id $proc.Id -Force
Start-Sleep -Milliseconds 400
$form.Close()
$form.Dispose()
$back.Dispose()

Write-Output ("SAVED " + $realPath)
Write-Output ("SAVED " + $layPath)
