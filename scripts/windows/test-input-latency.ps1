# ==============================================================================
# TabletDroid Canonical Software Input-to-Frame Latency Benchmark Suite
# Measures guest software input latency (Event -> Dispatch -> Choreographer -> onDraw)
# A/B Comparison: Standalone Emulator vs Host Embedded (Win32 SetParent)
# Baseline: 1920x1200 @ 120Hz, gfxstream, pipe, WHPX
# ==============================================================================
param(
    [string]$DeviceSerial = "emulator-5554",
    [string]$AvdName = "TabletDroid_Z13_Play",
    [switch]$SkipBuild = $false,
    [switch]$SkipBoot = $false,
    [int]$TapCount = 60,
    [int]$DragCount = 15,
    [int]$SwipeCount = 15,
    [string]$OutputDir = "$PSScriptRoot\..\..\artifacts\input-latency"
)

$ErrorActionPreference = "Stop"

$rootDir = (Resolve-Path "$PSScriptRoot\..\..").Path
$avdConfigPath = "$env:USERPROFILE\.android\avd\$AvdName.avd\config.ini"
$androidHome = "$env:LOCALAPPDATA\Android\Sdk"
$jdkHome = "$env:LOCALAPPDATA\Android\Jdk"

if (Test-Path $jdkHome) {
    $env:JAVA_HOME = $jdkHome
    $env:PATH = "$jdkHome\bin;$env:PATH"
}
if (Test-Path $androidHome) {
    $env:ANDROID_HOME = $androidHome
    $env:ANDROID_SDK_ROOT = $androidHome
    $env:PATH = "$androidHome\platform-tools;$androidHome\emulator;$androidHome\cmdline-tools\latest\bin;$env:PATH"
}

$adb = (Get-Command adb.exe -ErrorAction SilentlyContinue).Source
if (-not $adb) { $adb = "$androidHome\platform-tools\adb.exe" }
$emulator = "$androidHome\emulator\emulator.exe"
$dotnetDir = "$env:LOCALAPPDATA\Microsoft\dotnet"
$dotnet = if (Test-Path "$dotnetDir\dotnet.exe") { "$dotnetDir\dotnet.exe" } else { (Get-Command dotnet.exe -ErrorAction SilentlyContinue).Source }
$env:DOTNET_ROOT = $dotnetDir
$env:PATH = "$dotnetDir;$env:PATH"

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$sessionOutputDir = "$OutputDir\$timestamp"
New-Item -ItemType Directory -Path $sessionOutputDir -Force | Out-Null

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host " TabletDroid Canonical Software Input-to-Frame Latency Benchmark" -ForegroundColor Cyan
Write-Host " Timestamp         : $timestamp" -ForegroundColor Cyan
Write-Host " Target Hardware   : ASUS ROG Flow Z13 / Windows 11" -ForegroundColor Cyan
Write-Host " Baseline Config   : 1920x1200 @ 120Hz, gfxstream, pipe transport, WHPX" -ForegroundColor Cyan
Write-Host " Benchmark Package : com.tabletdroid.benchmark/.InputProbeActivity" -ForegroundColor Cyan
Write-Host " Output Directory  : $sessionOutputDir" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host " [DISCLAIMER] This benchmark measures guest software input-to-frame latency." -ForegroundColor Yellow
Write-Host "              It is NOT a physical touch-to-photon measurement." -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan

function Invoke-AdbSilent {
    param([string]$CmdArgs)
    $proc = Start-Process -FilePath $adb -ArgumentList "-s $DeviceSerial $CmdArgs" -NoNewWindow -Wait -PassThru
    return $proc.ExitCode
}

function Invoke-AdbOutput {
    param([string]$CmdArgs)
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $adb
    $pinfo.Arguments = "-s $DeviceSerial $CmdArgs"
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $true
    $p = [System.Diagnostics.Process]::Start($pinfo)
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    return $stdout.Trim()
}

function Invoke-AdbGlobalOutput {
    param([string]$CmdArgs)
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $adb
    $pinfo.Arguments = $CmdArgs
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $true
    $p = [System.Diagnostics.Process]::Start($pinfo)
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    return $stdout.Trim()
}

function Terminate-Emulator {
    Write-Host "  Terminating any running emulator / host instances..." -ForegroundColor Gray
    Invoke-AdbSilent "emu kill" | Out-Null
    Start-Sleep -Seconds 2
    Get-Process -Name qemu-system-x86_64,emulator,TabletDroid.Host -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    for ($w = 0; $w -lt 10; $w++) {
        $devList = Invoke-AdbGlobalOutput "devices"
        if ($devList -notmatch "emulator-5554\s+device") { break }
        Start-Sleep -Seconds 1
    }
}

function Ensure-AvdConfig120 {
    if (-not (Test-Path $avdConfigPath)) { return }
    $configLines = Get-Content $avdConfigPath
    $newConfigLines = [System.Collections.Generic.List[string]]::new()
    $vsyncSet = $false; $glTransportSet = $false; $gpuModeSet = $false
    foreach ($line in $configLines) {
        if ($line -match "^hw\.lcd\.vsync\s*=") { $newConfigLines.Add("hw.lcd.vsync = 120"); $vsyncSet = $true }
        elseif ($line -match "^hw\.gltransport\s*=") { $newConfigLines.Add("hw.gltransport = pipe"); $glTransportSet = $true }
        elseif ($line -match "^hw\.gpu\.mode\s*=") { $newConfigLines.Add("hw.gpu.mode = host"); $gpuModeSet = $true }
        else { $newConfigLines.Add($line) }
    }
    if (-not $vsyncSet) { $newConfigLines.Add("hw.lcd.vsync = 120") }
    if (-not $glTransportSet) { $newConfigLines.Add("hw.gltransport = pipe") }
    if (-not $gpuModeSet) { $newConfigLines.Add("hw.gpu.mode = host") }
    Set-Content -Path $avdConfigPath -Value $newConfigLines -Encoding UTF8
}

function Invoke-HostCmd {
    param([string]$Cmd)
    $c = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $c.BeginConnect("127.0.0.1", 28889, $null, $null)
        if ($iar.AsyncWaitHandle.WaitOne(3000)) {
            $c.EndConnect($iar)
            $s = $c.GetStream()
            $w = New-Object System.IO.StreamWriter($s, [System.Text.Encoding]::UTF8)
            $w.AutoFlush = $true
            $r = New-Object System.IO.StreamReader($s, [System.Text.Encoding]::UTF8)
            $w.WriteLine($Cmd)
            $resp = $r.ReadLine()
            return ($resp | ConvertFrom-Json)
        }
    } catch {} finally { $c.Close() }
    return $null
}

# -----------------------------------------------------------------------------
# STEP 1: Compile Benchmark APK
# -----------------------------------------------------------------------------
if (-not $SkipBuild) {
    Write-Host "`n[1/6] Building Benchmark APK..." -ForegroundColor Yellow
    & powershell.exe -ExecutionPolicy Bypass -File "$rootDir\scripts\windows\build-benchmark-app.ps1"
    if ($LASTEXITCODE -ne 0) { throw "Benchmark APK build failed!" }
}

# -----------------------------------------------------------------------------
# STEP 2: Boot / Verify 120Hz Emulator
# -----------------------------------------------------------------------------
$runningDevs = Invoke-AdbGlobalOutput "devices"
$isDevOnline = ($runningDevs -match "emulator-5554\s+device")

if (-not $isDevOnline -and -not $SkipBoot) {
    Write-Host "`n[2/6] Booting Clean 120Hz Emulator..." -ForegroundColor Yellow
    Terminate-Emulator
    Ensure-AvdConfig120

    $allArgs = @("-avd", $AvdName, "-port", "5554", "-accel", "on", "-gpu", "host", "-no-skin", "-no-snapshot", "-no-snapshot-save", "-no-boot-anim")
    $emuProc = Start-Process -FilePath $emulator -ArgumentList $allArgs -PassThru

    Write-Host "  Waiting for emulator boot completion..." -ForegroundColor Gray
    $booted = $false
    $timeout = [DateTime]::UtcNow.AddSeconds(90)
    while ([DateTime]::UtcNow -lt $timeout) {
        $bootProp = Invoke-AdbOutput "shell getprop sys.boot_completed"
        if ($bootProp -eq "1") { $booted = $true; break }
        Start-Sleep -Seconds 2
    }
    if (-not $booted) { throw "Emulator boot timed out!" }
    Write-Host "  [OK] Emulator booted successfully (PID: $($emuProc.Id))." -ForegroundColor Green
} else {
    Write-Host "`n[2/6] Verifying Running Emulator..." -ForegroundColor Yellow
}

# Apply 120Hz system refresh rate policy & geometry
Write-Host "  Configuring 120Hz Refresh Policy & 1920x1200 Display Geometry..." -ForegroundColor Gray
Invoke-AdbSilent "shell settings put system peak_refresh_rate 120.0" | Out-Null
Invoke-AdbSilent "shell settings put system min_refresh_rate 120.0" | Out-Null
Invoke-AdbSilent "shell wm size 1920x1200" | Out-Null
Invoke-AdbSilent "shell wm density 280" | Out-Null
Invoke-AdbSilent "shell settings put global policy_control immersive.full=*" | Out-Null

# Install / update benchmark APK
$apkPath = "$rootDir\bin\TabletDroid.Benchmark.apk"
Write-Host "  Installing Benchmark APK ($apkPath)..." -ForegroundColor Gray
Invoke-AdbSilent "uninstall com.tabletdroid.benchmark" | Out-Null
$installOut = Invoke-AdbOutput "install -r -d -t `"$apkPath`""
if ($installOut -notmatch "Success") { throw "Failed to install benchmark APK: $installOut" }
Write-Host "  [OK] Benchmark APK installed successfully." -ForegroundColor Green

# -----------------------------------------------------------------------------
# Statistical Helper Functions
# -----------------------------------------------------------------------------
function Get-Percentile {
    param([double[]]$Values, [double]$Percentile)
    if ($null -eq $Values -or $Values.Count -eq 0) { return 0.0 }
    $sorted = $Values | Sort-Object
    $rank = ($Percentile / 100.0) * ($sorted.Count - 1)
    $low = [int][math]::Floor($rank)
    $high = [int][math]::Ceiling($rank)
    if ($low -eq $high) { return [math]::Round($sorted[$low], 3) }
    $frac = $rank - $low
    $val = $sorted[$low] + ($sorted[$high] - $sorted[$low]) * $frac
    return [math]::Round($val, 3)
}

function Get-Stats {
    param([double[]]$Values, [string]$Name)
    if ($null -eq $Values -or $Values.Count -eq 0) {
        return [PSCustomObject]@{
            Metric = $Name; Count = 0; Min = 0.0; Max = 0.0; Mean = 0.0; StdDev = 0.0;
            P50 = 0.0; P90 = 0.0; P95 = 0.0; P99 = 0.0
        }
    }
    $sorted = $Values | Sort-Object
    $min = [math]::Round($sorted[0], 3)
    $max = [math]::Round($sorted[-1], 3)
    $sum = ($Values | Measure-Object -Sum).Sum
    $mean = [math]::Round($sum / $Values.Count, 3)
    
    $sumSqDiff = 0.0
    foreach ($v in $Values) { $sumSqDiff += [math]::Pow($v - $mean, 2) }
    $stdDev = if ($Values.Count -gt 1) { [math]::Round([math]::Sqrt($sumSqDiff / ($Values.Count - 1)), 3) } else { 0.0 }
    
    return [PSCustomObject]@{
        Metric = $Name
        Count = $Values.Count
        Min = $min
        Max = $max
        Mean = $mean
        StdDev = $stdDev
        P50 = (Get-Percentile -Values $sorted -Percentile 50)
        P90 = (Get-Percentile -Values $sorted -Percentile 90)
        P95 = (Get-Percentile -Values $sorted -Percentile 95)
        P99 = (Get-Percentile -Values $sorted -Percentile 99)
    }
}

# -----------------------------------------------------------------------------
# Workload Execution & Logcat Extraction Function
# -----------------------------------------------------------------------------
function Run-InputLatencyWorkload {
    param(
        [string]$ConditionName
    )

    Write-Host "  [Launch] Starting InputProbeActivity in Canonical Mode..." -ForegroundColor Cyan
    Invoke-AdbSilent "shell am start -S -n com.tabletdroid.benchmark/.InputProbeActivity --ez canonical_mode true" | Out-Null
    Start-Sleep -Seconds 2

    # Clear logcat
    Invoke-AdbSilent "logcat -c" | Out-Null
    Start-Sleep -Milliseconds 300

    Write-Host "  [Workload 1/3] Executing $TapCount discrete TAPs across viewport..." -ForegroundColor Gray
    for ($i = 0; $i -lt $TapCount; $i++) {
        $x = 200 + (($i * 37) % 1500)
        $y = 200 + (($i * 29) % 800)
        Invoke-AdbSilent "shell input tap $x $y" | Out-Null
        Start-Sleep -Milliseconds 60
    }

    Write-Host "  [Workload 2/3] Executing $DragCount continuous DRAGs (sustained MOVE sequences)..." -ForegroundColor Gray
    for ($i = 0; $i -lt $DragCount; $i++) {
        $x1 = 300 + (($i * 73) % 1200)
        $y1 = 300 + (($i * 51) % 600)
        $x2 = $x1 + 300
        $y2 = $y1 + 250
        Invoke-AdbSilent "shell input swipe $x1 $y1 $x2 $y2 400" | Out-Null
        Start-Sleep -Milliseconds 120
    }

    Write-Host "  [Workload 3/3] Executing $SwipeCount rapid SWIPEs / FLINGs..." -ForegroundColor Gray
    for ($i = 0; $i -lt $SwipeCount; $i++) {
        $x1 = 1400 - (($i * 61) % 800)
        $y1 = 800 - (($i * 47) % 500)
        $x2 = $x1 - 400
        $y2 = $y1 - 300
        Invoke-AdbSilent "shell input swipe $x1 $y1 $x2 $y2 150" | Out-Null
        Start-Sleep -Milliseconds 100
    }

    Start-Sleep -Seconds 2

    # Extract logcat
    Write-Host "  [Extract] Retrieving and parsing INPUT_PROBE_JSON records..." -ForegroundColor Gray
    $logcatRaw = Invoke-AdbOutput "logcat -d -s TabletDroidInputProbe"
    $matches = [regex]::Matches($logcatRaw, 'INPUT_PROBE_JSON:\s*(\{.*\})')

    $records = [System.Collections.Generic.List[PSCustomObject]]::new()
    $invalidCount = 0

    foreach ($m in $matches) {
        try {
            $j = $m.Groups[1].Value | ConvertFrom-Json
            
            # Validation rules: schemaVersion == 2, sequenceId > 0, eventToDrawMs > 0
            if ($j.schemaVersion -eq 2 -and $j.sequenceId -gt 0 -and $j.eventToDrawMs -gt 0) {
                $records.Add([PSCustomObject]@{
                    schemaVersion = [int]$j.schemaVersion
                    sequenceId = [int]$j.sequenceId
                    gestureId = [int]$j.gestureId
                    action = [string]$j.action
                    actionCode = [int]$j.actionCode
                    eventUptime = [int64]$j.eventUptime
                    receiveUptime = [int64]$j.receiveUptime
                    receiveNano = [int64]$j.receiveNano
                    choreographerFrameNano = [int64]$j.choreographerFrameNano
                    drawNano = [int64]$j.drawNano
                    x = [double]$j.x
                    y = [double]$j.y
                    eventToDispatchMs = [double]$j.eventToDispatchMs
                    dispatchToFrameMs = [double]$j.dispatchToFrameMs
                    frameToDrawMs = [double]$j.frameToDrawMs
                    eventToDrawMs = [double]$j.eventToDrawMs
                })
            } else {
                $invalidCount++
            }
        } catch {
            $invalidCount++
        }
    }

    Write-Host "  [Result] Collected $($records.Count) valid records ($invalidCount invalid/rejected)." -ForegroundColor Green
    return @{
        Condition = $ConditionName
        Records = $records
        InvalidCount = $invalidCount
        RawLogcat = $logcatRaw
    }
}

function Analyze-ConditionDataset {
    param(
        [hashtable]$Dataset
    )

    $records = $Dataset.Records
    $cond = $Dataset.Condition

    # Segregate DOWN, MOVE, UP
    $downList = $records | Where-Object { $_.action -eq "DOWN" }
    $moveList = $records | Where-Object { $_.action -eq "MOVE" }
    $upList = $records | Where-Object { $_.action -eq "UP" }

    # Cold vs Warm segregation (Initial 5 events vs Warm events)
    $coldList = if ($records.Count -ge 5) { $records[0..4] } else { $records }
    $warmList = if ($records.Count -gt 5) { $records[5..($records.Count - 1)] } else { @() }

    $coldDownList = $coldList | Where-Object { $_.action -eq "DOWN" }
    $warmDownList = $warmList | Where-Object { $_.action -eq "DOWN" }

    # DOWN Stats
    $downEvtDisp = Get-Stats -Values ($downList | ForEach-Object { $_.eventToDispatchMs }) -Name "DOWN_EventToDispatch"
    $downDispFrame = Get-Stats -Values ($downList | ForEach-Object { $_.dispatchToFrameMs }) -Name "DOWN_DispatchToFrame"
    $downFrameDraw = Get-Stats -Values ($downList | ForEach-Object { $_.frameToDrawMs }) -Name "DOWN_FrameToDraw"
    $downEvtDraw = Get-Stats -Values ($downList | ForEach-Object { $_.eventToDrawMs }) -Name "DOWN_EventToDraw"

    # MOVE Stats
    $moveEvtDisp = Get-Stats -Values ($moveList | ForEach-Object { $_.eventToDispatchMs }) -Name "MOVE_EventToDispatch"
    $moveDispFrame = Get-Stats -Values ($moveList | ForEach-Object { $_.dispatchToFrameMs }) -Name "MOVE_DispatchToFrame"
    $moveFrameDraw = Get-Stats -Values ($moveList | ForEach-Object { $_.frameToDrawMs }) -Name "MOVE_FrameToDraw"
    $moveEvtDraw = Get-Stats -Values ($moveList | ForEach-Object { $_.eventToDrawMs }) -Name "MOVE_EventToDraw"

    # Cold vs Warm Stats
    $coldEvtDraw = Get-Stats -Values ($coldList | ForEach-Object { $_.eventToDrawMs }) -Name "Cold_EventToDraw"
    $warmEvtDraw = Get-Stats -Values ($warmList | ForEach-Object { $_.eventToDrawMs }) -Name "Warm_EventToDraw"
    $initialPenaltyMs = [math]::Round($coldEvtDraw.Mean - $warmEvtDraw.Mean, 3)

    return [PSCustomObject]@{
        Condition = $cond
        TotalRecords = $records.Count
        InvalidCount = $Dataset.InvalidCount
        DownCount = $downList.Count
        MoveCount = $moveList.Count
        UpCount = $upList.Count
        
        Down_EventToDispatch = $downEvtDisp
        Down_DispatchToFrame = $downDispFrame
        Down_FrameToDraw = $downFrameDraw
        Down_EventToDraw = $downEvtDraw

        Move_EventToDispatch = $moveEvtDisp
        Move_DispatchToFrame = $moveDispFrame
        Move_FrameToDraw = $moveFrameDraw
        Move_EventToDraw = $moveEvtDraw

        Cold_EventToDraw = $coldEvtDraw
        Warm_EventToDraw = $warmEvtDraw
        InitialPenaltyMs = $initialPenaltyMs
    }
}

# -----------------------------------------------------------------------------
# STEP 3: Standalone Latency Measurement
# -----------------------------------------------------------------------------
Write-Host "`n[3/6] Running Standalone Emulator Input Latency Benchmark..." -ForegroundColor Yellow
$standaloneData = Run-InputLatencyWorkload -ConditionName "Standalone_Emulator"
$standaloneSummary = Analyze-ConditionDataset -Dataset $standaloneData

# Save Standalone Events & Summary
$standaloneData.Records | ForEach-Object { $_ | ConvertTo-Json -Compress } | Set-Content -Path "$sessionOutputDir\standalone-events.jsonl" -Encoding UTF8
$standaloneSummary | ConvertTo-Json -Depth 5 | Set-Content -Path "$sessionOutputDir\standalone-summary.json" -Encoding UTF8

Write-Host "  [OK] Standalone Benchmark Complete: $($standaloneSummary.TotalRecords) samples (DOWN: $($standaloneSummary.DownCount), MOVE: $($standaloneSummary.MoveCount))" -ForegroundColor Green
Write-Host "       DOWN Event->Draw: P50=$($standaloneSummary.Down_EventToDraw.P50) ms, P95=$($standaloneSummary.Down_EventToDraw.P95) ms, P99=$($standaloneSummary.Down_EventToDraw.P99) ms" -ForegroundColor Cyan
Write-Host "       MOVE Event->Draw: P50=$($standaloneSummary.Move_EventToDraw.P50) ms, P95=$($standaloneSummary.Move_EventToDraw.P95) ms, P99=$($standaloneSummary.Move_EventToDraw.P99) ms" -ForegroundColor Cyan

# -----------------------------------------------------------------------------
# STEP 4: Host Embedded Latency Measurement (Win32 SetParent)
# -----------------------------------------------------------------------------
Write-Host "`n[4/6] Building & Launching TabletDroid.Host for Embedded Benchmark..." -ForegroundColor Yellow
$hostProj = "$rootDir\host\TabletDroid.Host\TabletDroid.Host.csproj"
& $dotnet build $hostProj -c Debug > $null
$hostDll = (Resolve-Path "$rootDir\host\TabletDroid.Host\bin\Debug\net9.0-windows\TabletDroid.Host.dll").Path
$hostProc = Start-Process -FilePath $dotnet -ArgumentList "`"$hostDll`" --auto-embed --automation" -PassThru
Start-Sleep -Seconds 3

# Verify Host Embedding
$isEmbedVerified = $false
$lastGeom = $null
for ($i = 0; $i -lt 20; $i++) {
    $lastGeom = Invoke-HostCmd -Cmd "GET_GEOMETRY"
    if ($null -ne $lastGeom -and $lastGeom.isEmbedded -eq $true) {
        $isEmbedVerified = $true
        break
    }
    if ($i -ge 2) { Invoke-HostCmd -Cmd "EMBED" | Out-Null }
    Start-Sleep -Milliseconds 500
}

if (-not $isEmbedVerified) {
    if (-not $hostProc.HasExited) { Stop-Process -Id $hostProc.Id -Force -ErrorAction SilentlyContinue }
    throw "[FATAL] Host embed verification failed! isEmbedded was not true."
}

Write-Host "  [HOST_EMBED_VERIFIED] Embedded HWND=$($lastGeom.embeddedHwnd), Viewport=$($lastGeom.physW)x$($lastGeom.physH)" -ForegroundColor Green

Write-Host "  Running Embedded Latency Workload..." -ForegroundColor Yellow
$embeddedData = Run-InputLatencyWorkload -ConditionName "Host_Embedded_SetParent"
$embeddedSummary = Analyze-ConditionDataset -Dataset $embeddedData

# Save Embedded Events & Summary
$embeddedData.Records | ForEach-Object { $_ | ConvertTo-Json -Compress } | Set-Content -Path "$sessionOutputDir\embedded-events.jsonl" -Encoding UTF8
$embeddedSummary | ConvertTo-Json -Depth 5 | Set-Content -Path "$sessionOutputDir\embedded-summary.json" -Encoding UTF8

# Gracefully detach & close Host
Invoke-HostCmd -Cmd "DETACH" | Out-Null
Start-Sleep -Milliseconds 500
if (-not $hostProc.HasExited) {
    Stop-Process -Id $hostProc.Id -Force -ErrorAction SilentlyContinue
}

Write-Host "  [OK] Embedded Benchmark Complete: $($embeddedSummary.TotalRecords) samples (DOWN: $($embeddedSummary.DownCount), MOVE: $($embeddedSummary.MoveCount))" -ForegroundColor Green
Write-Host "       DOWN Event->Draw: P50=$($embeddedSummary.Down_EventToDraw.P50) ms, P95=$($embeddedSummary.Down_EventToDraw.P95) ms, P99=$($embeddedSummary.Down_EventToDraw.P99) ms" -ForegroundColor Cyan
Write-Host "       MOVE Event->Draw: P50=$($embeddedSummary.Move_EventToDraw.P50) ms, P95=$($embeddedSummary.Move_EventToDraw.P95) ms, P99=$($embeddedSummary.Move_EventToDraw.P99) ms" -ForegroundColor Cyan

# -----------------------------------------------------------------------------
# STEP 5: A/B Comparison & Statistical Delta Calculation
# -----------------------------------------------------------------------------
Write-Host "`n[5/6] Calculating Standalone vs Embedded Latency Deltas..." -ForegroundColor Yellow

function Compute-Delta {
    param([double]$Standalone, [double]$Embedded)
    $deltaMs = [math]::Round($Embedded - $Standalone, 3)
    $deltaPct = if ($Standalone -gt 0) { [math]::Round((($Embedded - $Standalone) / $Standalone) * 100.0, 2) } else { 0.0 }
    return @{ DeltaMs = $deltaMs; DeltaPct = $deltaPct }
}

$compRows = [System.Collections.Generic.List[PSCustomObject]]::new()

function Add-CompRow {
    param([string]$MetricName, [double]$StdVal, [double]$EmbVal, [string]$Unit = "ms")
    $d = Compute-Delta -Standalone $StdVal -Embedded $EmbVal
    $compRows.Add([PSCustomObject]@{
        Metric = $MetricName
        Standalone = "$StdVal $Unit"
        Embedded = "$EmbVal $Unit"
        Delta_ms = if ($d.DeltaMs -ge 0) { "+$($d.DeltaMs) ms" } else { "$($d.DeltaMs) ms" }
        Delta_pct = if ($d.DeltaPct -ge 0) { "+$($d.DeltaPct)%" } else { "$($d.DeltaPct)%" }
        RawDeltaMs = $d.DeltaMs
        RawDeltaPct = $d.DeltaPct
    })
}

Add-CompRow -MetricName "DOWN Event->Dispatch P50" -StdVal $standaloneSummary.Down_EventToDispatch.P50 -EmbVal $embeddedSummary.Down_EventToDispatch.P50
Add-CompRow -MetricName "DOWN Event->Dispatch P95" -StdVal $standaloneSummary.Down_EventToDispatch.P95 -EmbVal $embeddedSummary.Down_EventToDispatch.P95

Add-CompRow -MetricName "DOWN Event->Draw P50" -StdVal $standaloneSummary.Down_EventToDraw.P50 -EmbVal $embeddedSummary.Down_EventToDraw.P50
Add-CompRow -MetricName "DOWN Event->Draw P95" -StdVal $standaloneSummary.Down_EventToDraw.P95 -EmbVal $embeddedSummary.Down_EventToDraw.P95
Add-CompRow -MetricName "DOWN Event->Draw P99" -StdVal $standaloneSummary.Down_EventToDraw.P99 -EmbVal $embeddedSummary.Down_EventToDraw.P99

Add-CompRow -MetricName "MOVE Event->Draw P50" -StdVal $standaloneSummary.Move_EventToDraw.P50 -EmbVal $embeddedSummary.Move_EventToDraw.P50
Add-CompRow -MetricName "MOVE Event->Draw P95" -StdVal $standaloneSummary.Move_EventToDraw.P95 -EmbVal $embeddedSummary.Move_EventToDraw.P95
Add-CompRow -MetricName "MOVE Event->Draw P99" -StdVal $standaloneSummary.Move_EventToDraw.P99 -EmbVal $embeddedSummary.Move_EventToDraw.P99

Add-CompRow -MetricName "Initial State Penalty (Cold - Warm)" -StdVal $standaloneSummary.InitialPenaltyMs -EmbVal $embeddedSummary.InitialPenaltyMs

$compRows.Add([PSCustomObject]@{
    Metric = "Total Valid Events"
    Standalone = "$($standaloneSummary.TotalRecords)"
    Embedded = "$($embeddedSummary.TotalRecords)"
    Delta_ms = "$($embeddedSummary.TotalRecords - $standaloneSummary.TotalRecords)"
    Delta_pct = "N/A"
    RawDeltaMs = 0.0
    RawDeltaPct = 0.0
})

$compRows.Add([PSCustomObject]@{
    Metric = "Missing / Invalid Events"
    Standalone = "$($standaloneSummary.InvalidCount)"
    Embedded = "$($embeddedSummary.InvalidCount)"
    Delta_ms = "$($embeddedSummary.InvalidCount - $standaloneSummary.InvalidCount)"
    Delta_pct = "N/A"
    RawDeltaMs = 0.0
    RawDeltaPct = 0.0
})

# Save comparison.csv
$compRows | Export-Csv -Path "$sessionOutputDir\comparison.csv" -NoTypeInformation -Encoding UTF8

# Save environment metadata
$envMetadata = @{
    Timestamp = $timestamp
    HostHardware = "ASUS ROG Flow Z13 (Intel Core i9-12900H, NVIDIA RTX 3050 Ti Laptop GPU, 16GB RAM)"
    HostOS = "Windows 11 Home 23H2 (Hypervisor: WHPX)"
    Resolution = "1920x1200 @ 280dpi"
    RefreshRate = "120 Hz (hw.lcd.vsync=120, peak_refresh_rate=120, min_refresh_rate=120)"
    GpuMode = "host"
    GlTransport = "pipe"
    Embedding = "Win32 SetParent Child Window"
    TargetPackage = "com.tabletdroid.benchmark"
    TargetActivity = "com.tabletdroid.benchmark/.InputProbeActivity"
    TapCount = $TapCount
    DragCount = $DragCount
    SwipeCount = $SwipeCount
    StandaloneValidRecords = $standaloneSummary.TotalRecords
    EmbeddedValidRecords = $embeddedSummary.TotalRecords
}
$envMetadata | ConvertTo-Json -Depth 3 | Set-Content -Path "$sessionOutputDir\environment.json" -Encoding UTF8

# -----------------------------------------------------------------------------
# STEP 6: Display Summary & A/B Comparison Table
# -----------------------------------------------------------------------------
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host " CANONICAL INPUT LATENCY A/B COMPARISON TABLE" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan

$fmtHeader = "{0,-35} | {1,-14} | {2,-14} | {3,-12} | {4,-10}"
Write-Host ($fmtHeader -f "Metric", "Standalone", "Embedded", "Delta (ms)", "Delta (%)") -ForegroundColor Yellow
Write-Host ("-" * 92) -ForegroundColor Gray

foreach ($r in $compRows) {
    Write-Host ($fmtHeader -f $r.Metric, $r.Standalone, $r.Embedded, $r.Delta_ms, $r.Delta_pct) -ForegroundColor White
}
Write-Host ("-" * 92) -ForegroundColor Gray

Write-Host "`n[ARTIFACTS SAVED] $sessionOutputDir" -ForegroundColor Green
Write-Host " - environment.json" -ForegroundColor Green
Write-Host " - standalone-events.jsonl" -ForegroundColor Green
Write-Host " - standalone-summary.json" -ForegroundColor Green
Write-Host " - embedded-events.jsonl" -ForegroundColor Green
Write-Host " - embedded-summary.json" -ForegroundColor Green
Write-Host " - comparison.csv" -ForegroundColor Green
