$dotnetExe = "C:\Users\o1o6o\AppData\Local\Microsoft\dotnet\dotnet.exe"
$env:DOTNET_ROOT = "C:\Users\o1o6o\AppData\Local\Microsoft\dotnet"
$hostDll = (Resolve-Path "$PSScriptRoot\..\host\TabletDroid.Host\bin\Debug\net9.0-windows\TabletDroid.Host.dll").Path

Write-Host "Launching $dotnetExe `"$hostDll`" --auto-embed --automation"
$proc = Start-Process -FilePath $dotnetExe -ArgumentList "`"$hostDll`" --auto-embed --automation" -PassThru
Start-Sleep -Seconds 3

Write-Host "Checking if process is alive: $(-not $proc.HasExited) (PID: $($proc.Id))"

$c = New-Object System.Net.Sockets.TcpClient
try {
    $iar = $c.BeginConnect("127.0.0.1", 28889, $null, $null)
    $ok = $iar.AsyncWaitHandle.WaitOne(3000)
    Write-Host "TCP 28889 Connect result: $ok"
    if ($ok) {
        $c.EndConnect($iar)
        $s = $c.GetStream()
        $w = New-Object System.IO.StreamWriter($s, [System.Text.Encoding]::UTF8) { AutoFlush = $true }
        $r = New-Object System.IO.StreamReader($s, [System.Text.Encoding]::UTF8)
        $w.WriteLine("PING")
        $resp = $r.ReadLine()
        Write-Host "PING response: $resp"
        $w.WriteLine("GET_GEOMETRY")
        $geom = $r.ReadLine()
        Write-Host "GET_GEOMETRY response: $geom"
    }
} catch {
    Write-Host "TCP Error: $_"
} finally {
    $c.Close()
}

Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
