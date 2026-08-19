$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Android Emulator Device Status on Z13    " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$release = & $adb shell getprop ro.build.version.release
$sdk = & $adb shell getprop ro.build.version.sdk
$model = & $adb shell getprop ro.product.model
$size = & $adb shell wm size
$density = & $adb shell wm density
$boot = & $adb shell getprop sys.boot_completed
$insta = & $adb shell pm path com.instagram.android

Write-Host ("Android Release   : {0}" -f $release.Trim()) -ForegroundColor Green
Write-Host ("Android SDK Level : {0}" -f $sdk.Trim()) -ForegroundColor Green
Write-Host ("Product Model     : {0}" -f $model.Trim()) -ForegroundColor Green
Write-Host ("Display Size      : {0}" -f $size.Trim()) -ForegroundColor Green
Write-Host ("Display Density   : {0}" -f $density.Trim()) -ForegroundColor Green
Write-Host ("Boot Completed    : {0}" -f $boot.Trim()) -ForegroundColor Green
Write-Host ("Instagram Status  : {0}" -f $(if ($insta -match "package:") { "INSTALLED ($insta)" } else { "NOT INSTALLED (Open Play Store in Emulator)" })) -ForegroundColor Yellow

# Apply Immersive policy and port forward
& $adb shell settings put global policy_control immersive.full=*
& $adb forward tcp:28888 tcp:28888
Write-Host "Immersive Fullscreen Policy & Port Forwarding (tcp:28888) Active." -ForegroundColor Cyan
