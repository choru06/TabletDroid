$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$cleanedPath = ($userPath -split ';' | Where-Object { $_ -and $_ -notlike '*Microsoft\dotnet*' }) -join ';'
[Environment]::SetEnvironmentVariable("Path", $cleanedPath, "User")
[Environment]::SetEnvironmentVariable("DOTNET_ROOT", $null, "User")
[Environment]::SetEnvironmentVariable("DOTNET_ROOT(x86)", $null, "User")

Write-Host "=== User Environment Cleaned ===" -ForegroundColor Green
Write-Host "User Path: " ([Environment]::GetEnvironmentVariable("Path", "User"))
Write-Host "DOTNET_ROOT: " ([Environment]::GetEnvironmentVariable("DOTNET_ROOT", "User"))
