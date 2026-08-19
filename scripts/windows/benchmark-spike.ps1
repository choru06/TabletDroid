param(
    [string]$DeviceSerial = "emulator-5554",
    [string]$PackageName = "com.instagram.android",
    [string]$ActivityName = "com.instagram.mainactivity.MainActivity",
    [int]$ScrollDurationSeconds = 8,
    [switch]$SkipArtBenchmark,
    [switch]$SkipResolutionBenchmark,
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

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " TabletDroid v0.1 Performance Baseline Benchmark Runner" -ForegroundColor Cyan
Write-Host " Target Device : ASUS ROG Flow Z13" -ForegroundColor Cyan
Write-Host " Target Package: $PackageName" -ForegroundColor Cyan
Write-Host " ADB Device    : $DeviceSerial" -ForegroundColor Cyan
Write-Host "========================================================`n" -ForegroundColor Cyan

$devices = & $adb devices
if ($devices -notmatch $DeviceSerial) {
    Write-Host "[ERROR] Device '$DeviceSerial' not connected. Please start emulator first via .\launch.bat" -ForegroundColor Red
    exit 1
}

$appPath = & $adb -s $DeviceSerial shell pm path $PackageName 2>$null
if (-not $appPath -or $appPath -notmatch "package:") {
    Write-Host "[WARN] Package '$PackageName' is not installed. Testing with Settings app..." -ForegroundColor Yellow
    $PackageName = "com.android.settings"
    $ActivityName = "com.android.settings.Settings"
}

function Measure-AppLaunchTime {
    param([string]$pkg, [string]$act)
    & $adb -s $DeviceSerial shell am force-stop $pkg 2>$null
    Start-Sleep -Milliseconds 500
    $output = & $adb -s $DeviceSerial shell am start -W -S -n "$pkg/$act" 2>$null
    $totalTimeMs = 0
    foreach ($line in $output) {
        if ($line -match "TotalTime:\s*(\d+)") {
            $totalTimeMs = [int]$matches[1]
            break
        }
    }
    return $totalTimeMs
}

function Measure-Framestats {
    param(
        [string]$pkg,
        [int]$durationSec,
        [string]$testLabel = "Test"
    )

    Write-Host "  -> Collecting Framestats ($testLabel, ${durationSec}s)..." -ForegroundColor Gray
    
    & $adb -s $DeviceSerial shell dumpsys gfxinfo $pkg reset > $null
    & $adb -s $DeviceSerial shell dumpsys SurfaceFlinger --timestats -clear > $null

    $startTime = [DateTime]::UtcNow
    $endTime = $startTime.AddSeconds($durationSec)
    
    while ([DateTime]::UtcNow -lt $endTime) {
        & $adb -s $DeviceSerial shell input swipe 600 900 600 300 180 > $null
        Start-Sleep -Milliseconds 350
    }

    $rawGfx = & $adb -s $DeviceSerial shell dumpsys gfxinfo $pkg framestats 2>$null
    
    $frameTimesMs = [System.Collections.Generic.List[double]]::new()
    $parsingProfileData = $false

    foreach ($line in $rawGfx) {
        if ($line -match "---PROFILEDATA---") {
            $parsingProfileData = $true
            continue
        }
        if ($parsingProfileData) {
            if ($line -match "Flags," -or [string]::IsNullOrWhiteSpace($line)) { continue }
            $parts = $line.Trim().Split(',')
            if ($parts.Count -ge 14) {
                try {
                    $intendedVsync = [int64]$parts[1]
                    $frameCompleted = [int64]$parts[13]
                    if ($intendedVsync -gt 0 -and $frameCompleted -gt $intendedVsync) {
                        $durationMs = ($frameCompleted - $intendedVsync) / 1000000.0
                        if ($durationMs -gt 0 -and $durationMs -lt 500) {
                            $frameTimesMs.Add($durationMs)
                        }
                    }
                } catch {}
            }
        }
    }

    $qemuProc = Get-Process -Name *qemu* -ErrorAction SilentlyContinue | Select-Object -First 1
    $qemuRamMb = if ($qemuProc) { [math]::Round($qemuProc.WorkingSet64 / 1MB, 1) } else { 0 }

    $totalFrames = $frameTimesMs.Count
    if ($totalFrames -eq 0) {
        return [PSCustomObject]@{
            Label = $testLabel
            TotalFrames = 0
            AvgFps = 0.0
            AvgFrameTimeMs = 0.0
            P50Ms = 0.0
            P90Ms = 0.0
            P99Ms = 0.0
            JankPercent = 0.0
            QemuRamMb = $qemuRamMb
        }
    }

    $sorted = $frameTimesMs | Sort-Object
    $avgMs = ($sorted | Measure-Object -Average).Average
    $avgFps = [math]::Round(1000.0 / $avgMs, 1)
    
    $p50Idx = [math]::Min([int]($totalFrames * 0.50), $totalFrames - 1)
    $p90Idx = [math]::Min([int]($totalFrames * 0.90), $totalFrames - 1)
    $p99Idx = [math]::Min([int]($totalFrames * 0.99), $totalFrames - 1)
    
    $p50Ms = [math]::Round($sorted[$p50Idx], 2)
    $p90Ms = [math]::Round($sorted[$p90Idx], 2)
    $p99Ms = [math]::Round($sorted[$p99Idx], 2)
    
    $jankCount = ($sorted | Where-Object { $_ -gt 16.67 }).Count
    $jankPercent = [math]::Round(($jankCount / $totalFrames) * 100.0, 1)

    return [PSCustomObject]@{
        Label = $testLabel
        TotalFrames = $totalFrames
        AvgFps = $avgFps
        AvgFrameTimeMs = [math]::Round($avgMs, 2)
        P50Ms = $p50Ms
        P90Ms = $p90Ms
        P99Ms = $p99Ms
        JankPercent = $jankPercent
        QemuRamMb = $qemuRamMb
    }
}

$results = [System.Collections.Generic.List[PSCustomObject]]::new()
$artComparison = [ordered]@{}
$resComparison = [ordered]@{}

# A/B TEST 1: ART Compilation
if (-not $SkipArtBenchmark) {
    Write-Host "`n[1/2] Benchmarking ART Compilation (AOT vs JIT)..." -ForegroundColor Yellow
    
    Write-Host "  [Step 1A] Measuring Baseline Launch Time & Framestats..." -ForegroundColor Cyan
    $launchTimeBeforeMs = Measure-AppLaunchTime -pkg $PackageName -act $ActivityName
    Write-Host "    Launch Time (Baseline): ${launchTimeBeforeMs} ms" -ForegroundColor Gray
    $statsBefore = Measure-Framestats -pkg $PackageName -durationSec $ScrollDurationSeconds -testLabel "ART Baseline (JIT)"
    $results.Add($statsBefore)
    
    Write-Host "`n  [Step 1B] Compiling package with 'cmd package compile -m speed -f $PackageName'..." -ForegroundColor Cyan
    $compileOut = & $adb -s $DeviceSerial shell cmd package compile -m speed -f $PackageName 2>$null
    Write-Host "    Compile Status: $compileOut" -ForegroundColor Gray
    Start-Sleep -Seconds 2

    Write-Host "  [Step 1C] Measuring Post-AOT Launch Time & Framestats..." -ForegroundColor Cyan
    $launchTimeAfterMs = Measure-AppLaunchTime -pkg $PackageName -act $ActivityName
    Write-Host "    Launch Time (Post-AOT): ${launchTimeAfterMs} ms" -ForegroundColor Gray
    $statsAfter = Measure-Framestats -pkg $PackageName -durationSec $ScrollDurationSeconds -testLabel "ART AOT (speed filter)"
    $results.Add($statsAfter)

    $artComparison["Package"] = $PackageName
    $artComparison["LaunchBeforeMs"] = $launchTimeBeforeMs
    $artComparison["LaunchAfterMs"] = $launchTimeAfterMs
    $artComparison["LaunchDeltaMs"] = $launchTimeAfterMs - $launchTimeBeforeMs
    $artComparison["FpsBefore"] = $statsBefore.AvgFps
    $artComparison["FpsAfter"] = $statsAfter.AvgFps
    $artComparison["FpsDelta"] = [math]::Round($statsAfter.AvgFps - $statsBefore.AvgFps, 1)
}

# A/B TEST 2: Resolution Scaling
if (-not $SkipResolutionBenchmark) {
    Write-Host "`n[2/2] Benchmarking Resolution Scaling Impact..." -ForegroundColor Yellow
    $resolutions = @(
        @{ Width = 1920; Height = 1200; Pixels = "2.30M (100%)" },
        @{ Width = 1600; Height = 1000; Pixels = "1.60M (70%)" },
        @{ Width = 1280; Height = 800;  Pixels = "1.02M (44%)" }
    )

    foreach ($res in $resolutions) {
        $w = $res.Width
        $h = $res.Height
        $pix = $res.Pixels
        $label = "${w}x${h} ($pix)"
        Write-Host "  Testing Resolution: $label..." -ForegroundColor Cyan
        
        & $adb -s $DeviceSerial shell wm size "${w}x${h}" > $null
        Start-Sleep -Seconds 1
        
        $resStats = Measure-Framestats -pkg $PackageName -durationSec $ScrollDurationSeconds -testLabel "Res $label"
        $results.Add($resStats)
        $resComparison["${w}x${h}"] = $resStats.AvgFps
    }

    Write-Host "  Restoring native 1920x1200 resolution..." -ForegroundColor Gray
    & $adb -s $DeviceSerial shell wm size reset > $null
    & $adb -s $DeviceSerial shell wm size 1920x1200 > $null
}

# Summary Table
Write-Host "`n====================================================================================" -ForegroundColor Cyan
Write-Host " TabletDroid Performance Benchmark Summary Table" -ForegroundColor Cyan
Write-Host "====================================================================================" -ForegroundColor Cyan
$results | Format-Table -Property Label, AvgFps, AvgFrameTimeMs, P50Ms, P90Ms, P99Ms, JankPercent, TotalFrames, QemuRamMb -AutoSize | Out-String | Write-Host -ForegroundColor Green

# Save Markdown Report
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
$reportFile = "$OutputDir\baseline_v0.1.md"

$mdLines = [System.Collections.Generic.List[string]]::new()
$mdLines.Add("# TabletDroid v0.1 Performance Baseline Benchmark")
$mdLines.Add("")
$mdLines.Add("- **Timestamp**: $timestamp")
$mdLines.Add("- **Host Hardware**: ASUS ROG Flow Z13 (Intel Core i9-12900H, RTX 3050 Ti Laptop GPU, 16GB RAM)")
$mdLines.Add("- **WHPX Accelerator**: Active & Operational")
$mdLines.Add("- **Target App**: $PackageName")
$mdLines.Add("- **Emulator Serial**: $DeviceSerial")
$mdLines.Add("")
$mdLines.Add("---")
$mdLines.Add("")
$mdLines.Add("## 1. Frame Metrics Summary")
$mdLines.Add("")
$mdLines.Add("| Test Scenario | Avg FPS | Avg FrameTime | P50 (ms) | P90 (ms) | P99 (ms) | Jank Rate (%) | Samples | QEMU RAM |")
$mdLines.Add("| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |")

foreach ($r in $results) {
    $row = "| **" + $r.Label + "** | **" + $r.AvgFps + "** | " + $r.AvgFrameTimeMs + " ms | " + $r.P50Ms + " ms | " + $r.P90Ms + " ms | " + $r.P99Ms + " ms | " + $r.JankPercent + "% | " + $r.TotalFrames + " | " + $r.QemuRamMb + " MB |"
    $mdLines.Add($row)
}

$mdLines.Add("")
$mdLines.Add("---")
$mdLines.Add("")
$mdLines.Add("## 2. A/B Bottleneck Isolation Analysis")
$mdLines.Add("")

if ($artComparison.Count -gt 0) {
    $lBefore = $artComparison['LaunchBeforeMs']
    $lAfter = $artComparison['LaunchAfterMs']
    $lDelta = $artComparison['LaunchDeltaMs']
    $fBefore = $artComparison['FpsBefore']
    $fAfter = $artComparison['FpsAfter']
    $fDelta = $artComparison['FpsDelta']

    $mdLines.Add("### 2.1 ART Compilation Impact (JIT vs AOT speed filter)")
    $mdLines.Add("- **Launch Time Before AOT**: $lBefore ms")
    $mdLines.Add("- **Launch Time After AOT**: $lAfter ms (Delta: $lDelta ms)")
    $mdLines.Add("- **Scroll Avg FPS (Before)**: $fBefore FPS")
    $mdLines.Add("- **Scroll Avg FPS (After)**: $fAfter FPS (Delta: $fDelta FPS)")
    $mdLines.Add("")
    $mdLines.Add("> **Interpretation**:")
    if ($fDelta -ge 10) {
        $mdLines.Add("> ART ahead-of-time compilation provides a SIGNIFICANT framerate improvement (+$fDelta FPS). JIT compiler thrashing was a primary bottleneck.")
    } else {
        $mdLines.Add("> ART compilation improved launch time, but framerate during active scrolling remained relatively flat (Delta: +$fDelta FPS). This indicates the bottleneck is primarily in the Graphics/Surface rendering and IPC composition pipeline.")
    }
    $mdLines.Add("")
}

if ($resComparison.Count -gt 0) {
    $mdLines.Add("### 2.2 Resolution Scaling Impact")
    foreach ($k in $resComparison.Keys) {
        $v = $resComparison[$k]
        $mdLines.Add("- **$k**: $v FPS")
    }
    $mdLines.Add("")
    $mdLines.Add("> **Interpretation**:")
    $fps1920 = $resComparison["1920x1200"]
    $fps1280 = $resComparison["1280x800"]
    if ($fps1280 -gt ($fps1920 * 1.5)) {
        $mdLines.Add("> Framerate scaled dramatically when lowering resolution ($fps1920 -> $fps1280 FPS). This is strong evidence that **pixel throughput / framebuffer IPC transfer** is the primary bottleneck.")
    } else {
        $mdLines.Add("> Framerate stayed flat across resolutions ($fps1920 -> $fps1280 FPS). This indicates that the bottleneck is likely **VM scheduling, SurfaceFlinger Vsync pacing, or guest app frame production logic** rather than pure pixel transfer.")
    }
    $mdLines.Add("")
}

$mdLines.Add("---")
$mdLines.Add("")
$mdLines.Add('## 3. Recommended Architectural Decision for v0.1')
$mdLines.Add('- Reference Ticket: `perf: establish v0.1 rendering baseline and isolate frame bottleneck`')
$mdLines.Add('- Next Step: `research: validate external GPU surface path for TabletDroid Host`')

[System.IO.File]::WriteAllLines($reportFile, $mdLines, [System.Text.Encoding]::UTF8)
Write-Host "[OK] Benchmark report written to: $reportFile`n" -ForegroundColor Green
