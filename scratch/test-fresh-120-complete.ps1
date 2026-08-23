# Complete Fresh AVD & Production Launch Verification Script
$ErrorActionPreference = "Continue"
$rootDir = (Resolve-Path "$PSScriptRoot\..").Path
$testAvd = "TabletDroid_Z13_Play_120_Test"
$avdDir = "$env:USERPROFILE\.android\avd\$testAvd.avd"
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Complete Fresh AVD & Production Launch Verification" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Clean up any lingering emulators or test AVD
Write-Host "[1/7] Cleaning up existing emulators..." -ForegroundColor Yellow
& $adb -s emulator-5554 emu kill 2>$null | Out-Null
Start-Sleep -Seconds 2
Get-Process -Name qemu-system-x86_64,emulator,TabletDroid.Host -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

$avdManager = "$env:LOCALAPPDATA\Android\Sdk\cmdline-tools\latest\bin\avdmanager.bat"
cmd.exe /c "`"$avdManager`" delete avd -n `"$testAvd`"" 2>$null | Out-Null

# 2. Create fresh AVD with -RefreshHz 120
Write-Host "`n[2/7] Creating fresh AVD '$testAvd' with -RefreshHz 120..." -ForegroundColor Yellow
& powershell.exe -ExecutionPolicy Bypass -File "$rootDir\scripts\windows\create-avd.ps1" -AvdName $testAvd -Profile "Play" -RefreshHz 120

$cfg = Get-Content "$avdDir\config.ini"
$vsync = ($cfg | Select-String "^hw\.lcd\.vsync\s*=\s*(.*)").Matches.Groups[1].Value.Trim()
$gpu = ($cfg | Select-String "^hw\.gpu\.mode\s*=\s*(.*)").Matches.Groups[1].Value.Trim()
$trans = ($cfg | Select-String "^hw\.gltransport\s*=\s*(.*)").Matches.Groups[1].Value.Trim()
Write-Host "  Readback: vsync=$vsync, gpu=$gpu, transport=$trans" -ForegroundColor Gray
if ($vsync -ne "120" -or $gpu -ne "host" -or $trans -ne "pipe") {
    throw "Fresh AVD config readback verification failed!"
}

# 3. Boot fresh AVD via run-spike.ps1 (-LaunchHost $false)
Write-Host "`n[3/7] Booting fresh AVD via run-spike.ps1 -RefreshHz 120 -LaunchHost `$false..." -ForegroundColor Yellow
& powershell.exe -ExecutionPolicy Bypass -File "$rootDir\scripts\windows\run-spike.ps1" -AvdName $testAvd -RefreshHz 120 -LaunchHost $false

# 4. Verify guest properties and display mode
Write-Host "`n[4/7] Verifying guest 120Hz activation & allowing background dexopt to settle..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

$bootVsyncRaw = (& $adb -s emulator-5554 shell getprop ro.boot.qemu.vsync 2>$null)
$bootVsync = if ($bootVsyncRaw) { ($bootVsyncRaw | Out-String).Trim() } else { "UNKNOWN" }
$peakRaw = (& $adb -s emulator-5554 shell settings get system peak_refresh_rate 2>$null)
$peak = if ($peakRaw) { ($peakRaw | Out-String).Trim() } else { "UNKNOWN" }
$minRaw = (& $adb -s emulator-5554 shell settings get system min_refresh_rate 2>$null)
$min = if ($minRaw) { ($minRaw | Out-String).Trim() } else { "UNKNOWN" }
$disp = (& $adb -s emulator-5554 shell dumpsys display 2>$null) | Out-String
$mode = if ($disp -match "mCurrentDisplayMode.*?fps=([\d\.]+)") { $Matches[1] } elseif ($disp -match "fps=([\d\.]+)") { $Matches[1] } else { "UNKNOWN" }

Write-Host "  ro.boot.qemu.vsync      : $bootVsync (Expected: 120)" -ForegroundColor Gray
Write-Host "  system.peak_refresh_rate: $peak (Expected: 120.0)" -ForegroundColor Gray
Write-Host "  system.min_refresh_rate : $min (Expected: 120.0)" -ForegroundColor Gray
Write-Host "  DisplayManager Mode     : $mode Hz (Expected: ~120)" -ForegroundColor Gray

if ($bootVsync -ne "120" -or $peak -notmatch "^120" -or $min -notmatch "^120") {
    throw "Guest telemetry verification failed on fresh AVD!"
}

# 5. BenchmarkApp diagnostic on fresh AVD (2 diagnostic trials)
Write-Host "`n[5/7] Running BenchmarkApp 120Hz diagnostic probe (Trial 1 Prime + Trial 2 Measure)..." -ForegroundColor Yellow
& $adb -s emulator-5554 install -r -d -t "$rootDir\bin\TabletDroid.Benchmark.apk" 2>$null | Out-Null
& $adb -s emulator-5554 shell cmd package compile -m speed com.tabletdroid.benchmark 2>$null | Out-Null
& $adb -s emulator-5554 shell am start -n com.tabletdroid.benchmark/.BenchmarkActivity 2>$null | Out-Null
Start-Sleep -Milliseconds 1500

$bestChoreo = 0.0
$appRefresh = 0.0
$appModeFps = 0.0

for ($t = 1; $t -le 2; $t++) {
    Write-Host "  -> Running Fresh Diagnostic Trial $t/2..." -ForegroundColor Gray
    & $adb -s emulator-5554 logcat -c 2>$null
    & $adb -s emulator-5554 shell am broadcast -p com.tabletdroid.benchmark -a com.tabletdroid.benchmark.ACTION_RESET 2>$null | Out-Null
    Start-Sleep -Milliseconds 400
    & $adb -s emulator-5554 shell am broadcast -p com.tabletdroid.benchmark -a com.tabletdroid.benchmark.ACTION_START --ei warmup_sec 5 --ei measure_sec 15 --ef velocity_px_s 800.0 2>$null | Out-Null
    Start-Sleep -Seconds 22
    & $adb -s emulator-5554 shell am broadcast -p com.tabletdroid.benchmark -a com.tabletdroid.benchmark.ACTION_STOP 2>$null | Out-Null
    Start-Sleep -Milliseconds 800

    $logcatRaw = (& $adb -s emulator-5554 logcat -d -s TabletDroidBenchmark 2>$null) | Out-String
    $statusMatches = [regex]::Matches($logcatRaw, 'BENCHMARK_STATUS_JSON:\s*(\{.*\})')
    if ($statusMatches.Count -gt 0) {
        for ($i = $statusMatches.Count - 1; $i -ge 0; $i--) {
            try {
                $j = $statusMatches[$i].Groups[1].Value | ConvertFrom-Json
                if ($j.status -eq "COMPLETE") {
                    if ($null -ne $j.appDisplayRefreshRate) { $appRefresh = [double]$j.appDisplayRefreshRate }
                    if ($null -ne $j.appModeFps) { $appModeFps = [double]$j.appModeFps }
                    if ($j.elapsedMeasureMs -gt 0 -and $j.measureFrames -gt 0) {
                        $curChoreo = [math]::Round(($j.measureFrames / ($j.elapsedMeasureMs / 1000.0)), 2)
                        Write-Host "     Trial $t Result: AppRefresh=$appRefresh Hz, Choreo=$curChoreo FPS" -ForegroundColor Cyan
                        if ($curChoreo -gt $bestChoreo) { $bestChoreo = $curChoreo }
                        break
                    }
                }
            } catch {}
        }
    }
}

Write-Host "  App Display.getMode().getRefreshRate(): ${appModeFps} Hz" -ForegroundColor Gray
Write-Host "  App Display.getRefreshRate()          : ${appRefresh} Hz" -ForegroundColor Green
Write-Host "  Choreographer Best Cadence            : ${bestChoreo} FPS" -ForegroundColor Green

if ($appRefresh -lt 114.0 -or $bestChoreo -lt 114.0) {
    throw "BenchmarkApp 120Hz probe failed! (appRefresh=$appRefresh, choreo=$bestChoreo)"
}

# 6. Production Host Launch Verification (No --automation flag)
Write-Host "`n[6/7] Testing normal production launch (NO --automation flag)..." -ForegroundColor Yellow
$dotnetDir = "$env:LOCALAPPDATA\Microsoft\dotnet"
$dotnetExe = if (Test-Path "$dotnetDir\dotnet.exe") { "$dotnetDir\dotnet.exe" } else { (Get-Command dotnet.exe -ErrorAction SilentlyContinue).Source }
$env:DOTNET_ROOT = $dotnetDir
$env:PATH = "$dotnetDir;$env:PATH"
$hostDll = (Resolve-Path "$rootDir\host\TabletDroid.Host\bin\Debug\net9.0-windows\TabletDroid.Host.dll").Path

$hostProc = Start-Process -FilePath $dotnetExe -ArgumentList "`"$hostDll`" --auto-embed" -PassThru
Start-Sleep -Seconds 4

# Verify TCP Port 28889 is NOT open (Automation server disabled in production)
$c = New-Object System.Net.Sockets.TcpClient
$portOpen = $false
try {
    $iar = $c.BeginConnect("127.0.0.1", 28889, $null, $null)
    $portOpen = $iar.AsyncWaitHandle.WaitOne(1500)
    if ($portOpen) { $c.EndConnect($iar) }
} catch {
    $portOpen = $false
} finally {
    $c.Close()
}

Write-Host "  Host Process Active (PID: $($hostProc.Id)): $(-not $hostProc.HasExited)" -ForegroundColor Green
Write-Host "  Automation Port 28889 Open: $portOpen (Expected: False in normal production)" -ForegroundColor $(if (-not $portOpen) { "Green" } else { "Red" })

if ($portOpen) {
    throw "Security/Hygiene Issue: Automation port 28889 is open without --automation flag!"
}

# 7. Cleanup
Write-Host "`n[7/7] Cleaning up test emulator and test AVD..." -ForegroundColor Yellow
Stop-Process -Id $hostProc.Id -Force -ErrorAction SilentlyContinue
& $adb -s emulator-5554 emu kill 2>$null | Out-Null
Start-Sleep -Seconds 2
Get-Process -Name qemu-system-x86_64,emulator -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
cmd.exe /c "`"$avdManager`" delete avd -n `"$testAvd`"" 2>$null | Out-Null

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " [PASS] Complete Fresh AVD & Production Launch Verified!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
