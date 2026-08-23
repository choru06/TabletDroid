# TabletDroid Fixed 120Hz Feasibility & VSYNC Break Characterization Report

- **Date / Timestamp**: 2026-08-23 17:37:22
- **Target Hardware**: ASUS ROG Flow Z13 (Intel Core i9-12900H, NVIDIA GeForce RTX 3050 Ti Laptop GPU, 16GB RAM)
- **Target OS**: Windows 11 Home 23H2 (Hypervisor: WHPX)
- **Host Physical Panel**: 1920x1200 @ 120 Hz
- **Target AVD Configuration**: `hw.lcd.vsync = 120`, `hw.gpu.mode = host`, `hw.gltransport = pipe`, `-no-snapshot`, `-no-snapshot-save`
- **Emulator Session Lifecycle**: Cold Boot Clean PID: 17316,27528 (Terminated Old PID: NONE)

---

## 1. Executive Summary & Multi-Layer Telemetry Matrix

| Pipeline Layer | Subsystem / Property | Measured Value | Evaluation |
| :--- | :--- | :---: | :---: |
| **Layer A: AVD Config** | `hw.lcd.vsync` in `config.ini` | **120** | **PASS (Configured 120)** |
| **Layer B: Guest Boot Prop** | `ro.boot.qemu.vsync` | **120** (qemu.vsync: `N/A`) | **PASS (120)** |
| **Layer C: DisplayManager** | `mCurrentDisplayMode` | **120 Hz** | **PASS (120Hz Exposed)** |
| **Layer C: Supported Modes** | `dumpsys display` Modes | **N/A / PARSE_UNAVAILABLE** | **N/A** |
| **Layer E/F: App Display** | `Display.getRefreshRate()` | **60 Hz** (Mode: 120 Hz) | **60Hz** |
| **Layer G: Guest Choreographer** | Workload frame callback cadence | **P50: 60 FPS** (Standalone) / **60 FPS** (Embedded) | **~60 FPS CAPPED** |
| **Layer H: SF Presented FPS** | Canonical Presented Throughput | **P50: 57.81 FPS** (Standalone) / **57.85 FPS** (Embedded) | **~60 FPS CAPPED** |
| **Canonical Validity Gate** | 5/5 Valid (Workload 1.0.0, Distance +- 10%, SF Layer Found) | **Standalone: 5/5, Embedded: 5/5** | **5/5 VALID** |

### Architectural Decision: **guest composer/display-config break**
> **Break Location**: `Guest DisplayManager/HWC -> SurfaceFlinger (SF Active Refresh: 60 Hz, App Disp: 60 Hz)`
> **Finding**: DisplayManager exposes 120Hz mode, but SurfaceFlinger / HWC active display configuration remains at 60Hz (~16.6ms VSYNC period).

---

## 2. [MEASURED] Platform & Display Subsystem Environment

| Property | Key | Value |
| :--- | :--- | :--- |
| **Hardware Composer HAL** | `ro.hardware.hwcomposer` | **N/A** |
| **Android API Level** | `ro.build.version.sdk` | **34** |
| **Build Fingerprint** | `ro.build.fingerprint` | `google/sdk_gphone64_x86_64/emu64xa:14/UE1A.230829.036.A4/12096271:user/release-keys` |
| **Raw VSYNC Properties** | `getprop | grep vsync` | `[debug.sf.vsync_reactor_ignore_present_fences]: [true]
[ro.boot.qemu.vsync]: [120]` |

---

## 3. [MEASURED] Canonical 120Hz Standalone Benchmark Trials (5 Trials)

| Trial | Condition | Guest Choreographer | SF Presented FPS | App Disp Refresh | Measure Frames | Actual Distance | Distance Error | Dropped | Duration | Status |
| :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| Trial 1 | Standalone_120Hz | **60 FPS** | **57.71 FPS** | 60 Hz | 1801 | 24013 px | 0.05% | 0 | 30.01s | **VALID** |
| Trial 2 | Standalone_120Hz | **60 FPS** | **57.81 FPS** | 60 Hz | 1800 | 24000 px | 0% | 0 | 30.01s | **VALID** |
| Trial 3 | Standalone_120Hz | **60 FPS** | **57.81 FPS** | 60 Hz | 1800 | 24000 px | 0% | 0 | 30.01s | **VALID** |
| Trial 4 | Standalone_120Hz | **60 FPS** | **57.87 FPS** | 60 Hz | 1800 | 24000 px | 0% | 0 | 30.01s | **VALID** |
| Trial 5 | Standalone_120Hz | **59.99 FPS** | **57.82 FPS** | 60 Hz | 1800 | 24000 px | 0% | 0 | 30.01s | **VALID** |

---

## 4. [MEASURED] Canonical 120Hz Real Host Embedded Benchmark Trials (5 Trials)

| Trial | Condition | Guest Choreographer | SF Presented FPS | App Disp Refresh | Measure Frames | Actual Distance | Distance Error | Dropped | Duration | Status |
| :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| Trial 1 | Host_Embedded_120Hz | **60 FPS** | **57.82 FPS** | 60 Hz | 1800 | 24000 px | 0% | 0 | 30s | **VALID** |
| Trial 2 | Host_Embedded_120Hz | **60 FPS** | **57.85 FPS** | 60 Hz | 1800 | 24000 px | 0% | 0 | 30.01s | **VALID** |
| Trial 3 | Host_Embedded_120Hz | **60 FPS** | **57.89 FPS** | 60 Hz | 1800 | 24000 px | 0% | 0 | 30s | **VALID** |
| Trial 4 | Host_Embedded_120Hz | **60 FPS** | **57.88 FPS** | 60 Hz | 1800 | 24000 px | 0% | 0 | 30.01s | **VALID** |
| Trial 5 | Host_Embedded_120Hz | **60 FPS** | **57.82 FPS** | 60 Hz | 1800 | 24000 px | 0% | 0 | 30.01s | **VALID** |

---

## 5. [OPEN / FUTURE] Variable Refresh Rate (VRR / Adaptive-Sync) Characterization

> [!NOTE]
> **Status: [OPEN / FUTURE]**
> Dynamic Variable Refresh Rate (VRR / NVIDIA G-Sync / AMD FreeSync / VESA Adaptive-Sync) requires custom host presentation swapchain management (`DXGI_SWAP_CHAIN_FLAG_ALLOW_TEARING`), tearing presentation without DWM compositor throttling, and dynamic guest-to-host frame pacing alignment. This remains scheduled for post-v0.1 graphics architecture investigation.

---

## 6. [DECISION] Conclusion & Summary
1. **Production 60Hz Baseline**: Locked and verified at **5/5 VALID (59.27 FPS baseline)**. Throughput, graphics transport (`pipe`), and SetParent embedding architecture are **[CLOSED]**.
2. **Fixed 120Hz VSYNC Break**: Directly identified and isolated as **guest composer/display-config break** at layer `Guest DisplayManager/HWC -> SurfaceFlinger (SF Active Refresh: 60 Hz, App Disp: 60 Hz)`.
3. **Next Steps**: Retain stable 60Hz production configuration (`hw.gpu.mode=host`, `hw.gltransport=pipe`) for v0.1 release.
