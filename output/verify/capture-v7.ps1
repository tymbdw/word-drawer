param(
    [string]$Exe = "D:\Window Word\src\WordDrawer.App\bin\Debug\net8.0-windows\WordDrawer.App.exe",
    [string]$OutDir = "D:\Window Word\output\wpf",
    [string]$DbPath = "D:\Window Word\output\verify\v13.db",
    [int]$WarmupMs = 3600,
    [string]$Tag = "v13"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class WC7 {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr c);
    [DllImport("shcore.dll")] public static extern int SetProcessDpiAwareness(int v);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    public static readonly IntPtr TOPMOST = new IntPtr(-1);
    public static readonly IntPtr NOTOPMOST = new IntPtr(-2);
    public const uint NOMOVE = 0x0002;
    public const uint NOSIZE = 0x0001;

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

[WC7]::Dpi()

if (Test-Path $DbPath) { Remove-Item $DbPath -Force }
New-Item -ItemType Directory -Force -Path (Split-Path $DbPath) | Out-Null
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# ---- fake document backdrop with plenty of high-frequency detail ----
$bw = 700
$bh = 940
$back = New-Object System.Drawing.Bitmap($bw, $bh, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($back)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

$rectAll = New-Object System.Drawing.Rectangle(0, 0, $bw, $bh)
$grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rectAll, [System.Drawing.Color]::FromArgb(255,205,219,226), [System.Drawing.Color]::FromArgb(255,158,176,191), 45.0)
$g.FillRectangle($grad, $rectAll)
$grad.Dispose()

$panel = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(240,252,253,255))
$g.FillRectangle($panel, 55, 70, 590, 800)
$panel.Dispose()

$penLine = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,40,70,95), 1)
$g.DrawRectangle($penLine, 55, 70, 590, 800)
$penLine.Dispose()

$titleFont = New-Object System.Drawing.Font("Microsoft YaHei", 20, [System.Drawing.FontStyle]::Bold)
$bodyFont = New-Object System.Drawing.Font("Microsoft YaHei", 12)
$monoFont = New-Object System.Drawing.Font("Consolas", 13)
$dark = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,24,38,51))
$mid = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,70,95,115))

$g.DrawString("Vocabulary Review Notes 2027", $titleFont, $dark, 80, 96)
$lines = @(
    "abandon v. give up      abstract adj. not concrete",
    "accumulate v. to gather  acknowledge v. to admit",
    "adequate adj. sufficient  advocate v. to support",
    "ambiguous adj. unclear    anticipate v. to expect",
    "arbitrary adj. random     assess v. to evaluate",
    "assume v. to suppose      attribute v. to ascribe"
)
$y = 150
foreach ($line in $lines) {
    $g.DrawString($line, $bodyFont, $dark, 80, $y)
    $y += 34
}

$g.DrawString("Daily plan 50 words   completed 1,248", $bodyFont, $mid, 80, 380)
$g.DrawString("01  02  03  04  05  06  07", $monoFont, $mid, 80, 420)

$chip = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,41,153,214))
$g.FillRectangle($chip, 80, 470, 120, 44)
$chip.Dispose()
$chip2 = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,232,138,72))
$g.FillRectangle($chip2, 216, 470, 120, 44)
$chip2.Dispose()

$rule = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,120,150,170), 1)
for ($i = 0; $i -lt 8; $i++) {
    $g.DrawLine($rule, 80, (560 + $i * 30), (600 - ($i % 3) * 60), (560 + $i * 30))
}
$rule.Dispose()

$g.Dispose()

$wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$wantX = $wa.Right - 540
$wantY = $wa.Top + [int][Math]::Max(18, (($wa.Height - 780) / 2))
$fx = [Math]::Max(0, $wantX - 80)
$fy = [Math]::Max(0, $wantY - 100)

$form = New-Object System.Windows.Forms.Form
$form.FormBorderStyle = "None"
$form.StartPosition = "Manual"
$form.Bounds = New-Object System.Drawing.Rectangle($fx, $fy, $bw, $bh)
$form.BackgroundImage = $back
$form.BackgroundImageLayout = "Stretch"
$form.ShowInTaskbar = $false
$form.TopMost = $true
$form.Show()
$form.Activate()
[System.Windows.Forms.Application]::DoEvents()
Start-Sleep -Milliseconds 600

# reference: the same rectangle with nothing on top of it
$refBmp = New-Object System.Drawing.Bitmap(540, 780)
$rg = [System.Drawing.Graphics]::FromImage($refBmp)
$rg.CopyFromScreen($wantX, $wantY, 0, 0, (New-Object System.Drawing.Size(540, 780)), [System.Drawing.CopyPixelOperation]::SourceCopy)
$rg.Dispose()
$refPath = Join-Path $OutDir ($Tag + "-backdrop-sharp.png")
$refBmp.Save($refPath, [System.Drawing.Imaging.ImageFormat]::Png)
$refBmp.Dispose()

$env:WORDDRAWER_DATA_PATH = $DbPath
Start-Sleep -Milliseconds 200
$proc = Start-Process -FilePath $Exe -PassThru
Start-Sleep -Milliseconds $WarmupMs
$proc.Refresh()
if ($proc.HasExited) { throw "exited $($proc.ExitCode)" }

$w = 0; $h = 0
$hwnd = [WC7]::Largest([uint32]$proc.Id, [ref]$w, [ref]$h)
if ($hwnd -eq [IntPtr]::Zero) { throw "no window" }

[WC7]::SetWindowPos($hwnd, [WC7]::TOPMOST, 0, 0, 0, 0, ([WC7]::NOMOVE -bor [WC7]::NOSIZE)) | Out-Null
[WC7]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 250

$r = New-Object WC7+RECT
[WC7]::GetWindowRect($hwnd, [ref]$r) | Out-Null
$w = $r.Right - $r.Left; $h = $r.Bottom - $r.Top
Write-Output ("window " + $w + "x" + $h + " at " + $r.Left + "," + $r.Top)

[WC7]::SetCursorPos(($r.Left + [int]($w / 2)), ($r.Top + [int]($h / 2))) | Out-Null
Start-Sleep -Milliseconds 900

[WC7]::GetWindowRect($hwnd, [ref]$r) | Out-Null
$w = $r.Right - $r.Left; $h = $r.Bottom - $r.Top
$shot = New-Object System.Drawing.Bitmap($w, $h)
$sg = [System.Drawing.Graphics]::FromImage($shot)
$sg.CopyFromScreen($r.Left, $r.Top, 0, 0, (New-Object System.Drawing.Size($w, $h)), [System.Drawing.CopyPixelOperation]::SourceCopy)
$sg.Dispose()
$shotPath = Join-Path $OutDir ($Tag + "-real.png")
$shot.Save($shotPath, [System.Drawing.Imaging.ImageFormat]::Png)
$shot.Dispose()

[WC7]::SetWindowPos($hwnd, [WC7]::NOTOPMOST, 0, 0, 0, 0, ([WC7]::NOMOVE -bor [WC7]::NOSIZE)) | Out-Null
[WC7]::SetCursorPos(150, 150) | Out-Null
Stop-Process -Id $proc.Id -Force
Start-Sleep -Milliseconds 400
$form.Close(); $form.Dispose(); $back.Dispose()
Write-Output ("SAVED " + $refPath)
Write-Output ("SAVED " + $shotPath)
