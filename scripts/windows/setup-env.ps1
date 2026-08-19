param(
    [switch]$Force = $false
)

$ErrorActionPreference = "Stop"

$androidHome = "$env:LOCALAPPDATA\Android\Sdk"
$jdkHome = "$env:LOCALAPPDATA\Android\Jdk"
$dotnetDir = "$env:LOCALAPPDATA\Microsoft\dotnet"
$tempDir = "$env:TEMP\tabletdroid_setup"

if (-not (Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir -Force | Out-Null }
if (-not (Test-Path $androidHome)) { New-Item -ItemType Directory -Path $androidHome -Force | Out-Null }

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " TabletDroid Environment Automated Setup " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. .NET 9 SDK
Write-Host "`n[1/4] Checking .NET 9 SDK..." -ForegroundColor Yellow
$dotnetExe = "$dotnetDir\dotnet.exe"
if (-not (Test-Path $dotnetExe) -or $Force) {
    Write-Host "Downloading dotnet-install.ps1..." -ForegroundColor Gray
    $dotnetScript = "$tempDir\dotnet-install.ps1"
    curl.exe -sSL "https://dot.net/v1/dotnet-install.ps1" -o $dotnetScript
    Write-Host "Installing .NET 9 SDK to $dotnetDir..." -ForegroundColor Gray
    & powershell.exe -ExecutionPolicy Bypass -File $dotnetScript -Channel "9.0" -InstallDir $dotnetDir
}
if (Test-Path $dotnetExe) {
    Write-Host "  [OK] .NET 9 SDK ready at $dotnetExe" -ForegroundColor Green
    $env:DOTNET_ROOT = $dotnetDir
    $env:PATH = "$dotnetDir;$env:PATH"
    [Environment]::SetEnvironmentVariable("DOTNET_ROOT", $dotnetDir, "User")
}

# 2. OpenJDK 17
Write-Host "`n[2/4] Setting up OpenJDK 17..." -ForegroundColor Yellow
$javaExe = "$jdkHome\bin\java.exe"
if (-not (Test-Path $javaExe) -or $Force) {
    Write-Host "Downloading Adoptium OpenJDK 17 zip via curl..." -ForegroundColor Gray
    $jdkZip = "$tempDir\openjdk17.zip"
    $jdkUrl = "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.14%2B7/OpenJDK17U-jdk_x64_windows_hotspot_17.0.14_7.zip"
    curl.exe -L "$jdkUrl" -o "$jdkZip"
    Write-Host "Extracting OpenJDK 17..." -ForegroundColor Gray
    $jdkExtract = "$tempDir\jdk_extract"
    if (Test-Path $jdkExtract) { Remove-Item -Recurse -Force $jdkExtract }
    Expand-Archive -Path $jdkZip -DestinationPath $jdkExtract -Force
    $innerJdk = Get-ChildItem -Path $jdkExtract -Directory | Select-Object -First 1
    if (Test-Path $jdkHome) { Remove-Item -Recurse -Force $jdkHome }
    Move-Item -Path $innerJdk.FullName -Destination $jdkHome
}
if (Test-Path $javaExe) {
    Write-Host "  [OK] OpenJDK 17 ready at $javaExe" -ForegroundColor Green
    $env:JAVA_HOME = $jdkHome
    $env:PATH = "$jdkHome\bin;$env:PATH"
    [Environment]::SetEnvironmentVariable("JAVA_HOME", $jdkHome, "User")
}

# 3. Android Command-line Tools
Write-Host "`n[3/4] Setting up Android Command-line Tools..." -ForegroundColor Yellow
$cmdlineDir = "$androidHome\cmdline-tools\latest"
$sdkManager = "$cmdlineDir\bin\sdkmanager.bat"
if (-not (Test-Path $sdkManager) -or $Force) {
    Write-Host "Downloading Android cmdline-tools zip via curl..." -ForegroundColor Gray
    $cmdlineZip = "$tempDir\cmdline-tools.zip"
    $cmdlineUrl = "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
    curl.exe -L "$cmdlineUrl" -o "$cmdlineZip"
    Write-Host "Extracting cmdline-tools..." -ForegroundColor Gray
    $cmdlineExtract = "$tempDir\cmdline_extract"
    if (Test-Path $cmdlineExtract) { Remove-Item -Recurse -Force $cmdlineExtract }
    Expand-Archive -Path $cmdlineZip -DestinationPath $cmdlineExtract -Force
    
    if (-not (Test-Path "$androidHome\cmdline-tools")) { New-Item -ItemType Directory -Path "$androidHome\cmdline-tools" -Force | Out-Null }
    if (Test-Path $cmdlineDir) { Remove-Item -Recurse -Force $cmdlineDir }
    Move-Item -Path "$cmdlineExtract\cmdline-tools" -Destination $cmdlineDir
}
if (Test-Path $sdkManager) {
    Write-Host "  [OK] Android cmdline-tools ready at $sdkManager" -ForegroundColor Green
}

# 4. Install Emulator, Platform-Tools, and System Image
Write-Host "`n[4/4] Installing Android Platform Tools, Emulator, System Image (Android 34)..." -ForegroundColor Yellow
$env:ANDROID_HOME = $androidHome
$env:ANDROID_SDK_ROOT = $androidHome
[Environment]::SetEnvironmentVariable("ANDROID_HOME", $androidHome, "User")
[Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $androidHome, "User")

$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
$newPath = "$dotnetDir;$jdkHome\bin;$androidHome\platform-tools;$androidHome\emulator;$cmdlineDir\bin;$currentPath"
$env:PATH = "$dotnetDir;$jdkHome\bin;$androidHome\platform-tools;$androidHome\emulator;$cmdlineDir\bin;$env:PATH"
[Environment]::SetEnvironmentVariable("Path", $newPath, "User")

Write-Host "Accepting licenses..." -ForegroundColor Gray
cmd.exe /c "echo y | `"$sdkManager`" --licenses"

Write-Host "Installing packages: platform-tools, emulator, system-images;android-34;google_apis_playstore;x86_64..." -ForegroundColor Gray
cmd.exe /c "echo y | `"$sdkManager`" `"platform-tools`" `"emulator`" `"system-images;android-34;google_apis_playstore;x86_64`""

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host " Environment Setup Completed Successfully! " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
