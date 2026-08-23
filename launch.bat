@echo off
title TabletDroid Flow Z13 Spike Runner
set "JAVA_HOME=%LOCALAPPDATA%\Android\Jdk"
set "ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk"
set "DOTNET_ROOT=%LOCALAPPDATA%\Microsoft\dotnet"
set "PATH=%LOCALAPPDATA%\Microsoft\dotnet;%LOCALAPPDATA%\Android\Jdk\bin;%LOCALAPPDATA%\Android\Sdk\platform-tools;%LOCALAPPDATA%\Android\Sdk\emulator;%PATH%"

echo ========================================================
echo  Launching TabletDroid Spike on Flow Z13...
echo ========================================================

powershell.exe -ExecutionPolicy Bypass -File "%~dp0scripts\windows\run-spike.ps1" -RefreshHz 120 %*
pause
