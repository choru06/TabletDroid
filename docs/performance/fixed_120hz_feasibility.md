# TabletDroid Fixed 120Hz Feasibility Spike Characterization Report

- **Date / Timestamp**: 2026-08-23 16:55:14
- **Target Hardware**: ASUS ROG Flow Z13 (Intel Core i9-12900H, NVIDIA GeForce RTX 3050 Ti Laptop GPU, 16GB RAM)
- **Target OS**: Windows 11 Home 23H2 (Hypervisor: WHPX)
- **Host Physical Panel**: 1920x1200 @ 120 Hz
- **Target AVD Configuration**: `hw.lcd.vsync = 120`, `hw.gpu.mode = host`, `hw.gltransport = pipe`, `-no-snapshot`, `-no-snapshot-save`
- **Emulator Session Lifecycle**: Cold Boot Clean PID: 42396,38884 (Terminated Old PID: NONE)

> [!IMPORTANT]
> **Historical Correction**: Previous informal Decision D (hw.lcd.vsync=120 Ineffective) is hereby **SUPERSEDED / INVALIDATED**. The previous probe concluded guest display remained 60Hz due to unparsed SurfaceFlinger output. The canonical probe now directly isolates both **DisplayManager Mode**, **Guest Choreographer Rate**, and **SurfaceFlinger Presentation Cadence** with strict fail-closed validity gates.

---

## 1. Executive Summary & Feasibility Decision Matrix

| Feasibility Metric | Acceptance Criteria | Measured Value | Evaluation |
| :--- | :--- | :---: | :---: |
| **Host Physical Refresh Rate** | Windows display running at 120 Hz | **120 Hz** | **PASS** |
| **DisplayManager Current Mode** | Android reports 120 Hz active display mode | **120 Hz** | **PASS (120Hz Exposed)** |
| **DisplayManager Supported Modes** | QEMU display HAL exposes 120 Hz modes | **N/A / PARSE_UNAVAILABLE** | **60Hz Only** |
| **SurfaceFlinger displayRefreshRate** | SurfaceFlinger internal mode tracking | **60 Hz** | **60 Hz** |
| **Guest Choreographer Cadence (Standalone)** | Workload frame callback rate | **P50: 60 FPS** | **~60 FPS CAPPED** |
| **Presented FPS (Standalone)** | Canonical SurfaceFlinger Presented FPS | **P50: 57.88 FPS** | **~60 FPS CAPPED** |
| **Guest Choreographer Cadence (Embedded)** | Host SetParent frame callback rate | **P50: 60 FPS** | **~60 FPS CAPPED** |
| **Presented FPS (Embedded)** | Host SetParent Presented FPS | **P50: 57.83 FPS** | **~60 FPS CAPPED** |
| **Canonical Trial Validity** | 5/5 Valid (Workload 1.0.0, Distance +- 10%) | **Standalone: 5/5, Embedded: 5/5** | **5/5 VALID** |

### Architectural Decision: **guest vsync/frame scheduling cap [OPEN]**
> **Finding**: DisplayManager reports 120Hz display mode (120 Hz), but Guest Choreographer frame scheduling remains capped at ~60 FPS (60 FPS).
> **Technical Mechanism**: The guest Android window manager exposes a 120Hz display mode, but Choreographer VSYNC pulses or render thread cadence are governed by a 60Hz hardware VSYNC source.

---

## 2. [MEASURED] Canonical 120Hz Standalone Benchmark Trials

| Trial | Condition | Guest Choreographer | SF Presented FPS | Measure Frames | Actual Distance | Distance Error | Duration | Status |
| :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| Trial 1 | Standalone_120Hz | **60 FPS** | **58.18 FPS** | 1801 | 24013 px | 0.05% | 30.01s | **VALID** |
| Trial 2 | Standalone_120Hz | **60 FPS** | **57.88 FPS** | 1800 | 24000 px | 0% | 30.01s | **VALID** |
| Trial 3 | Standalone_120Hz | **60 FPS** | **57.79 FPS** | 1800 | 24000 px | 0% | 30.01s | **VALID** |
| Trial 4 | Standalone_120Hz | **60 FPS** | **57.9 FPS** | 1800 | 24000 px | 0% | 30s | **VALID** |
| Trial 5 | Standalone_120Hz | **60 FPS** | **57.8 FPS** | 1800 | 24000 px | 0% | 30s | **VALID** |

---

## 3. [MEASURED] Canonical 120Hz Real Host Embedded Benchmark Trials

| Trial | Condition | Guest Choreographer | SF Presented FPS | Measure Frames | Actual Distance | Distance Error | Duration | Status |
| :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| Trial 1 | Host_Embedded_120Hz | **60 FPS** | **57.89 FPS** | 1800 | 24000 px | 0% | 30.01s | **VALID** |
| Trial 2 | Host_Embedded_120Hz | **59.96 FPS** | **57.79 FPS** | 1799 | 24000 px | 0% | 30s | **VALID** |
| Trial 3 | Host_Embedded_120Hz | **60 FPS** | **57.82 FPS** | 1800 | 24000 px | 0% | 30s | **VALID** |
| Trial 4 | Host_Embedded_120Hz | **60.03 FPS** | **57.91 FPS** | 1801 | 24013 px | 0.05% | 30.01s | **VALID** |
| Trial 5 | Host_Embedded_120Hz | **60 FPS** | **57.83 FPS** | 1800 | 24000 px | 0% | 30s | **VALID** |

---

## 4. [OPEN / FUTURE] Variable Refresh Rate (VRR / Adaptive-Sync) Characterization

> [!NOTE]
> **Status: [OPEN / FUTURE]**
> Dynamic Variable Refresh Rate (VRR / NVIDIA G-Sync / AMD FreeSync / VESA Adaptive-Sync) requires custom host presentation swapchain management (`DXGI_SWAP_CHAIN_FLAG_ALLOW_TEARING`), tearing presentation without DWM compositor throttling, and dynamic guest-to-host frame pacing alignment. This remains scheduled for post-v0.1 graphics architecture investigation.

---

## 5. [DECISION] Conclusion & Summary
1. **Production 60Hz Characterization**: Fully verified, locked, and closed at **5/5 VALID (59.27 FPS baseline)**.
2. **Fixed 120Hz Spike**: Evaluated under canonical conditions with clean emulator cold boot and dual-layer cadence telemetry, categorized as **guest vsync/frame scheduling cap [OPEN]**.
3. **Next Steps**: Retain stable 60Hz production configuration (`hw.gpu.mode=host`, `hw.gltransport=pipe`) for v0.1 release.
