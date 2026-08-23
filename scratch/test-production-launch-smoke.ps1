# Production launch smoke verification
$ErrorActionPreference = "Continue"
$rootDir = (Resolve-Path "$PSScriptRoot\..").Path
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Production Launch Smoke Verification (120Hz & Host Embed)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Run run-spike.ps1 (-RefreshHz 120 -LaunchHost $true)
Write-Host "[1/4] Running run-spike.ps1 -RefreshHz 120 -LaunchHost `$true..." -ForegroundColor Yellow
& powershell.exe -ExecutionPolicy Bypass -File "$rootDir\scripts\windows\run-spike.ps1" -RefreshHz 120 -LaunchHost $true
Start-Sleep -Seconds 4

# 2. Verify Host is running and embedded
Write-Host "`n[2/4] Verifying Host Window & SetParent Embedding via IPC..." -ForegroundColor Yellow
function Invoke-HostCmd {
    param([string]$Cmd)
    $c = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $c.BeginConnect("127.0.0.1", 28889, $null, $null)
        if ($iar.AsyncWaitHandle.WaitOne(3000)) {
            $c.EndConnect($iar)
            $s = $c.GetStream()
            $w = New-Object System.IO.StreamWriter($s, [System.Text.Encoding]::UTF8)
            $w.AutoFlush = $true
            $r = New-Object System.IO.StreamReader($s, [System.Text.Encoding]::UTF8)
            $w.WriteLine($Cmd)
            $resp = $r.ReadLine()
            return ($resp | ConvertFrom-Json)
        }
    } catch {} finally { $c.Close() }
    return $null
}

$geom = $null
for ($i = 0; $i -lt 30; $i++) {
    $geom = Invoke-HostCmd -Cmd "GET_GEOMETRY"
    if ($null -ne $geom -and $geom.isEmbedded -eq $true) { break }
    if ($null -ne $geom -and $geom.isEmbedded -ne $true -and $i -ge 5) {
        Invoke-HostCmd -Cmd "EMBED" | Out-Null
    }
    Start-Sleep -Milliseconds 1000
}

Write-Host "  Host IsEmbedded    : $($geom.isEmbedded)" -ForegroundColor Green
Write-Host "  Embedded HWND      : $($geom.embeddedHwnd)" -ForegroundColor Gray
Write-Host "  Viewport Logical   : $($geom.logicalW)x$($geom.logicalH)" -ForegroundColor Gray
Write-Host "  Viewport Physical  : $($geom.physW)x$($geom.physH)" -ForegroundColor Gray

if ($null -eq $geom -or $geom.isEmbedded -ne $true) {
    throw "Host embedding verification failed!"
}

# 3. Launch BenchmarkApp and query Display.getRefreshRate()
Write-Host "`n[3/4] Launching BenchmarkApp and querying Display.getRefreshRate()..." -ForegroundColor Yellow
& $adb -s emulator-5554 install -r -d -t "$rootDir\bin\TabletDroid.Benchmark.apk" 2>$null | Out-Null
& $adb -s emulator-5554 shell am start -n com.tabletdroid.benchmark/.BenchmarkActivity 2>$null | Out-Null
Start-Sleep -Milliseconds 800
& $adb -s emulator-5554 logcat -c 2>$null
& $adb -s emulator-5554 shell am broadcast -p com.tabletdroid.benchmark -a com.tabletdroid.benchmark.ACTION_GET_STATUS 2>$null | Out-Null
Start-Sleep -Milliseconds 600

$logcatRaw = (& $adb -s emulator-5554 logcat -d -s TabletDroidBenchmark 2>$null) | Out-String
$appRefresh = 0.0
$appModeFps = 0.0
$statusMatches = [regex]::Matches($logcatRaw, 'BENCHMARK_STATUS_JSON:\s*(\{.*\})')
if ($statusMatches.Count -gt 0) {
    for ($i = $statusMatches.Count - 1; $i -ge 0; $i--) {
        try {
            $j = $statusMatches[$i].Groups[1].Value | ConvertFrom-Json
            if ($null -ne $j.appDisplayRefreshRate) { $appRefresh = [double]$j.appDisplayRefreshRate }
            if ($null -ne $j.appModeFps) { $appModeFps = [double]$j.appModeFps }
            if ($appRefresh -gt 0) { break }
        } catch {}
    }
}

Write-Host "  App Display.getMode().getRefreshRate(): ${appModeFps} Hz (Expected: 120)" -ForegroundColor Gray
Write-Host "  App Display.getRefreshRate()          : ${appRefresh} Hz (Expected: 120)" -ForegroundColor Green

if ($appRefresh -lt 114.0) {
    throw "BenchmarkApp Display.getRefreshRate() mismatch! (Observed: ${appRefresh}Hz)"
}

# 4. Clean Shutdown
Write-Host "`n[4/4] Cleaning up Host and Emulator..." -ForegroundColor Yellow
Get-Process -Name TabletDroid.Host,qemu-system-x86_64,emulator -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Write-Host "  [OK] Production launch smoke verified successfully." -ForegroundColor Green
