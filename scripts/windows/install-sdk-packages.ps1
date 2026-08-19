$androidHome = "$env:LOCALAPPDATA\Android\Sdk"
$jdkHome = "$env:LOCALAPPDATA\Android\Jdk"
$licensesDir = "$androidHome\licenses"

if (-not (Test-Path $licensesDir)) {
    New-Item -ItemType Directory -Path $licensesDir -Force | Out-Null
}

$license1 = @"
24333f8a63b6825ea9c5514f83c2829b004d1fee
84831b9409646a532e303d69b82814ab9d64e2b1
d975f751698a77b662f1254ddbeed3901e976f5a
"@

$license2 = @"
84831b9409646a532e303d69b82814ab9d64e2b1
799f6193e69c18843f7ce57705797169b251b1e3
"@

[System.IO.File]::WriteAllText("$licensesDir\android-sdk-license", $license1)
[System.IO.File]::WriteAllText("$licensesDir\android-sdk-preview-license", $license2)

$env:JAVA_HOME = $jdkHome
$env:ANDROID_HOME = $androidHome
$env:ANDROID_SDK_ROOT = $androidHome
$env:PATH = "$jdkHome\bin;$androidHome\cmdline-tools\latest\bin;$androidHome\platform-tools;$androidHome\emulator;$env:PATH"

$sdkManager = "$androidHome\cmdline-tools\latest\bin\sdkmanager.bat"

Write-Host "Accepting all licenses..." -ForegroundColor Cyan
cmd.exe /c "for /l %i in (1,1,20) do @echo y" | & $sdkManager --licenses

Write-Host "Installing packages: platform-tools, emulator, system-images;android-34;google_apis_playstore;x86_64..." -ForegroundColor Cyan
cmd.exe /c "for /l %i in (1,1,20) do @echo y" | & $sdkManager "platform-tools" "emulator" "system-images;android-34;google_apis_playstore;x86_64"

Write-Host "SDK Installation Completed!" -ForegroundColor Green
