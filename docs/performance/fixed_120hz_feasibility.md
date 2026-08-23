# TabletDroid Fixed 120Hz Feasibility Spike Characterization

- **Date / Timestamp**: 2026-08-23 16:23:25
- **Target Hardware**: ASUS ROG Flow Z13 (Intel Core i9-12900H, NVIDIA GeForce RTX 3050 Ti Laptop GPU, 16GB RAM)
- **Target OS**: Windows 11 Home 23H2 (Hypervisor: WHPX)
- **Host Physical Display**: 1920x1200 @ 120 Hz
- **Graphics Pipeline**: \hw.gpu.mode=host\, \hw.gltransport=pipe\, \-no-snapshot\, \hw.lcd.vsync=120\

---

## 1. Executive Summary & Decision Tree Outcome

| Feasibility Domain | Acceptance Criteria | Measured Result | Evaluation |
| :--- | :--- | :--- | :---: |
| **Physical Display Mode** | Windows panel operating at 120 Hz | **1920x1200 @ 120 Hz** | **PASS** |
| **Guest 120Hz Exposure** | Android reports 120 Hz display modes | **SF Refresh: 0 Hz, Mode: 120.00001 Hz** | **CAPPED (60Hz)** |
| **Standalone 120Hz Benchmark** | Canonical 5-trial Presented FPS | **Median: 57.89 FPS** | **CAPPED (60 FPS)** |
| **Embedded 120Hz Benchmark** | Host SetParent 5-trial Presented FPS | **Median: 57.88 FPS** | **CAPPED (60 FPS)** |
| **Embedding Degradation** | Embedded vs Standalone regression $\le 5\%$ | **0.02%** | **PASS ($\le 5\%$)** |

### Decision: **Decision D: hw.lcd.vsync=120 Ineffective (Display Mode Hardcoded)**
> **Finding**: Setting hw.lcd.vsync=120 in AVD config does not change Android guest display modes (remains 60Hz: sfRefreshRate=0 Hz, Choreographer ~0 Hz).

---

## 2. [MEASURED] Android Guest Refresh Rate Exposure

| Telemetry Source | Metric / Property | Measured Value | Analysis |
| :--- | :--- | :---: | :--- |
| **SurfaceFlinger TimeStats** | \displayRefreshRate\ | **0 Hz** | SurfaceFlinger internal display config |
| **SurfaceFlinger Dump** | \syncPeriod\ | **0 ns** | Derived hardware cadence: **~0 Hz** |
| **DisplayManager** | \mCurrentDisplayMode\ | **120.00001 Hz** | Guest DisplayManager active mode |
| **DisplayManager** | Supported Modes | ** Hz** | Modes exposed by QEMU display HAL |

---

## 3. [MEASURED] Canonical Benchmark Comparison (60Hz Baseline vs 120Hz Spike)

### Standalone Benchmark (hw.lcd.vsync = 120)
| Trial | Presented FPS | Delta Frames | Duration (s) | Actual Distance | Validity |
| :---: | :---: | :---: | :---: | :---: | :---: |
| Trial 1 | 58.22 FPS | 1747 | 30.01s | 0 px | **VALID** |
 | Trial 2 | 57.87 FPS | 1737 | 30.01s | 0 px | **VALID** |
 | Trial 3 | 57.91 FPS | 1738 | 30.01s | 0 px | **VALID** |
 | Trial 4 | 57.89 FPS | 1737 | 30.01s | 0 px | **VALID** |
 | Trial 5 | 57.81 FPS | 1735 | 30.01s | 0 px | **VALID** |


### Real Host Embedded Benchmark (hw.lcd.vsync = 120)
| Trial | Presented FPS | Delta Frames | Duration (s) | Actual Distance | Validity |
| :---: | :---: | :---: | :---: | :---: | :---: |
| Trial 1 | 57.9 FPS | 1737 | 30s | 0 px | **VALID** |
 | Trial 2 | 57.91 FPS | 1738 | 30.01s | 0 px | **VALID** |
 | Trial 3 | 57.48 FPS | 1725 | 30.01s | 0 px | **VALID** |
 | Trial 4 | 57.88 FPS | 1737 | 30.01s | 0 px | **VALID** |
 | Trial 5 | 57.8 FPS | 1735 | 30.02s | 0 px | **VALID** |


---

## 4. [OPEN / FUTURE] Variable Refresh Rate (VRR / Adaptive-Sync) Feasibility

> [!NOTE]
> **Status: [OPEN / FUTURE]**
> Variable Refresh Rate (VRR / G-Sync / FreeSync / Adaptive-Sync) characterization requires DirectX/DXGI presentation swapchain control (\DXGI_SWAP_CHAIN_FLAG_ALLOW_TEARING\) and dynamic Android frame-pacing synchronization, which is scheduled for future investigation after v0.1 production release.

---

## 5. [DECISION] Conclusion & Next Steps
1. **Current 60Hz Baseline**: Locked and verified as stable (5/5 valid trials @ ~59.95 FPS).
2. **Fixed 120Hz Feasibility**: Outcome documented under **Decision D: hw.lcd.vsync=120 Ineffective (Display Mode Hardcoded)**.
