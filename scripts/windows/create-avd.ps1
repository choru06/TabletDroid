param(
    [string]$AvdName = "TabletDroid_Z13_Play",
    [ValidateSet("Play", "Dev")]
    [string]$Profile = "Play",
    [int]$Width = 1920,
    [int]$Height = 1200,
    [int]$Dpi = 280,
    [int]$RamMb = 4096
)

$imagePackage = if ($Profile -eq "Play") {
    "system-images;android-34;google_apis_playstore;x86_64"
} else {
    "system-images;android-34;google_apis;x86_64"
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Creating TabletDroid AVD: $AvdName ($Profile Profile)" -ForegroundColor Cyan
Write-Host " Package: $imagePackage" -ForegroundColor Yellow
Write-Host " Resolution: ${Width}x${Height} @ ${Dpi}dpi, Memory: ${RamMb}MB" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan

$avdManager = (Get-Command avdmanager -ErrorAction SilentlyContinue).Source
if (-not $avdManager) {
    $avdManager = "$env:LOCALAPPDATA\Android\Sdk\cmdline-tools\latest\bin\avdmanager.bat"
}

if (-not (Test-Path $avdManager)) {
    Write-Warning "avdmanager not found at '$avdManager'. Please install cmdline-tools via SDK Manager."
    exit 1
}

# 기본 태블릿 AVD 생성 명령
Write-Host "Running avdmanager create avd..." -ForegroundColor Gray
& $avdManager create avd -n $AvdName -k $imagePackage --device "tablet" --force

# config.ini 속성 미세조정 (해상도 및 WHPX 최적화)
$avdPath = "$env:USERPROFILE\.android\avd\$AvdName.avd\config.ini"
if (Test-Path $avdPath) {
    Write-Host "Customizing config.ini for TabletDroid resolution & memory..." -ForegroundColor Yellow
    $config = Get-Content $avdPath
    $config += "hw.lcd.width = $Width"
    $config += "hw.lcd.height = $Height"
    $config += "hw.lcd.density = $Dpi"
    $config += "hw.ramSize = $RamMb"
    $config += "hw.keyboard = yes"
    $config += "hw.mainKeys = no"
    $config += "hw.accelerometer = yes"
    $config += "hw.sensors.orientation = yes"
    $config | Set-Content $avdPath
    Write-Host "[OK] AVD '$AvdName' ($Profile) created and customized successfully." -ForegroundColor Green
} else {
    Write-Warning "config.ini not found at '$avdPath'."
}
