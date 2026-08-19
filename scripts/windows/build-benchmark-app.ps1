param(
    [switch]$Install = $false,
    [string]$DeviceId = "emulator-5554"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = (Resolve-Path "$scriptDir\..\..").Path
$appDir = "$rootDir\android\guest\TabletDroid.Benchmark"
$buildDir = "$appDir\build"
$binDir = "$rootDir\bin"

$androidSdk = "$env:LOCALAPPDATA\Android\Sdk"
$buildTools = "$androidSdk\build-tools\34.0.0"
$androidJar = "$androidSdk\platforms\android-34\android.jar"
$adb = "$androidSdk\platform-tools\adb.exe"

$aapt2 = "$buildTools\aapt2.exe"
$d8 = "$buildTools\d8.bat"
$zipalign = "$buildTools\zipalign.exe"
$apksigner = "$buildTools\apksigner.bat"

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host " Building TabletDroid Canonical Benchmark App (com.tabletdroid.benchmark)" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan

# 1. Clean / create build directories
if (Test-Path $buildDir) {
    Remove-Item $buildDir -Recurse -Force
}
New-Item -ItemType Directory -Path "$buildDir\gen" -Force | Out-Null
New-Item -ItemType Directory -Path "$buildDir\obj" -Force | Out-Null
New-Item -ItemType Directory -Path "$buildDir\dex" -Force | Out-Null
New-Item -ItemType Directory -Path $binDir -Force | Out-Null

# 2. Compile resources
Write-Host "[1/6] Compiling Android resources with AAPT2..." -ForegroundColor Gray
& $aapt2 compile --dir "$appDir\res" -o "$buildDir\compiled_res.zip"
if ($LASTEXITCODE -ne 0) { throw "aapt2 compile failed with code $LASTEXITCODE" }

# 3. Link resources and generate R.java
Write-Host "[2/6] Linking APK resources and generating R.java..." -ForegroundColor Gray
& $aapt2 link -I $androidJar --manifest "$appDir\AndroidManifest.xml" -o "$buildDir\base.apk" --java "$buildDir\gen" "$buildDir\compiled_res.zip" --auto-add-overlay
if ($LASTEXITCODE -ne 0) { throw "aapt2 link failed with code $LASTEXITCODE" }

# 4. Compile Java sources
Write-Host "[3/6] Compiling Java sources with javac..." -ForegroundColor Gray
$javaFiles = @()
$javaFiles += (Get-ChildItem -Path "$buildDir\gen" -Filter *.java -Recurse | Select-Object -ExpandProperty FullName)
$javaFiles += (Get-ChildItem -Path "$appDir\src" -Filter *.java -Recurse | Select-Object -ExpandProperty FullName)

& javac -source 1.8 -target 1.8 -bootclasspath $androidJar -cp $androidJar -d "$buildDir\obj" $javaFiles
if ($LASTEXITCODE -ne 0) { throw "javac compilation failed with code $LASTEXITCODE" }

# 5. Dex classes
Write-Host "[4/6] Dexing bytecode with D8..." -ForegroundColor Gray
$classFiles = (Get-ChildItem -Path "$buildDir\obj" -Filter *.class -Recurse | Select-Object -ExpandProperty FullName)
& cmd.exe /c "`"$d8`" --min-api 26 --output `"$buildDir\dex`" $($classFiles -join ' ')"
if ($LASTEXITCODE -ne 0) { throw "d8 failed with code $LASTEXITCODE" }

# 6. Package, Align and Sign APK
Write-Host "[5/6] Packaging and signing APK..." -ForegroundColor Gray
# Copy base.apk and add classes.dex
Copy-Item "$buildDir\base.apk" "$buildDir\unaligned.apk"
$zipExe = (Get-Command 7z, tar -ErrorAction SilentlyContinue | Select-Object -First 1).Source

# Use powershell archive utility or jar to update apk with classes.dex
Push-Location "$buildDir\dex"
& jar uf "$buildDir\unaligned.apk" "classes.dex"
Pop-Location

# Zipalign
$alignedApk = "$buildDir\aligned.apk"
& $zipalign -p -f 4 "$buildDir\unaligned.apk" $alignedApk
if ($LASTEXITCODE -ne 0) { throw "zipalign failed with code $LASTEXITCODE" }

# Ensure debug keystore exists
$keystorePath = "$buildDir\debug.keystore"
& keytool -genkeypair -alias androiddebugkey -keypass android -keystore $keystorePath -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 10000 -keyalg RSA -keysize 2048

# Sign APK
$finalApk = "$binDir\TabletDroid.Benchmark.apk"
& cmd.exe /c "`"$apksigner`" sign --ks `"$keystorePath`" --ks-pass pass:android --ks-key-alias androiddebugkey --key-pass pass:android --out `"$finalApk`" `"$alignedApk`""
if ($LASTEXITCODE -ne 0) { throw "apksigner failed with code $LASTEXITCODE" }

Write-Host " [SUCCESS] Benchmark APK created: $finalApk" -ForegroundColor Green

# 7. Install if requested
if ($Install) {
    Write-Host "[6/6] Installing APK to ADB device ($DeviceId)..." -ForegroundColor Cyan
    & $adb -s $DeviceId install -r "$finalApk"
    if ($LASTEXITCODE -eq 0) {
        Write-Host " [SUCCESS] Benchmark App installed successfully on $DeviceId!" -ForegroundColor Green
    } else {
        Write-Warning "Failed to install APK to $DeviceId"
    }
}
