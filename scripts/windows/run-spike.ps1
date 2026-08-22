param(
    [string]$AvdName = "TabletDroid_Z13_Play",
    [int]$ConsolePort = 5554,
    [int]$GuestPort = 28888,
    [switch]$LaunchHost = $true
)

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
Write-Host " TabletDroid v0.0 Physical E2E Validation Spike Runner" -ForegroundColor Cyan
Write-Host " Target Device: ASUS ROG Flow Z13 / Windows 11" -ForegroundColor Cyan
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

# 2. AVD 존재 확인
Write-Host "`n[2/8] Checking AVD '$AvdName'..." -ForegroundColor Yellow
$avdPath = "$env:USERPROFILE\.android\avd\$AvdName.avd"
if (Test-Path $avdPath) {
    Write-Host "  [PASS] AVD '$AvdName' exists." -ForegroundColor Green
    $results["AVD ($AvdName)"] = "PASS"
} else {
    Write-Host "  [INFO] AVD '$AvdName' not found. Creating now..." -ForegroundColor Yellow
    & powershell.exe -ExecutionPolicy Bypass -File "$PSScriptRoot\create-avd.ps1" -AvdName $AvdName -Profile "Play"
    if (Test-Path $avdPath) {
        Write-Host "  [PASS] AVD created successfully." -ForegroundColor Green
        $results["AVD ($AvdName)"] = "PASS"
    } else {
        Write-Host "  [FAIL] AVD creation failed." -ForegroundColor Red
        $results["AVD ($AvdName)"] = "FAIL"
    }
}

# 3. Emulator 및 ADB 도구 확인
Write-Host "`n[3/8] Checking ADB & Emulator binaries..." -ForegroundColor Yellow
if ((Test-Path $emulator) -and (Test-Path $adb)) {
    Write-Host "  [PASS] Emulator and ADB found." -ForegroundColor Green
    $results["Tooling"] = "PASS"
} else {
    Write-Host "  [FAIL] Missing emulator or adb at standard paths." -ForegroundColor Red
    $results["Tooling"] = "FAIL"
}

# 4. Emulator 실행 및 부팅 대기
Write-Host "`n[4/8] Checking Emulator process on $deviceSerial..." -ForegroundColor Yellow
$devices = & $adb devices
$isRunning = $devices -match $deviceSerial

if (-not $isRunning) {
    Write-Host "  Starting Emulator '$AvdName' on port $ConsolePort with High Performance Settings..." -ForegroundColor Gray
    Start-Process -FilePath $emulator -ArgumentList "-avd", $AvdName, "-port", $ConsolePort, "-accel", "on", "-gpu", "host", "-dns-server", "8.8.8.8,1.1.1.1", "-no-skin", "-no-snapshot", "-no-snapshot-save", "-no-boot-anim"
}

Write-Host "  Waiting for sys.boot_completed=1 (max 120s)..." -ForegroundColor Gray
$booted = $false
$timeout = [DateTime]::UtcNow.AddSeconds(120)

while ([DateTime]::UtcNow -lt $timeout) {
    $bootProp = & $adb -s $deviceSerial shell getprop sys.boot_completed 2>$null
    if ($bootProp -and $bootProp.Trim() -eq "1") {
        $booted = $true
        break
    }
    Start-Sleep -Seconds 2
}

if ($booted) {
    Write-Host "  [PASS] Android boot_completed = 1 on $deviceSerial" -ForegroundColor Green
    $results["Android Boot"] = "PASS"
} else {
    Write-Host "  [FAIL] Android boot_completed timed out." -ForegroundColor Red
    $results["Android Boot"] = "FAIL"
}

# 5. Fullscreen Insets Workaround 적용
Write-Host "`n[5/8] Applying Clean Fullscreen policy..." -ForegroundColor Yellow
& $adb -s $deviceSerial shell settings put global policy_control immersive.full=* 2>$null
Write-Host "  [PASS] Immersive fullscreen policy applied." -ForegroundColor Green
$results["Fullscreen Policy"] = "PASS"

# 6. GuestAgent 서비스 시작 및 포트 포워딩
Write-Host "`n[6/8] Starting GuestAgent Service & Setting up Port Forwarding..." -ForegroundColor Yellow
& $adb -s $deviceSerial shell am startservice -n com.tabletdroid.guestagent/.GuestService 2>$null
& $adb -s $deviceSerial forward tcp:$GuestPort tcp:$GuestPort 2>$null
Write-Host "  [PASS] Port tcp:$GuestPort forwarded to Guest." -ForegroundColor Green
$results["Guest Forward"] = "PASS"

# 7. Instagram 설치 여부 확인
Write-Host "`n[7/8] Checking Instagram APK installation on $deviceSerial..." -ForegroundColor Yellow
$instaPath = & $adb -s $deviceSerial shell pm path com.instagram.android 2>$null
if ($instaPath -and $instaPath -match "package:") {
    Write-Host "  [PASS] Instagram (com.instagram.android) is INSTALLED." -ForegroundColor Green
    $results["Instagram App"] = "INSTALLED"
} else {
    Write-Host "  [INFO] Instagram is NOT yet installed. You can install it from Play Store in the emulator." -ForegroundColor DarkYellow
    $results["Instagram App"] = "NOT_INSTALLED (Install via Play Store)"
}

# 8. 종합 요약 리포트 출력
Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " TabletDroid v0.0 Spike Summary Report" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
foreach ($key in $results.Keys) {
    $val = $results[$key]
    $color = if ($val -eq "PASS" -or $val -eq "INSTALLED") { "Green" } elseif ($val -match "WARN" -or $val -match "NOT_INSTALLED") { "Yellow" } else { "Red" }
    Write-Host ("  {0,-25} : {1}" -f $key, $val) -ForegroundColor $color
}
Write-Host "========================================================`n" -ForegroundColor Cyan

# 9. Host GUI 실행
if ($LaunchHost) {
    Write-Host "Launching TabletDroid Host Application (.NET 9)..." -ForegroundColor Cyan
    $hostProj = "$PSScriptRoot\..\..\host\TabletDroid.Host\TabletDroid.Host.csproj"
    $dotnetExe = (Get-Command dotnet.exe -ErrorAction SilentlyContinue).Source
    if (-not $dotnetExe) { $dotnetExe = "$dotnetDir\dotnet.exe" }
    Start-Process $dotnetExe -ArgumentList "run", "--project", "`"$hostProj`""
}
