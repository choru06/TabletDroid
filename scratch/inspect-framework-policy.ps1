$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"

Write-Host "=== SETTINGS (refresh_rate) ==="
$peak = & $adb shell settings get system peak_refresh_rate
$min = & $adb shell settings get system min_refresh_rate
Write-Host "  peak_refresh_rate: '$peak'"
Write-Host "  min_refresh_rate : '$min'"

Write-Host "`n=== SURFACEFLINGER --DISPLAYS ==="
& $adb shell dumpsys SurfaceFlinger --displays

Write-Host "`n=== SURFACEFLINGER --DISPLAY-MODES ==="
& $adb shell dumpsys SurfaceFlinger --display-modes

Write-Host "`n=== DISPLAYMODEDIRECTOR (dumpsys display) ==="
$dispDump = & $adb shell dumpsys display
$lines = $dispDump -split "`r?`n"

$record = $false
foreach ($line in $lines) {
    if ($line -match "DisplayModeDirector|Display Device Details|Display Devices:|mOverride|refreshRateOverride|mBaseDisplayInfo|VoteSummary|mSupportedModes") {
        Write-Host $line
    }
}
