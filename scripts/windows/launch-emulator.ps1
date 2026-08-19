param(
    [string]$AvdName = "TabletDroid_Z13",
    [switch]$NoSkin = $true,
    [switch]$NoWindow = $false
)

$emulatorPath = (Get-Command emulator -ErrorAction SilentlyContinue).Source
if (-not $emulatorPath) {
    $emulatorPath = "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe"
}

if (-not (Test-Path $emulatorPath)) {
    Write-Warning "Android Emulator not found. Please ensure Android SDK emulator is installed."
    exit 1
}

$argsList = @(
    "-avd", $AvdName,
    "-accel", "on",
    "-gpu", "host",
    "-no-boot-anim",
    "-no-snapshot-save"
)

if ($NoSkin) {
    $argsList += "-no-skin"
}

if ($NoWindow) {
    $argsList += "-no-window"
}

Write-Host "Launching Android Emulator for TabletDroid ($AvdName) with WHPX acceleration..." -ForegroundColor Cyan
& $emulatorPath $argsList
