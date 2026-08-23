# Fresh-path validation script for TabletDroid_Z13_Play_120_Test
$ErrorActionPreference = "Continue"
$rootDir = (Resolve-Path "$PSScriptRoot\..").Path
$testAvd = "TabletDroid_Z13_Play_120_Test"
$avdDir = "$env:USERPROFILE\.android\avd\$testAvd.avd"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Fresh-Path Validation: $testAvd (120Hz)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Step 1: Create fresh test AVD
Write-Host "[1/4] Running create-avd.ps1 with -RefreshHz 120..." -ForegroundColor Yellow
& powershell.exe -ExecutionPolicy Bypass -File "$rootDir\scripts\windows\create-avd.ps1" -AvdName $testAvd -Profile "Play" -RefreshHz 120

# Verify config.ini
$cfgPath = "$avdDir\config.ini"
if (-not (Test-Path $cfgPath)) { throw "config.ini not found at $cfgPath" }
$cfg = Get-Content $cfgPath
$vsync = ($cfg | Select-String "^hw\.lcd\.vsync\s*=\s*(.*)").Matches.Groups[1].Value.Trim()
$gpu = ($cfg | Select-String "^hw\.gpu\.mode\s*=\s*(.*)").Matches.Groups[1].Value.Trim()
$trans = ($cfg | Select-String "^hw\.gltransport\s*=\s*(.*)").Matches.Groups[1].Value.Trim()
Write-Host "  Readback: vsync=$vsync, gpu=$gpu, transport=$trans" -ForegroundColor Gray
if ($vsync -ne "120" -or $gpu -ne "host" -or $trans -ne "pipe") {
    throw "Fresh AVD config readback failed!"
}

# Step 2: Boot fresh AVD via run-spike.ps1 (-LaunchHost $false)
Write-Host "`n[2/4] Running run-spike.ps1 with -AvdName $testAvd -RefreshHz 120 -LaunchHost `$false..." -ForegroundColor Yellow
& powershell.exe -ExecutionPolicy Bypass -File "$rootDir\scripts\windows\run-spike.ps1" -AvdName $testAvd -RefreshHz 120 -LaunchHost $false

# Step 3: Direct telemetry validation
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$bootVsyncRaw = (& $adb -s emulator-5554 shell getprop ro.boot.qemu.vsync 2>$null)
$bootVsync = if ($bootVsyncRaw) { ($bootVsyncRaw | Out-String).Trim() } else { "UNKNOWN" }
$peakRaw = (& $adb -s emulator-5554 shell settings get system peak_refresh_rate 2>$null)
$peak = if ($peakRaw) { ($peakRaw | Out-String).Trim() } else { "UNKNOWN" }
$minRaw = (& $adb -s emulator-5554 shell settings get system min_refresh_rate 2>$null)
$min = if ($minRaw) { ($minRaw | Out-String).Trim() } else { "UNKNOWN" }
$disp = (& $adb -s emulator-5554 shell dumpsys display 2>$null) | Out-String
$mode = if ($disp -match "mCurrentDisplayMode.*?fps=([\d\.]+)") { $Matches[1] } elseif ($disp -match "fps=([\d\.]+)") { $Matches[1] } else { "UNKNOWN" }

Write-Host "`n[3/4] Fresh AVD Guest Verification:" -ForegroundColor Cyan
Write-Host "  ro.boot.qemu.vsync      : $bootVsync (Expected: 120)" -ForegroundColor Gray
Write-Host "  system.peak_refresh_rate: $peak (Expected: 120.0)" -ForegroundColor Gray
Write-Host "  system.min_refresh_rate : $min (Expected: 120.0)" -ForegroundColor Gray
Write-Host "  DisplayManager Mode     : $mode Hz (Expected: ~120)" -ForegroundColor Gray

if ($bootVsync -ne "120" -or $peak -notmatch "^120" -or $min -notmatch "^120") {
    throw "Guest telemetry validation failed on fresh AVD!"
}

# Step 4: Cleanup
Write-Host "`n[4/4] Terminating test emulator and cleaning up test AVD..." -ForegroundColor Yellow
& $adb -s emulator-5554 emu kill 2>$null | Out-Null
Start-Sleep -Seconds 2
Get-Process -Name qemu-system-x86_64,emulator -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Remove test AVD
$avdManager = "$env:LOCALAPPDATA\Android\Sdk\cmdline-tools\latest\bin\avdmanager.bat"
cmd.exe /c "`"$avdManager`" delete avd -n `"$testAvd`""
Write-Host "  [OK] Fresh AVD validation completed and cleaned up successfully." -ForegroundColor Green
