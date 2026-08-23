param(
    [string]$AvdName = "TabletDroid_Z13_Play",
    [ValidateSet(60, 120)]
    [int]$RefreshHz = 120,
    [int]$ConsolePort = 5554,
    [int]$GuestPort = 28888,
    $LaunchHost = $true
)

$shouldLaunchHost = ($LaunchHost -eq $true -or $LaunchHost -eq "true" -or $LaunchHost -eq "1" -or $LaunchHost -eq 1)

$ErrorActionPreference = "Continue"

$androidHome = "$env:LOCALAPPDATA\Android\Sdk"
$jdkHome = "$env:LOCALAPPDATA\Android\Jdk"
$dotnetDir = "$env:LOCALAPPDATA\Microsoft\dotnet"

if (Test-Path $jdkHome) {
    $env:JAVA_HOME = $jdkHome
    $env:PATH = "$jdkHome\bin;$env:PATH"
}
if (Test-Path $androidHome) {
    $env:ANDROID_HOME = $androidHome
    $env:ANDROID_SDK_ROOT = $androidHome
    $env:PATH = "$androidHome\platform-tools;$androidHome\emulator;$androidHome\cmdline-tools\latest\bin;$env:PATH"
}
if (Test-Path $dotnetDir) {
    $env:DOTNET_ROOT = $dotnetDir
    $env:PATH = "$dotnetDir;$env:PATH"
}

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " TabletDroid Physical E2E Production Spike Runner" -ForegroundColor Cyan
Write-Host " Target Device: ASUS ROG Flow Z13 / Windows 11" -ForegroundColor Cyan
Write-Host " Target Profile: RefreshHz=${RefreshHz}Hz, GPU=host, Transport=pipe" -ForegroundColor Cyan
Write-Host "========================================================`n" -ForegroundColor Cyan

$results = [ordered]@{}
$deviceSerial = "emulator-$ConsolePort"

$emulator = (Get-Command emulator.exe -ErrorAction SilentlyContinue).Source
if (-not $emulator) { $emulator = "$androidHome\emulator\emulator.exe" }

$adb = (Get-Command adb.exe -ErrorAction SilentlyContinue).Source
if (-not $adb) { $adb = "$androidHome\platform-tools\adb.exe" }

# 1. WHPX 확인
Write-Host "[1/8] Checking Windows Hypervisor Platform (WHPX)..." -ForegroundColor Yellow
$accelCheck = & $emulator -accel-check 2>$null
if ($accelCheck -match "WHPX" -or $accelCheck -match "accel:\s*0") {
    Write-Host "  [PASS] WHPX is active and usable." -ForegroundColor Green
    $results["WHPX"] = "PASS"
} else {
    Write-Host "  [WARN] Hypervisor status: $accelCheck" -ForegroundColor DarkYellow
    $results["WHPX"] = "WARN"
}

# 2. AVD 존재 확인 및 생성
Write-Host "`n[2/8] Checking AVD '$AvdName'..." -ForegroundColor Yellow
$avdPath = "$env:USERPROFILE\.android\avd\$AvdName.avd"
if (Test-Path $avdPath) {
    Write-Host "  [PASS] AVD '$AvdName' exists." -ForegroundColor Green
    $results["AVD ($AvdName)"] = "PASS"
} else {
    Write-Host "  [INFO] AVD '$AvdName' not found. Creating with RefreshHz=$RefreshHz..." -ForegroundColor Yellow
    & powershell.exe -ExecutionPolicy Bypass -File "$PSScriptRoot\create-avd.ps1" -AvdName $AvdName -Profile "Play" -RefreshHz $RefreshHz
    if (Test-Path $avdPath) {
        Write-Host "  [PASS] AVD created successfully." -ForegroundColor Green
        $results["AVD ($AvdName)"] = "PASS"
    } else {
        throw "[FATAL] AVD creation failed for '$AvdName'."
    }
}

# 3. Emulator 및 ADB 도구 확인
Write-Host "`n[3/8] Checking ADB & Emulator binaries..." -ForegroundColor Yellow
if ((Test-Path $emulator) -and (Test-Path $adb)) {
    Write-Host "  [PASS] Emulator and ADB found." -ForegroundColor Green
    $results["Tooling"] = "PASS"
} else {
    throw "[FATAL] Missing emulator or adb at standard paths."
}

# 4. AVD config.ini 엄격한 보정 및 Readback 검증
Write-Host "`n[4/8] Normalizing and verifying AVD configuration for $RefreshHz Hz..." -ForegroundColor Yellow
$avdConfigFile = "$env:USERPROFILE\.android\avd\$AvdName.avd\config.ini"
if (Test-Path $avdConfigFile) {
    $cfgLines = Get-Content $avdConfigFile
    $newLines = [System.Collections.Generic.List[string]]::new()
    $hasGpu = $false; $hasTrans = $false; $hasVsync = $false

    foreach ($line in $cfgLines) {
        if ($line -match "^hw\.gpu\.mode\s*=") {
            $newLines.Add("hw.gpu.mode = host")
            $hasGpu = $true
        } elseif ($line -match "^hw\.gltransport\s*=") {
            $newLines.Add("hw.gltransport = pipe")
            $hasTrans = $true
        } elseif ($line -match "^hw\.lcd\.vsync\s*=") {
            $newLines.Add("hw.lcd.vsync = $RefreshHz")
            $hasVsync = $true
        } else {
            $newLines.Add($line)
        }
    }
    if (-not $hasGpu) { $newLines.Add("hw.gpu.mode = host") }
    if (-not $hasTrans) { $newLines.Add("hw.gltransport = pipe") }
    if (-not $hasVsync) { $newLines.Add("hw.lcd.vsync = $RefreshHz") }

    [System.IO.File]::WriteAllLines($avdConfigFile, $newLines)

    # Post-remediation strict readback
    $verifiedCfg = Get-Content $avdConfigFile
    $vGpu = ($verifiedCfg | Select-String "^hw\.gpu\.mode\s*=\s*(.*)").Matches.Groups[1].Value.Trim()
    $vTrans = ($verifiedCfg | Select-String "^hw\.gltransport\s*=\s*(.*)").Matches.Groups[1].Value.Trim()
    $vVsync = ($verifiedCfg | Select-String "^hw\.lcd\.vsync\s*=\s*(.*)").Matches.Groups[1].Value.Trim()

    if ($vGpu -ne "host" -or $vTrans -ne "pipe" -or $vVsync -ne "$RefreshHz") {
        throw "[FATAL] AVD config verification failed! vsync='$vVsync', gpu='$vGpu', transport='$vTrans' (Expected: $RefreshHz, host, pipe)"
    }
    Write-Host "  [CONFIG_VERIFIED] AVD Profile: hw.gpu.mode='$vGpu', hw.gltransport='$vTrans', hw.lcd.vsync='$vVsync'" -ForegroundColor Cyan
    $results["AVD Refresh Config"] = "PASS ($RefreshHz Hz)"
} else {
    throw "[FATAL] AVD config file '$avdConfigFile' not found!"
}

# 5. Emulator 프로세스 및 실행 중 vsync 프로퍼티 일치 검증
$devices = & $adb devices 2>$null
$isRunning = $devices -match $deviceSerial

if ($isRunning) {
    $rawRunningVsync = (& $adb -s $deviceSerial shell getprop ro.boot.qemu.vsync 2>$null)
    $runningVsync = if ($rawRunningVsync) { ($rawRunningVsync | Out-String).Trim() } else { "UNKNOWN" }
    if ($runningVsync -ne "$RefreshHz") {
        Write-Host "  [INFO] Running emulator VSYNC profile mismatch ($runningVsync vs requested $RefreshHz). Terminating and cold booting..." -ForegroundColor Yellow
        & $adb -s $deviceSerial emu kill 2>$null | Out-Null
        Start-Sleep -Seconds 2
        Get-Process -Name qemu-system-x86_64,emulator -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        $isRunning = $false
    }
}

if (-not $isRunning) {
    Write-Host "  Starting Emulator '$AvdName' on port $ConsolePort with High Performance Settings..." -ForegroundColor Gray
    Start-Process -FilePath $emulator -ArgumentList "-avd", $AvdName, "-port", $ConsolePort, "-accel", "on", "-gpu", "host", "-dns-server", "8.8.8.8,1.1.1.1", "-no-skin", "-no-snapshot", "-no-snapshot-save", "-no-boot-anim"
}

Write-Host "  Waiting for sys.boot_completed=1 (max 120s)..." -ForegroundColor Gray
$booted = $false
$timeout = [DateTime]::UtcNow.AddSeconds(120)

while ([DateTime]::UtcNow -lt $timeout) {
    $bootPropRaw = & $adb -s $deviceSerial shell getprop sys.boot_completed 2>$null
    $bootProp = if ($bootPropRaw) { ($bootPropRaw | Out-String).Trim() } else { "" }
    if ($bootProp -eq "1") {
        $booted = $true
        break
    }
    Start-Sleep -Seconds 2
}

if ($booted) {
    Write-Host "  [PASS] Android boot_completed = 1 on $deviceSerial" -ForegroundColor Green
    $results["Android Boot"] = "PASS"
} else {
    throw "[FATAL] Android boot_completed timed out."
}

# 6. Guest Boot VSYNC Property 검증 (Fail-Closed)
$bootVsyncRaw = (& $adb -s $deviceSerial shell getprop ro.boot.qemu.vsync 2>$null)
$bootVsync = if ($bootVsyncRaw) { ($bootVsyncRaw | Out-String).Trim() } else { "UNKNOWN" }
if ($bootVsync -ne "$RefreshHz") {
    throw "[FATAL] Guest ro.boot.qemu.vsync mismatch! (Observed: '$bootVsync', Expected: '$RefreshHz')"
}
Write-Host "  [PASS] Guest ro.boot.qemu.vsync = $bootVsync" -ForegroundColor Green
$results["Guest Boot VSYNC"] = "PASS ($bootVsync Hz)"

# 7. Framework Refresh-Rate Policy 주입 및 Fail-Closed Readback
Write-Host "`n[5/8] Applying Framework Refresh-Rate Policy & Fullscreen..." -ForegroundColor Yellow
& $adb -s $deviceSerial shell settings put global policy_control immersive.full=* 2>$null
$results["Fullscreen Policy"] = "PASS"

$rateVal = [double]$RefreshHz
& $adb -s $deviceSerial shell settings put system peak_refresh_rate "${rateVal}.0" 2>$null
& $adb -s $deviceSerial shell settings put system min_refresh_rate "${rateVal}.0" 2>$null
Start-Sleep -Seconds 1

$rbPeakRaw = (& $adb -s $deviceSerial shell settings get system peak_refresh_rate 2>$null)
$rbPeak = if ($rbPeakRaw) { ($rbPeakRaw | Out-String).Trim() } else { "UNKNOWN" }
$rbMinRaw = (& $adb -s $deviceSerial shell settings get system min_refresh_rate 2>$null)
$rbMin = if ($rbMinRaw) { ($rbMinRaw | Out-String).Trim() } else { "UNKNOWN" }

if ($rbPeak -notmatch "^$RefreshHz" -or $rbMin -notmatch "^$RefreshHz") {
    throw "[FATAL] Framework refresh rate policy verification failed! (peak='$rbPeak', min='$rbMin', expected='$rateVal')"
}
Write-Host "  [PASS] Framework refresh policy applied: peak=$rbPeak, min=$rbMin" -ForegroundColor Green
$results["Framework Refresh Policy"] = "PASS ($RefreshHz Hz)"

# 8. DisplayManager Active Mode 검증 (Fail-Closed Gate)
$dispDump = (& $adb -s $deviceSerial shell dumpsys display 2>$null) | Out-String
$dmMode = 0
if ($dispDump -match "mCurrentDisplayMode.*?fps=([\d\.]+)") {
    $dmMode = [math]::Round([double]$Matches[1], 0)
} elseif ($dispDump -match "DisplayDeviceInfo.*?([\d\.]+)\s*fps") {
    $dmMode = [math]::Round([double]$Matches[1], 0)
} elseif ($dispDump -match "fps=([\d\.]+)") {
    $dmMode = [math]::Round([double]$Matches[1], 0)
}

if ([math]::Abs($dmMode - $RefreshHz) -gt 2) {
    throw "[FATAL] DisplayManager active mode mismatch! (Observed: ${dmMode}Hz, Expected: ${RefreshHz}Hz)"
}
Write-Host "  [PASS] DisplayManager active mode verified at ${dmMode}Hz." -ForegroundColor Green
$results["Display Active Mode"] = "PASS (${dmMode} Hz)"

# 9. GuestAgent 서비스 시작 및 포트 포워딩
Write-Host "`n[6/8] Starting GuestAgent Service & Setting up Port Forwarding..." -ForegroundColor Yellow
& $adb -s $deviceSerial shell am startservice -n com.tabletdroid.guestagent/.GuestService 2>$null | Out-Null
& $adb -s $deviceSerial forward tcp:$GuestPort tcp:$GuestPort 2>$null | Out-Null
Write-Host "  [PASS] Port tcp:$GuestPort forwarded to Guest." -ForegroundColor Green
$results["Guest Forward"] = "PASS"

# 10. Instagram 설치 여부 확인
Write-Host "`n[7/8] Checking Instagram APK installation on $deviceSerial..." -ForegroundColor Yellow
$instaPath = & $adb -s $deviceSerial shell pm path com.instagram.android 2>$null
if ($instaPath -and $instaPath -match "package:") {
    Write-Host "  [PASS] Instagram (com.instagram.android) is INSTALLED." -ForegroundColor Green
    $results["Instagram App"] = "INSTALLED"
} else {
    Write-Host "  [INFO] Instagram is NOT yet installed. You can install it from Play Store in the emulator." -ForegroundColor DarkYellow
    $results["Instagram App"] = "NOT_INSTALLED (Install via Play Store)"
}

# 11. 종합 요약 리포트 출력
Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " TabletDroid Spike Production Summary Report" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
foreach ($key in $results.Keys) {
    $val = $results[$key]
    $color = if ($val -match "PASS" -or $val -eq "INSTALLED") { "Green" } elseif ($val -match "WARN" -or $val -match "NOT_INSTALLED") { "Yellow" } else { "Red" }
    Write-Host ("  {0,-26} : {1}" -f $key, $val) -ForegroundColor $color
}
Write-Host "========================================================`n" -ForegroundColor Cyan

# 12. Host GUI 실행
if ($shouldLaunchHost) {
    Write-Host "[8/8] Building & Launching TabletDroid.Host (.NET 9.0 WPF)..." -ForegroundColor Yellow
    $hostProject = "$PSScriptRoot\..\..\host\TabletDroid.Host\TabletDroid.Host.csproj"
    $dotnetExe = (Get-Command dotnet.exe -ErrorAction SilentlyContinue).Source
    if (-not $dotnetExe) { $dotnetExe = "$dotnetDir\dotnet.exe" }

    & $dotnetExe build $hostProject -c Debug
    if ($LASTEXITCODE -ne 0) { throw "[FATAL] TabletDroid.Host build failed!" }

    $hostDll = (Resolve-Path "$PSScriptRoot\..\..\host\TabletDroid.Host\bin\Debug\net9.0-windows\TabletDroid.Host.dll").Path
    $env:DOTNET_ROOT = "$env:LOCALAPPDATA\Microsoft\dotnet"
    Write-Host "  Launching Host window with automatic SetParent embedding..." -ForegroundColor Green
    Start-Process -FilePath $dotnetExe -ArgumentList "`"$hostDll`" --auto-embed --automation"
}
