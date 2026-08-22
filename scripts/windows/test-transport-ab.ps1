param(
    [string]$DeviceSerial = "emulator-5554",
    [string]$AvdName = "TabletDroid_Z13_Play",
    [string]$PackageName = "com.tabletdroid.benchmark",
    [string]$ActivityName = "com.tabletdroid.benchmark/.BenchmarkActivity",
    [int]$WarmupSeconds = 10,
    [int]$MeasurementSeconds = 30,
    [double]$VelocityPxSec = 800.0,
    [int]$Trials = 5,
    [string]$OutputDir = "$PSScriptRoot\..\..\docs\performance"
)

$ErrorActionPreference = "Continue"

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
$avdConfig = "$env:USERPROFILE\.android\avd\$AvdName.avd\config.ini"

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host " TabletDroid Graphics Transport Characterization Suite (pipe vs asg vs virtio-gpu)" -ForegroundColor Cyan
Write-Host " Device Serial     : $DeviceSerial" -ForegroundColor Cyan
Write-Host " Target Package    : $PackageName" -ForegroundColor Cyan
Write-Host " Benchmark Specs   : 1920x1200 @ 280dpi, ${WarmupSeconds}s Warmup, ${MeasurementSeconds}s Measure, $VelocityPxSec px/s" -ForegroundColor Cyan
Write-Host " Telemetry Mode    : Strictly OFF (Primary Performance Baseline)" -ForegroundColor Cyan
Write-Host "================================================================================`n" -ForegroundColor Cyan

function Set-AvdGlTransport {
    param([string]$transport)
    $lines = Get-Content $avdConfig
    $newLines = @()
    $found = $false
    foreach ($l in $lines) {
        if ($l -match "^hw\.gltransport\s*=") {
            $newLines += "hw.gltransport = $transport"
            $found = $true
        } else {
            $newLines += $l
        }
    }
    if (-not $found) {
        $newLines += "hw.gltransport = $transport"
    }
    [System.IO.File]::WriteAllLines($avdConfig, $newLines)
}

function Restart-ColdBootEmulator {
    param([string]$transport)
    Write-Host "`n>>> [COLD BOOT] Restarting emulator with hw.gltransport = $transport <<<" -ForegroundColor Yellow

    & $adb -s $DeviceSerial emu kill > $null 2>&1
    Start-Sleep -Seconds 3
    Get-Process -Name "*qemu*", "*emulator*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    Set-AvdGlTransport -transport $transport

    $logFile = "$OutputDir\..\..\scratch\startup_$transport.log"
    $proc = Start-Process -FilePath $emulator -ArgumentList "-avd $AvdName -accel on -gpu host -no-snapshot -no-boot-anim -no-audio" -PassThru

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $booted = $false
    while ($sw.Elapsed.TotalSeconds -lt 100) {
        Start-Sleep -Seconds 3
        if ($proc.HasExited) {
            Write-Host "  [FAIL] Emulator exited prematurely with code $($proc.ExitCode)!" -ForegroundColor Red
            break
        }
        $bootProp = (& $adb -s $DeviceSerial shell getprop sys.boot_completed 2>$null)
        if ($bootProp -and $bootProp.Trim() -eq "1") {
            $booted = $true
            Write-Host "  [OK] Device booted in $([math]::Round($sw.Elapsed.TotalSeconds, 1))s!" -ForegroundColor Green
            break
        }
    }

    if (-not $booted) {
        return [PSCustomObject]@{
            Success = $false
            Status = "BOOT_FAILED"
            Egl = "N/A"
            Gralloc = "N/A"
        }
    }

    Start-Sleep -Seconds 2
    & $adb -s $DeviceSerial shell wm size 1920x1200 > $null 2>&1
    & $adb -s $DeviceSerial shell wm density 280 > $null 2>&1
    & $adb -s $DeviceSerial shell dumpsys SurfaceFlinger --timestats -enable > $null 2>&1

    $egl = (& $adb -s $DeviceSerial shell getprop ro.hardware.egl 2>$null).Trim()
    $gralloc = (& $adb -s $DeviceSerial shell getprop ro.hardware.gralloc 2>$null).Trim()

    return [PSCustomObject]@{
        Success = $true
        Status = "BOOT_OK"
        Egl = $egl
        Gralloc = $gralloc
    }
}

function Get-SurfaceFlingerTargetLayerStats {
    param([string]$pkg)
    $rawSf = (& $adb -s $DeviceSerial shell dumpsys SurfaceFlinger --timestats -dump 2>$null) | Out-String
    $blocks = $rawSf -split "displayRefreshRate"
    
    $candidateLayers = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($b in $blocks) {
        if ($b -match "layerName\s*=\s*(?<name>[^\r\n]+)") {
            $layerName = $Matches['name'].Trim()
            if ($layerName -match $pkg -and $layerName -notmatch "Splash Screen") {
                $totalFrames = 0
                if ($b -match "totalFrames\s*=\s*(?<tf>\d+)") {
                    $totalFrames = [int64]$Matches['tf']
                }
                $layerId = 0
                if ($layerName -match "#(?<id>\d+)") {
                    $layerId = [int64]$Matches['id']
                }
                $candidateLayers.Add([PSCustomObject]@{
                    LayerName = $layerName
                    LayerId = $layerId
                    TotalFrames = $totalFrames
                    Found = $true
                })
            }
        }
    }
    
    if ($candidateLayers.Count -gt 0) {
        return ($candidateLayers | Sort-Object LayerId -Descending | Select-Object -First 1)
    }
    
    return [PSCustomObject]@{
        LayerName = "NONE"
        LayerId = 0
        TotalFrames = 0
        Found = $false
    }
}

function Measure-SingleTrial {
    param(
        [string]$pkg,
        [int]$warmupSec,
        [int]$measureSec,
        [double]$velocity,
        [string]$testLabel,
        [string]$conditionKey,
        [int]$trialNum
    )

    Write-Host "  -> [Trial $trialNum] Running Workload ($testLabel | Warmup:${warmupSec}s, Measure:${measureSec}s)..." -ForegroundColor Gray

    # 1. Foreground target activity
    & $adb -s $DeviceSerial shell am start -n $ActivityName > $null 2>&1
    Start-Sleep -Milliseconds 600

    # 2. Reset In-App State & Gfxinfo
    & $adb -s $DeviceSerial shell am broadcast -p $pkg -a com.tabletdroid.benchmark.ACTION_RESET > $null 2>&1
    & $adb -s $DeviceSerial shell dumpsys gfxinfo $pkg reset > $null 2>&1
    & $adb -s $DeviceSerial logcat -c > $null 2>&1
    Start-Sleep -Milliseconds 400

    # 3. Start In-App Benchmark Engine
    & $adb -s $DeviceSerial shell am broadcast -p $pkg -a com.tabletdroid.benchmark.ACTION_START --ei warmup_sec $warmupSec --ei measure_sec $measureSec --ef velocity_px_s $velocity > $null 2>&1

    # 4. Wait for Warmup
    if ($warmupSec -gt 0) {
        Start-Sleep -Seconds $warmupSec
    }

    # 5. Capture Start Snapshot
    $layerStart = Get-SurfaceFlingerTargetLayerStats -pkg $pkg
    $sfTotalFramesStart = $layerStart.TotalFrames
    $targetLayerName = $layerStart.LayerName
    $targetLayerFound = $layerStart.Found

    # 6. Active Measurement Interval
    $measureStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    Start-Sleep -Seconds $measureSec
    $measureStopwatch.Stop()
    $actualDurationSec = [math]::Round($measureStopwatch.Elapsed.TotalSeconds, 3)

    # 7. Capture End Snapshot
    $layerEnd = Get-SurfaceFlingerTargetLayerStats -pkg $pkg
    $sfTotalFramesEnd = $layerEnd.TotalFrames

    # 8. Query In-App Status from Logcat
    $logcatRaw = (& $adb -s $DeviceSerial logcat -d -s TabletDroidBenchmark 2>$null) | Out-String
    $inAppStatus = "UNKNOWN"
    $actualDistancePx = 0.0
    $inAppElapsedMs = 0
    $inAppMeasureFrames = 0
    $workloadVersion = "UNKNOWN"

    $jsonMatches = [regex]::Matches($logcatRaw, 'BENCHMARK_STATUS_JSON:\s*(\{.*\})')
    if ($jsonMatches.Count -gt 0) {
        $lastJsonStr = $jsonMatches[$jsonMatches.Count - 1].Groups[1].Value
        try {
            $appMeta = $lastJsonStr | ConvertFrom-Json
            $inAppStatus = $appMeta.status
            $actualDistancePx = [double]$appMeta.actualDistance
            $inAppElapsedMs = [int64]$appMeta.elapsedMeasureMs
            $inAppMeasureFrames = [int64]$appMeta.measureFrames
            $workloadVersion = $appMeta.workloadVersion
        } catch {}
    }

    # 9. Extract gfxinfo framestats
    $rawGfx = & $adb -s $DeviceSerial shell dumpsys gfxinfo $pkg framestats 2>$null
    $frameTimesMs = [System.Collections.Generic.List[double]]::new()
    if ($rawGfx) {
        $inProfile = $false
        $flagsIdx = 0; $intendedIdx = 2; $completedIdx = 16
        foreach ($line in $rawGfx) {
            if ($line -match "---PROFILEDATA---") { $inProfile = -not $inProfile; continue }
            if (-not $inProfile) { continue }
            if ($line -match "^Flags,") {
                $headers = $line.Split(',')
                for ($i = 0; $i -lt $headers.Count; $i++) {
                    $h = $headers[$i].Trim().ToUpper()
                    if ($h -eq "FLAGS") { $flagsIdx = $i }
                    if ($h -eq "INTENDEDVSYNC" -or $h -eq "INTENDED_VSYNC") { $intendedIdx = $i }
                    if ($h -eq "FRAMECOMPLETED" -or $h -eq "FRAME_COMPLETED") { $completedIdx = $i }
                }
                continue
            }
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $parts = $line.Trim().Split(',')
            if ($parts.Count -gt $completedIdx) {
                try {
                    $intendedVsync = [int64]$parts[$intendedIdx]
                    $frameCompleted = [int64]$parts[$completedIdx]
                    if ($intendedVsync -gt 0 -and $frameCompleted -gt $intendedVsync) {
                        $durationMs = ($frameCompleted - $intendedVsync) / 1000000.0
                        if ($durationMs -gt 0 -and $durationMs -lt 5000) {
                            $frameTimesMs.Add($durationMs)
                        }
                    }
                } catch {}
            }
        }
    }

    $capturedRecords = $frameTimesMs.Count
    $sfDeltaFrames = [math]::Max(0, $sfTotalFramesEnd - $sfTotalFramesStart)
    $presentedFps = if ($actualDurationSec -gt 0) { [math]::Round($sfDeltaFrames / $actualDurationSec, 2) } else { 0.0 }

    # 10. Fail-Closed Validation Gates
    $statusReason = "VALID"
    $isValid = $true

    $expectedDistance = $velocity * $actualDurationSec
    $expectedDurationMs = $measureSec * 1000

    if (-not $targetLayerFound) {
        $isValid = $false
        $statusReason = "INVALID / TARGET_LAYER_NOT_FOUND"
    } elseif ($capturedRecords -eq 0) {
        $isValid = $false
        $statusReason = "INVALID / GFXINFO_UNAVAILABLE"
    } elseif ($workloadVersion -ne "1.0.0") {
        $isValid = $false
        $statusReason = "INVALID / WORKLOAD_VERSION_MISMATCH"
    } elseif ($inAppStatus -ne "COMPLETE") {
        $isValid = $false
        $statusReason = "INVALID / WORKLOAD_NOT_COMPLETE"
    } elseif ($inAppElapsedMs -lt ($expectedDurationMs * 0.90) -or $inAppElapsedMs -gt ($expectedDurationMs * 1.10 + 2000)) {
        $isValid = $false
        $statusReason = "INVALID / WORKLOAD_DURATION_MISMATCH"
    } elseif ($expectedDistance -gt 0 -and (([math]::Abs($actualDistancePx - $expectedDistance) / $expectedDistance) -gt 0.10)) {
        $isValid = $false
        $statusReason = "INVALID / WORKLOAD_DISTANCE_OUT_OF_RANGE"
    }

    if ($capturedRecords -gt 0) {
        $sorted = $frameTimesMs | Sort-Object
        $avgLatencyMs = [math]::Round(($sorted | Measure-Object -Average).Average, 2)
        $p50Idx = [math]::Min([int]($capturedRecords * 0.50), $capturedRecords - 1)
        $p90Idx = [math]::Min([int]($capturedRecords * 0.90), $capturedRecords - 1)
        $p99Idx = [math]::Min([int]($capturedRecords * 0.99), $capturedRecords - 1)
        $p50Ms = [math]::Round($sorted[$p50Idx], 2)
        $p90Ms = [math]::Round($sorted[$p90Idx], 2)
        $p99Ms = [math]::Round($sorted[$p99Idx], 2)
        $jankCount = ($sorted | Where-Object { $_ -gt 16.67 }).Count
        $jankPercent = [math]::Round(($jankCount / $capturedRecords) * 100.0, 1)
    } else {
        $avgLatencyMs = -1.0; $p50Ms = -1.0; $p90Ms = -1.0; $p99Ms = -1.0; $jankPercent = -1.0
    }

    return [PSCustomObject]@{
        Label = $testLabel
        Condition = $conditionKey
        Trial = $trialNum
        Status = $statusReason
        IsValid = $isValid
        WorkloadVersion = $workloadVersion
        RequestedVelocity = $velocity
        ActualDistancePx = $actualDistancePx
        ExpectedDistancePx = [math]::Round($expectedDistance, 1)
        ActualDurationSec = $actualDurationSec
        SfLayerName = $targetLayerName
        SfStartFrames = $sfTotalFramesStart
        SfEndFrames = $sfTotalFramesEnd
        SfDeltaFrames = $sfDeltaFrames
        PresentedFps = $presentedFps
        CapturedGfxRecords = $capturedRecords
        FrameLatencyAvgMs = $avgLatencyMs
        P50Ms = $p50Ms
        P90Ms = $p90Ms
        P99Ms = $p99Ms
        JankPercent = $jankPercent
    }
}

# --- Execution Suite ---
$conditions = @(
    @{ Key = "CondA_Pipe_Initial"; Name = "A. pipe (Goldfish Pipe - Initial)"; Transport = "pipe" },
    @{ Key = "CondB_ASG";          Name = "B. asg (Address Space Graphics)";    Transport = "asg" },
    @{ Key = "CondC_VirtioGpu";    Name = "C. virtio-gpu (VirtIO GPU)";         Transport = "virtio-gpu" },
    @{ Key = "CondD_Pipe_Retest";  Name = "D. pipe (Goldfish Pipe - Retest/Drift)"; Transport = "pipe" }
)

$allRawTrials = [System.Collections.Generic.List[PSCustomObject]]::new()
$conditionSummaries = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($cond in $conditions) {
    $cKey = $cond.Key
    $cName = $cond.Name
    $cTrans = $cond.Transport

    $bootResult = Restart-ColdBootEmulator -transport $cTrans
    if (-not $bootResult.Success) {
        Write-Warning "Condition '$cName' FAILED to boot!"
        $conditionSummaries.Add([PSCustomObject]@{
            Condition = $cName
            Key = $cKey
            Transport = $cTrans
            BootStatus = $bootResult.Status
            ValidTrials = "0 / $Trials"
            PresentedFpsMedian = 0.0
            PresentedFpsMin = 0.0
            PresentedFpsMax = 0.0
            PresentedFpsStdDev = 0.0
            PresentedFpsCVPercent = 0.0
            ActualDistanceMedian = 0.0
            DistanceCVPercent = 0.0
            LatencyAvgMedianMs = 0.0
            P50MedianMs = 0.0
            P90MedianMs = 0.0
            P99MedianMs = 0.0
            JankMedianPercent = 0.0
            GateStatus = "UNSUPPORTED / BOOT_FAILED"
        })
        continue
    }

    # Execute 5 trials
    $condTrials = [System.Collections.Generic.List[PSCustomObject]]::new()
    for ($t = 1; $t -le $Trials; $t++) {
        $trialData = Measure-SingleTrial -pkg $PackageName -warmupSec $WarmupSeconds -measureSec $MeasurementSeconds -velocity $VelocityPxSec -testLabel $cName -conditionKey $cKey -trialNum $t
        $allRawTrials.Add($trialData)
        if ($trialData.IsValid) { $condTrials.Add($trialData) }
        Start-Sleep -Milliseconds 600
    }

    $validCount = $condTrials.Count
    if ($validCount -ge 1) {
        $sortedFps = $condTrials | Select-Object -ExpandProperty PresentedFps | Sort-Object
        $sortedDist = $condTrials | Select-Object -ExpandProperty ActualDistancePx | Sort-Object
        $sortedLatency = $condTrials | Select-Object -ExpandProperty FrameLatencyAvgMs | Sort-Object
        $sortedP50 = $condTrials | Select-Object -ExpandProperty P50Ms | Sort-Object
        $sortedP90 = $condTrials | Select-Object -ExpandProperty P90Ms | Sort-Object
        $sortedP99 = $condTrials | Select-Object -ExpandProperty P99Ms | Sort-Object
        $sortedJank = $condTrials | Select-Object -ExpandProperty JankPercent | Sort-Object

        $medianIdx = [int]($validCount / 2)
        $avgFps = ($sortedFps | Measure-Object -Average).Average
        $sumSqFps = 0.0; foreach ($v in $sortedFps) { $sumSqFps += [math]::Pow($v - $avgFps, 2) }
        $stdDevFps = [math]::Round([math]::Sqrt($sumSqFps / $validCount), 2)
        $cvFps = if ($avgFps -gt 0) { [math]::Round(($stdDevFps / $avgFps) * 100.0, 1) } else { 0.0 }

        $avgDist = ($sortedDist | Measure-Object -Average).Average
        $sumSqDist = 0.0; foreach ($d in $sortedDist) { $sumSqDist += [math]::Pow($d - $avgDist, 2) }
        $stdDevDist = [math]::Round([math]::Sqrt($sumSqDist / $validCount), 2)
        $cvDist = if ($avgDist -gt 0) { [math]::Round(($stdDevDist / $avgDist) * 100.0, 1) } else { 0.0 }

        $gateStatus = if ($validCount -eq $Trials -and $cvDist -le 10.0) { "PASS" } else { "INCONCLUSIVE" }

        $conditionSummaries.Add([PSCustomObject]@{
            Condition = $cName
            Key = $cKey
            Transport = $cTrans
            BootStatus = "BOOT_OK (egl=$($bootResult.Egl))"
            ValidTrials = "$validCount / $Trials"
            PresentedFpsMedian = $sortedFps[$medianIdx]
            PresentedFpsMin = ($sortedFps | Measure-Object -Minimum).Minimum
            PresentedFpsMax = ($sortedFps | Measure-Object -Maximum).Maximum
            PresentedFpsStdDev = $stdDevFps
            PresentedFpsCVPercent = $cvFps
            ActualDistanceMedian = $sortedDist[$medianIdx]
            DistanceCVPercent = $cvDist
            LatencyAvgMedianMs = $sortedLatency[$medianIdx]
            P50MedianMs = $sortedP50[$medianIdx]
            P90MedianMs = $sortedP90[$medianIdx]
            P99MedianMs = $sortedP99[$medianIdx]
            JankMedianPercent = $sortedJank[$medianIdx]
            GateStatus = $gateStatus
        })
    }
}

# Summary to Console
Write-Host "`n========================================================================================================================" -ForegroundColor Cyan
Write-Host " TabletDroid Graphics Transport Characterization Summary" -ForegroundColor Cyan
Write-Host "========================================================================================================================" -ForegroundColor Cyan
$conditionSummaries | Format-Table -Property Condition, BootStatus, ValidTrials, PresentedFpsMedian, PresentedFpsCVPercent, ActualDistanceMedian, DistanceCVPercent, P50MedianMs, P90MedianMs, JankMedianPercent, GateStatus -AutoSize | Out-String | Write-Host -ForegroundColor Green

# Save Markdown Report
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
$reportFile = "$OutputDir\graphics_transport_ab.md"

$mdLines = [System.Collections.Generic.List[string]]::new()
$mdLines.Add("# TabletDroid v0.1 Graphics Transport Characterization Report (pipe vs asg vs virtio-gpu)")
$mdLines.Add("")
$mdLines.Add("- **Timestamp**: $timestamp")
$mdLines.Add("- **Host Hardware**: ASUS ROG Flow Z13 (Intel Core i9-12900H, NVIDIA GeForce RTX 3050 Ti Laptop GPU, 16GB RAM)")
$mdLines.Add("- **Host Operating System**: Windows 11 Home 23H2 (Hypervisor: WHPX)")
$mdLines.Add("- **Emulator Version**: 37.1.11.0 (build_id 15917651)")
$mdLines.Add("- **Target Package**: $PackageName")
$mdLines.Add("- **Target Activity**: $ActivityName")
$mdLines.Add("- **Resolution Tested**: 1920x1200 @ 280dpi (Native Tablet Resolution)")
$mdLines.Add("- **Protocol**: 4 Conditions x $Trials Trials x Warmup:${WarmupSeconds}s, Measure:${MeasurementSeconds}s (${VelocityPxSec} px/s, Telemetry OFF)")
$mdLines.Add("- **Frame Rate Source**: SurfaceFlinger Compositor Presentation (`dumpsys SurfaceFlinger --timestats -dump`) on target layer")
$mdLines.Add("- **Latency/Jitter Source**: HWUI Framestats (`dumpsys gfxinfo framestats`)")
$mdLines.Add("")
$mdLines.Add("---")
$mdLines.Add("")
$mdLines.Add("## 1. [MEASURED] Statistical Transport Comparison Matrix")
$mdLines.Add("")
$mdLines.Add("| Condition | Transport | Boot Status | Valid Trials | Presented FPS | FPS [Min, Max] | StdDev | FPS CV% | Actual Distance | Dist CV% | P50 Latency | P90 Latency | Jank % | Gate Status |")
$mdLines.Add("| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |")

foreach ($s in $conditionSummaries) {
    $row = "| **$($s.Condition)** | `$($s.Transport)` | $($s.BootStatus) | $($s.ValidTrials) | **$($s.PresentedFpsMedian) FPS** | [$($s.PresentedFpsMin), $($s.PresentedFpsMax)] | $($s.PresentedFpsStdDev) | $($s.PresentedFpsCVPercent)% | $($s.ActualDistanceMedian) px | $($s.DistanceCVPercent)% | $($s.P50MedianMs) ms | $($s.P90MedianMs) ms | $($s.JankMedianPercent)% | **$($s.GateStatus)** |"
    $mdLines.Add($row)
}

$mdLines.Add("")
$mdLines.Add("### 1.1 All Raw Trial Records")
$mdLines.Add("")
$mdLines.Add("| Trial ID | Condition | Status | Duration (s) | Target Layer | SF Start | SF End | Delta | Presented FPS | Actual Dist (px) | Expected Dist (px) | Gfx Records | Latency Avg (ms) | P50 (ms) | P90 (ms) | Jank % |")
$mdLines.Add("| :--- | :--- | :---: | :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |")

foreach ($r in $allRawTrials) {
    $rRow = "| $($r.Condition) (T$($r.Trial)) | $($r.Label) | $($r.Status) | $($r.ActualDurationSec)s | $($r.SfLayerName) | $($r.SfStartFrames) | $($r.SfEndFrames) | $($r.SfDeltaFrames) | $($r.PresentedFps) FPS | $($r.ActualDistancePx) px | $($r.ExpectedDistancePx) px | $($r.CapturedGfxRecords) | $($r.FrameLatencyAvgMs) ms | $($r.P50Ms) ms | $($r.P90Ms) ms | $($r.JankPercent)% |"
    $mdLines.Add($rRow)
}

$mdLines.Add("")
$mdLines.Add("---")
$mdLines.Add("")
$mdLines.Add("## 2. [IMPLEMENTED] Environment Fingerprint & Transport Protocol")
$mdLines.Add("- **Emulator Version**: 37.1.11.0 (build_id 15917651), Graphics backend: `gfxstream`.")
$mdLines.Add("- **Transport Options Defined in Hardware Properties**: `pipe`, `asg`, `virtio-gpu`, `tcp`.")
$mdLines.Add("- **Isolation Guardrails**: Every condition was executed after a full cold boot (`-no-snapshot -no-boot-anim -no-audio`) to ensure no snapshot or IPC state leaked between conditions.")
$mdLines.Add("- **Order Bias Mitigation**: Tested `pipe (initial)` -> `asg` -> `virtio-gpu` -> `pipe (retest)` to evaluate thermal or time drift.")
$mdLines.Add("")
$mdLines.Add("---")
$mdLines.Add("")
$mdLines.Add("## 3. [INFERENCE] Comparative Analysis & Findings")

$pipe1 = ($conditionSummaries | Where-Object { $_.Key -eq "CondA_Pipe_Initial" } | Select-Object -First 1)
$asg = ($conditionSummaries | Where-Object { $_.Key -eq "CondB_ASG" } | Select-Object -First 1)
$virtio = ($conditionSummaries | Where-Object { $_.Key -eq "CondC_VirtioGpu" } | Select-Object -First 1)
$pipe2 = ($conditionSummaries | Where-Object { $_.Key -eq "CondD_Pipe_Retest" } | Select-Object -First 1)

if ($pipe1 -and $asg) {
    $deltaAsg = [math]::Round($asg.PresentedFpsMedian - $pipe1.PresentedFpsMedian, 2)
    $mdLines.Add("### 3.1 Pipe vs ASG Comparison")
    $mdLines.Add("- **Goldfish Pipe (Initial)**: Presented FPS = **$($pipe1.PresentedFpsMedian) FPS**, P50 = **$($pipe1.P50MedianMs) ms**, Distance = **$($pipe1.ActualDistanceMedian) px** (CV: $($pipe1.DistanceCVPercent)%)")
    $mdLines.Add("- **Address Space Graphics (ASG)**: Presented FPS = **$($asg.PresentedFpsMedian) FPS**, P50 = **$($asg.P50MedianMs) ms**, Distance = **$($asg.ActualDistanceMedian) px** (CV: $($asg.DistanceCVPercent)%)")
    $mdLines.Add("- **Observed Delta (ASG - Pipe)**: **${deltaAsg} FPS**")
    $mdLines.Add("")
    if ($deltaAsg -gt 3.0) {
        $mdLines.Add("> **Finding**: **ASG demonstrates meaningful improvement over pipe** (+${deltaAsg} FPS). Proceeding to ASG ring-size tuning is warranted.")
    } elseif ($deltaAsg -lt -3.0) {
        $mdLines.Add("> **Finding**: **ASG is slower than pipe** (${deltaAsg} FPS). Pipe remains the superior transport.")
    } else {
        $mdLines.Add("> **Finding**: **No meaningful difference between Pipe and ASG** (${deltaAsg} FPS delta). Changing transport mode alone does not relieve the throughput bottleneck.")
    }
}

if ($virtio) {
    $mdLines.Add("")
    $mdLines.Add("### 3.2 VirtIO-GPU Evaluation")
    $mdLines.Add("- **VirtIO-GPU Boot Status**: $($virtio.BootStatus)")
    $mdLines.Add("- **VirtIO-GPU Presented FPS**: **$($virtio.PresentedFpsMedian) FPS**")
}

if ($pipe1 -and $pipe2) {
    $driftFps = [math]::Round($pipe2.PresentedFpsMedian - $pipe1.PresentedFpsMedian, 2)
    $mdLines.Add("")
    $mdLines.Add("### 3.3 Baseline Thermal & Temporal Drift Check")
    $mdLines.Add("- **Pipe Initial**: **$($pipe1.PresentedFpsMedian) FPS**")
    $mdLines.Add("- **Pipe Retest**: **$($pipe2.PresentedFpsMedian) FPS**")
    $mdLines.Add("- **Baseline Drift Delta**: **${driftFps} FPS**")
    if ([math]::Abs($driftFps) -le 1.5) {
        $mdLines.Add("> **Drift Assessment**: Minimal baseline drift (${driftFps} FPS), confirming test consistency.")
    } else {
        $mdLines.Add("> **Drift Assessment**: Noticeable drift (${driftFps} FPS), indicating thermal throttling or background system variation.")
    }
}

$mdLines.Add("")
$mdLines.Add("---")
$mdLines.Add("")
$mdLines.Add("## 4. [OPEN] Residual Architectural Hypotheses")
$mdLines.Add("1. **Host Compositor / Presentation Pipeline**: ANGLE / D3D11 swapchain copy bottlenecks on host window presentation.")
$mdLines.Add("2. **ASG Ring Buffer Sizing [CONDITIONAL]**: Potential throughput limits in default 32KB data ring size.")
$mdLines.Add("")
$mdLines.Add("---")
$mdLines.Add("")
$mdLines.Add("## 5. [DECISION] Next Phase Execution")
$mdLines.Add("- Retain the optimal transport based on empirical data.")
$mdLines.Add("- Proceed to transport parameter exploration or host composition zero-copy pipeline.")

[System.IO.File]::WriteAllLines($reportFile, $mdLines, [System.Text.Encoding]::UTF8)
Write-Host "`n[OK] Graphics transport characterization report written to: $reportFile`n" -ForegroundColor Green
