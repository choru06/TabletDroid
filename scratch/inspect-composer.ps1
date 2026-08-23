$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"

Write-Host "=== SERVICE LIST (composer) ==="
& $adb shell "service list" | Select-String "composer"

Write-Host "`n=== PROCESS LIST (composer) ==="
& $adb shell "ps -A" | Select-String "composer"

Write-Host "`n=== /proc/cmdline ==="
& $adb shell "cat /proc/cmdline"

Write-Host "`n=== VSYNC PROPERTIES ==="
& $adb shell "getprop" | Select-String "vsync"

Write-Host "`n=== COMPOSER APEX / PACKAGES ==="
& $adb shell "ls -l /vendor/bin/hw/ /apex/ 2>/dev/null" | Select-String "composer"
& $adb shell "which android.hardware.graphics.composer3-service.ranchu 2>/dev/null || ls -l /vendor/bin/hw/*composer*"

Write-Host "`n=== LSHAL (composer) ==="
& $adb shell "lshal 2>/dev/null" | Select-String "composer"
