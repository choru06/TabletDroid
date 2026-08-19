# TabletDroid Windows 환경 점검 스크립트
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " TabletDroid Windows Environment Checker" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# 1. .NET SDK 확인
Write-Host "`n[1] Checking .NET SDK..." -ForegroundColor Yellow
try {
    $dotnetVer = dotnet --version
    Write-Host "  [OK] .NET SDK version: $dotnetVer" -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] .NET SDK is not installed or not in PATH." -ForegroundColor Red
}

# 2. WHPX (Windows Hypervisor Platform) 확인
Write-Host "`n[2] Checking WHPX (Windows Hypervisor Platform)..." -ForegroundColor Yellow
$whpxFeature = Get-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform -ErrorAction SilentlyContinue
if ($whpxFeature -and $whpxFeature.State -eq "Enabled") {
    Write-Host "  [OK] Windows Hypervisor Platform (WHPX) is ENABLED." -ForegroundColor Green
} else {
    Write-Host "  [WARN] HypervisorPlatform feature state: $($whpxFeature.State). Please enable it via 'Enable-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform' if needed." -ForegroundColor DarkYellow
}

# 3. Android SDK / Emulator 확인
Write-Host "`n[3] Checking Android SDK / Emulator & ADB..." -ForegroundColor Yellow
$adbPath = (Get-Command adb -ErrorAction SilentlyContinue).Source
$emulatorPath = (Get-Command emulator -ErrorAction SilentlyContinue).Source

if ($adbPath) {
    Write-Host "  [OK] ADB found at: $adbPath" -ForegroundColor Green
} else {
    Write-Host "  [INFO] ADB not in standard PATH. Checking LOCALAPPDATA\Android\Sdk..." -ForegroundColor Gray
    $localSdkAdb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
    if (Test-Path $localSdkAdb) {
        Write-Host "  [OK] ADB found at: $localSdkAdb" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] ADB not found. Please install Android Platform Tools or set ANDROID_HOME." -ForegroundColor DarkYellow
    }
}

if ($emulatorPath) {
    Write-Host "  [OK] Emulator found at: $emulatorPath" -ForegroundColor Green
} else {
    $localSdkEmulator = "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe"
    if (Test-Path $localSdkEmulator) {
        Write-Host "  [OK] Emulator found at: $localSdkEmulator" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Android Emulator not found in standard paths." -ForegroundColor DarkYellow
    }
}

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host " Environment check completed." -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
