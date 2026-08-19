$androidHome = "$env:LOCALAPPDATA\Android\Sdk"
$jdkHome = "$env:LOCALAPPDATA\Android\Jdk"
$dotnetDir = "$env:LOCALAPPDATA\Microsoft\dotnet"

$env:JAVA_HOME = $jdkHome
$env:ANDROID_HOME = $androidHome
$env:DOTNET_ROOT = $dotnetDir
$env:PATH = "$dotnetDir;$jdkHome\bin;$androidHome\platform-tools;$androidHome\emulator;$androidHome\cmdline-tools\latest\bin;$env:PATH"

Write-Host "--- .NET SDK Version ---"
& "$dotnetDir\dotnet.exe" --version

Write-Host "`n--- OpenJDK Version ---"
& "$jdkHome\bin\java.exe" -version

Write-Host "`n--- ADB Version ---"
& "$androidHome\platform-tools\adb.exe" version

Write-Host "`n--- Emulator Version ---"
& "$androidHome\emulator\emulator.exe" -version

Write-Host "`n--- AVD Targets ---"
& "$androidHome\cmdline-tools\latest\bin\avdmanager.bat" list target
