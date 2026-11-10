param(
    [string]$Exe = "D:\Window Word\src\WordDrawer.App\bin\Debug\net8.0-windows\WordDrawer.App.exe",
    [string]$DbPath = "D:\Window Word\output\verify\book.db"
)
$ErrorActionPreference = "Stop"
if (Test-Path $DbPath) { Remove-Item $DbPath -Force }
$env:WORDDRAWER_DATA_PATH = $DbPath

$sw = [Diagnostics.Stopwatch]::StartNew()
$proc = Start-Process -FilePath $Exe -PassThru

$deadline = 40
$seeded = $false
while ($sw.Elapsed.TotalSeconds -lt $deadline) {
    Start-Sleep -Milliseconds 250
    if (-not (Test-Path $DbPath)) { continue }
    try {
        Copy-Item $DbPath "$DbPath.probe" -Force
        $count = & powershell.exe -NoProfile -Command "(Get-Item '$DbPath.probe').Length" 2>$null
    } catch { }
    if (Test-Path "$DbPath.probe") { Remove-Item "$DbPath.probe" -Force -ErrorAction SilentlyContinue }
    $seeded = $true
    break
}

Start-Sleep -Seconds 6
$sw.Stop()
Write-Output ("app started in " + [int]$sw.Elapsed.TotalSeconds + "s, pid=" + $proc.Id)
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500
Write-Output "done"
