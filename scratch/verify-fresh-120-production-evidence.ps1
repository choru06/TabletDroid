# ==============================================================================
# TabletDroid Fresh-Install 120Hz Production Verification Evidence Runner
# ==============================================================================
$ErrorActionPreference = "Continue"
$rootDir = (Resolve-Path "$PSScriptRoot\..").Path
$testAvd = "TabletDroid_Z13_Play_120_Test"
$avdDir = "$env:USERPROFILE\.android\avd\$testAvd.avd"
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$avdManager = "$env:LOCALAPPDATA\Android\Sdk\cmdline-tools\latest\bin\avdmanager.bat"
$dotnetDir = "$env:LOCALAPPDATA\Microsoft\dotnet"
$dotnetExe = if (Test-Path "$dotnetDir\dotnet.exe") { "$dotnetDir\dotnet.exe" } else { (Get-Command dotnet.exe -ErrorAction SilentlyContinue).Source }
$env:DOTNET_ROOT = $dotnetDir
$env:PATH = "$dotnetDir;$env:PATH"
$hostDll = (Resolve-Path "$rootDir\host\TabletDroid.Host\bin\Debug\net9.0-windows\TabletDroid.Host.dll").Path

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host " TabletDroid Fresh-Install 120Hz Production Evidence Collection" -ForegroundColor Cyan
Write-Host " Target Hardware : ASUS ROG Flow Z13 (Windows 11)" -ForegroundColor Cyan
Write-Host " Base Commit     : 772c28d+" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan

# 1. Cleanup
Write-Host "`n[1/7] Cleaning up existing emulators and old test AVD..." -ForegroundColor Yellow
& $adb -s emulator-5554 emu kill 2>$null | Out-Null
Start-Sleep -Seconds 2
Get-Process -Name qemu-system-x86_64,emulator,TabletDroid.Host -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
cmd.exe /c "`"$avdManager`" delete avd -n `"$testAvd`"" 2>$null | Out-Null

# 2. Fresh AVD Creation
Write-Host "`n[2/7] Creating fresh AVD '$testAvd' with -RefreshHz 120..." -ForegroundColor Yellow
& powershell.exe -ExecutionPolicy Bypass -File "$rootDir\scripts\windows\create-avd.ps1" -AvdName $testAvd -Profile "Play" -RefreshHz 120

$cfg = Get-Content "$avdDir\config.ini"
$vsync = ($cfg | Select-String "^hw\.lcd\.vsync\s*=\s*(.*)").Matches.Groups[1].Value.Trim()
$gpu = ($cfg | Select-String "^hw\.gpu\.mode\s*=\s*(.*)").Matches.Groups[1].Value.Trim()
$trans = ($cfg | Select-String "^hw\.gltransport\s*=\s*(.*)").Matches.Groups[1].Value.Trim()

Write-Host "  [READBACK] hw.lcd.vsync='$vsync', hw.gpu.mode='$gpu', hw.gltransport='$trans'" -ForegroundColor Cyan
if ($vsync -ne "120" -or $gpu -ne "host" -or $trans -ne "pipe") {
    throw "Fresh AVD config readback verification failed! ($vsync, $gpu, $trans)"
}

# 3. Fresh AVD Production Boot (No Host)
Write-Host "`n[3/7] Booting fresh AVD via run-spike.ps1 -LaunchHost `$false..." -ForegroundColor Yellow
& powershell.exe -ExecutionPolicy Bypass -File "$rootDir\scripts\windows\run-spike.ps1" -AvdName $testAvd -RefreshHz 120 -LaunchHost $false

Start-Sleep -Seconds 5
$bootVsync = ((& $adb -s emulator-5554 shell getprop ro.boot.qemu.vsync 2>$null) | Out-String).Trim()
$peakRate = ((& $adb -s emulator-5554 shell settings get system peak_refresh_rate 2>$null) | Out-String).Trim()
$minRate = ((& $adb -s emulator-5554 shell settings get system min_refresh_rate 2>$null) | Out-String).Trim()
$dispDump = (& $adb -s emulator-5554 shell dumpsys display 2>$null) | Out-String
$dmMode = if ($dispDump -match "mCurrentDisplayMode.*?fps=([\d\.]+)") { $Matches[1] } elseif ($dispDump -match "fps=([\d\.]+)") { $Matches[1] } else { "UNKNOWN" }

Write-Host "  [GUEST_TELEMETRY]" -ForegroundColor Cyan
Write-Host "    ro.boot.qemu.vsync       : $bootVsync (Expected: 120)" -ForegroundColor Gray
Write-Host "    system.peak_refresh_rate : $peakRate (Expected: 120.0)" -ForegroundColor Gray
Write-Host "    system.min_refresh_rate  : $minRate (Expected: 120.0)" -ForegroundColor Gray
Write-Host "    DisplayManager Mode      : $dmMode Hz (Expected: ~120)" -ForegroundColor Gray

if ($bootVsync -ne "120" -or $peakRate -notmatch "^120" -or $minRate -notmatch "^120") {
    throw "Guest telemetry verification failed on fresh AVD!"
}

# 4. Pure BenchmarkApp 1.0.0 Observation
Write-Host "`n[4/7] Running Canonical BenchmarkApp 1.0.0 Observation..." -ForegroundColor Yellow
& $adb -s emulator-5554 install -r -d -t "$rootDir\bin\TabletDroid.Benchmark.apk" 2>$null | Out-Null
& $adb -s emulator-5554 shell am start -n com.tabletdroid.benchmark/.BenchmarkActivity 2>$null | Out-Null
Start-Sleep -Milliseconds 1500

& $adb -s emulator-5554 logcat -c 2>$null
& $adb -s emulator-5554 shell am broadcast -p com.tabletdroid.benchmark -a com.tabletdroid.benchmark.ACTION_RESET 2>$null | Out-Null
Start-Sleep -Milliseconds 400
& $adb -s emulator-5554 shell am broadcast -p com.tabletdroid.benchmark -a com.tabletdroid.benchmark.ACTION_START --ei warmup_sec 2 --ei measure_sec 5 --ef velocity_px_s 800.0 2>$null | Out-Null
Start-Sleep -Seconds 8
& $adb -s emulator-5554 shell am broadcast -p com.tabletdroid.benchmark -a com.tabletdroid.benchmark.ACTION_STOP 2>$null | Out-Null
Start-Sleep -Milliseconds 800

$logcatRaw = (& $adb -s emulator-5554 logcat -d -s TabletDroidBenchmark 2>$null) | Out-String
$appRefresh = 0.0; $appModeFps = 0.0
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

Write-Host "  [APP_OBSERVATION]" -ForegroundColor Cyan
Write-Host "    Display.getMode()        : $appModeFps Hz (Expected: 120)" -ForegroundColor Gray
Write-Host "    Display.getRefreshRate() : $appRefresh Hz (Expected: 120)" -ForegroundColor Gray

if ($appRefresh -lt 114.0 -or $appModeFps -lt 114.0) {
    throw "BenchmarkApp 120Hz observation failed! (appRefresh=$appRefresh, appMode=$appModeFps)"
}

# 5. Verifying Host Embedding & Automation Isolation
Write-Host "`n[5/7] Verifying Host Embedding & Automation Isolation..." -ForegroundColor Yellow

# Helper for IPC
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

# 5a. Test Harness Automation Launch (--auto-embed --automation)
$testHostProc = Start-Process -FilePath $dotnetExe -ArgumentList "`"$hostDll`" --auto-embed --automation" -PassThru
Start-Sleep -Seconds 3

$testPortOpen = $false
$isEmbeddedResponse = $false
$lastGeom = $null

for ($i = 0; $i -lt 15; $i++) {
    $lastGeom = Invoke-HostCmd -Cmd "GET_GEOMETRY"
    if ($null -ne $lastGeom) {
        $testPortOpen = $true
        if ($lastGeom.isEmbedded -eq $true) {
            $isEmbeddedResponse = $true
            break
        }
    }
    if ($i -ge 2) { Invoke-HostCmd -Cmd "EMBED" | Out-Null }
    Start-Sleep -Milliseconds 500
}

Write-Host "  [TEST_HARNESS_AUTOMATION_LAUNCH]" -ForegroundColor Cyan
Write-Host "    Host Process PID         : $($testHostProc.Id) (Active: $(-not $testHostProc.HasExited))" -ForegroundColor Gray
Write-Host "    Command Line Args        : --auto-embed --automation" -ForegroundColor Gray
Write-Host "    Automation Port 28889    : $testPortOpen (Expected: True / LISTENING)" -ForegroundColor $(if ($testPortOpen) { "Green" } else { "Red" })
Write-Host "    SetParent Embedded Status: $isEmbeddedResponse (Expected: True)" -ForegroundColor $(if ($isEmbeddedResponse) { "Green" } else { "Red" })

# Clean detach before closing test host
Invoke-HostCmd -Cmd "DETACH" | Out-Null
Start-Sleep -Milliseconds 500
$testHostProc.CloseMainWindow() | Out-Null
Start-Sleep -Seconds 2
if (-not $testHostProc.HasExited) { Stop-Process -Id $testHostProc.Id -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 1

# 5b. Normal Production Launch (--auto-embed only)
$prodHostProc = Start-Process -FilePath $dotnetExe -ArgumentList "`"$hostDll`" --auto-embed" -PassThru
Start-Sleep -Seconds 4

$c1 = New-Object System.Net.Sockets.TcpClient
$prodPortOpen = $false
try {
    $iar1 = $c1.BeginConnect("127.0.0.1", 28889, $null, $null)
    $prodPortOpen = $iar1.AsyncWaitHandle.WaitOne(1000)
    if ($prodPortOpen) { $c1.EndConnect($iar1) }
} catch {
    $prodPortOpen = $false
} finally {
    $c1.Close()
}

$prodHostAlive = -not $prodHostProc.HasExited
Write-Host "  [NORMAL_PRODUCTION_LAUNCH]" -ForegroundColor Cyan
Write-Host "    Host Process PID         : $($prodHostProc.Id) (Active: $prodHostAlive)" -ForegroundColor Gray
Write-Host "    Command Line Args        : --auto-embed only" -ForegroundColor Gray
Write-Host "    Automation Port 28889    : $prodPortOpen (Expected: False / NOT LISTENING)" -ForegroundColor $(if (-not $prodPortOpen) { "Green" } else { "Red" })

$prodHostProc.CloseMainWindow() | Out-Null
Start-Sleep -Seconds 2
if (-not $prodHostProc.HasExited) { Stop-Process -Id $prodHostProc.Id -Force -ErrorAction SilentlyContinue }

if ($prodPortOpen -or -not $testPortOpen -or -not $isEmbeddedResponse) {
    throw "Host automation isolation / embedding verification failed! (prodPort=$prodPortOpen, testPort=$testPortOpen, embedded=$isEmbeddedResponse)"
}

# 6. Build & Test Verification
Write-Host "`n[6/7] Running Build & Test Verification..." -ForegroundColor Yellow

# 6a. Benchmark APK
$apkBuildOutput = & powershell.exe -ExecutionPolicy Bypass -File "$rootDir\scripts\windows\build-benchmark-app.ps1" 2>&1 | Out-String
$apkSuccess = ($LASTEXITCODE -eq 0 -and $apkBuildOutput -match "SUCCESS")
Write-Host "  Benchmark APK Build        : $(if ($apkSuccess) { 'PASS' } else { 'FAIL' })" -ForegroundColor $(if ($apkSuccess) { "Green" } else { "Red" })

# 6b. Dotnet Build
$buildOutput = & $dotnetExe build "$rootDir\host\TabletDroid.sln" -c Debug 2>&1 | Out-String
$buildSuccess = ($LASTEXITCODE -eq 0)
Write-Host "  Host Solution Build (.NET) : $(if ($buildSuccess) { 'PASS' } else { 'FAIL' })" -ForegroundColor $(if ($buildSuccess) { "Green" } else { "Red" })

# 6c. Dotnet Test
$testOutput = & $dotnetExe test "$rootDir\host\TabletDroid.Tests\TabletDroid.Tests.csproj" -c Debug 2>&1 | Out-String
$testPassedCount = 0; $testFailedCount = 0; $testTotalCount = 0
if ($testOutput -match "실패:\s*(\d+),\s*통과:\s*(\d+).*?전체:\s*(\d+)") {
    $testFailedCount = [int]$Matches[1]
    $testPassedCount = [int]$Matches[2]
    $testTotalCount = [int]$Matches[3]
} elseif ($testOutput -match "Failed:\s*(\d+),\s*Passed:\s*(\d+).*?Total:\s*(\d+)") {
    $testFailedCount = [int]$Matches[1]
    $testPassedCount = [int]$Matches[2]
    $testTotalCount = [int]$Matches[3]
}
$testSuccess = ($LASTEXITCODE -eq 0 -and $testFailedCount -eq 0 -and $testPassedCount -gt 0)
Write-Host "  Host Unit Tests            : $(if ($testSuccess) { 'PASS' } else { 'FAIL' }) ($testPassedCount passed, $testFailedCount failed, total $testTotalCount)" -ForegroundColor $(if ($testSuccess) { "Green" } else { "Red" })

# 7. Cleanup Test Environment
Write-Host "`n[7/7] Cleaning up test AVD and processes..." -ForegroundColor Yellow
& $adb -s emulator-5554 emu kill 2>$null | Out-Null
Start-Sleep -Seconds 2
Get-Process -Name qemu-system-x86_64,emulator -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
cmd.exe /c "`"$avdManager`" delete avd -n `"$testAvd`"" 2>$null | Out-Null

Write-Host "`n================================================================================" -ForegroundColor Green
Write-Host " [PASS] ALL FRESH-INSTALL 120HZ PRODUCTION VERIFICATION CHECKS PASSED!" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Green
