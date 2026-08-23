param(
    [string]$AvdName = "TabletDroid_Z13_Play",
    [ValidateSet("Play", "Dev")]
    [string]$Profile = "Play",
    [ValidateSet(60, 120)]
    [int]$RefreshHz = 120,
    [int]$Width = 1920,
    [int]$Height = 1200,
    [int]$Dpi = 280,
    [int]$RamMb = 4096
)

$androidHome = "$env:LOCALAPPDATA\Android\Sdk"
$jdkHome = "$env:LOCALAPPDATA\Android\Jdk"

if (Test-Path $jdkHome) {
    $env:JAVA_HOME = $jdkHome
    $env:PATH = "$jdkHome\bin;$env:PATH"
}
if (Test-Path $androidHome) {
    $env:ANDROID_HOME = $androidHome
    $env:ANDROID_SDK_ROOT = $androidHome
    $env:PATH = "$androidHome\platform-tools;$androidHome\emulator;$androidHome\cmdline-tools\latest\bin;$env:PATH"
}

$imagePackage = if ($Profile -eq "Play") {
    "system-images;android-34;google_apis_playstore;x86_64"
} else {
    "system-images;android-34;google_apis;x86_64"
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Creating TabletDroid AVD: $AvdName ($Profile Profile)" -ForegroundColor Cyan
Write-Host " Package: $imagePackage" -ForegroundColor Yellow
Write-Host " Resolution: ${Width}x${Height} @ ${Dpi}dpi (${RefreshHz}Hz), Memory: ${RamMb}MB" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan

$avdManager = (Get-Command avdmanager -ErrorAction SilentlyContinue).Source
if (-not $avdManager) {
    $avdManager = "$androidHome\cmdline-tools\latest\bin\avdmanager.bat"
}

if (-not (Test-Path $avdManager)) {
    Write-Warning "avdmanager not found at '$avdManager'. Please install cmdline-tools via SDK Manager."
    exit 1
}

# 기본 태블릿 AVD 생성 명령 (시스템 이미지 기반 생성 후 config.ini 커스터마이징)
Write-Host "Running avdmanager create avd..." -ForegroundColor Gray
cmd.exe /c "echo no | `"$avdManager`" create avd -n `"$AvdName`" -k `"$imagePackage`" --force"

# config.ini 속성 미세조정 (해상도 및 Z13 Flow 가속 최적화)
$avdPath = "$env:USERPROFILE\.android\avd\$AvdName.avd\config.ini"
if (Test-Path $avdPath) {
    Write-Host "Customizing config.ini for TabletDroid resolution & memory..." -ForegroundColor Yellow
    $config = [System.Collections.Generic.List[string]]::new()
    foreach ($line in (Get-Content $avdPath)) {
        if ($line -notmatch "^(hw\.lcd\.width|hw\.lcd\.height|hw\.lcd\.density|hw\.lcd\.vsync|hw\.ramSize|hw\.gpu\.enabled|hw\.gpu\.mode|hw\.gltransport|hw\.cpu\.ncore|vm\.heapSize|hw\.keyboard|hw\.mainKeys|hw\.accelerometer|hw\.sensors\.orientation)\s*=") {
            $config.Add($line)
        }
    }
    $config.Add("hw.lcd.width = $Width")
    $config.Add("hw.lcd.height = $Height")
    $config.Add("hw.lcd.density = $Dpi")
    $config.Add("hw.lcd.vsync = $RefreshHz")
    $config.Add("hw.ramSize = 6144")
    $config.Add("hw.gpu.enabled = yes")
    $config.Add("hw.gpu.mode = host")
    $config.Add("hw.gltransport = pipe")
    $config.Add("hw.cpu.ncore = 8")
    $config.Add("vm.heapSize = 512M")
    $config.Add("hw.keyboard = yes")
    $config.Add("hw.mainKeys = no")
    $config.Add("hw.accelerometer = yes")
    $config.Add("hw.sensors.orientation = yes")
    Set-Content -Path $avdPath -Value $config -Encoding UTF8

    # Post-creation Fail-Closed Verification
    $verifiedCfg = Get-Content $avdPath
    $vGpu = ($verifiedCfg | Select-String "^hw\.gpu\.mode\s*=\s*(.*)").Matches.Groups[1].Value.Trim()
    $vTrans = ($verifiedCfg | Select-String "^hw\.gltransport\s*=\s*(.*)").Matches.Groups[1].Value.Trim()
    $vVsync = ($verifiedCfg | Select-String "^hw\.lcd\.vsync\s*=\s*(.*)").Matches.Groups[1].Value.Trim()

    if ($vGpu -ne "host" -or $vTrans -ne "pipe" -or $vVsync -ne "$RefreshHz") {
        throw "[FATAL] AVD config readback validation failed! vsync='$vVsync', gpu='$vGpu', transport='$vTrans' (Expected: $RefreshHz, host, pipe)"
    }
    Write-Host "  [CONFIG_VERIFIED] AVD Hardware Profile: hw.gpu.mode='$vGpu', hw.gltransport='$vTrans', hw.lcd.vsync='$vVsync'" -ForegroundColor Cyan
    Write-Host "[OK] AVD '$AvdName' ($Profile) created and verified successfully." -ForegroundColor Green
} else {
    throw "[FATAL] config.ini not found at '$avdPath'."
}
