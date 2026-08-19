# TabletDroid v0.1 Performance Baseline Benchmark (HISTORICAL / NON-CANONICAL)

> [!NOTE]
> **HISTORICAL / NON-CANONICAL RECORD**: This baseline used external applications (`com.instagram.android`) and legacy swipe scripts. As of commit `c89a0b1`+, all canonical TabletDroid performance evaluation is standardized on `com.tabletdroid.benchmark` (see [canonical_benchmark_workload.md](file:///c:/Users/o1o6o/Documents/Dev/TabletDroid/docs/performance/canonical_benchmark_workload.md)).
- **Host Hardware**: ASUS ROG Flow Z13 (Intel Core i9-12900H, RTX 3050 Ti Laptop GPU, 16GB RAM)
- **WHPX Accelerator**: Active & Operational
- **Target App**: com.instagram.android
- **Emulator Serial**: emulator-5554

---

## 1. Frame Metrics Summary

| Test Scenario | Avg FPS | Avg FrameTime | P50 (ms) | P90 (ms) | P99 (ms) | Jank Rate (%) | Samples | QEMU RAM |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **ART Baseline (JIT)** | **10** | 99.65 ms | 64.47 ms | 302.46 ms | 485.56 ms | 100% | 56 | 4590.1 MB |
| **ART AOT (speed filter)** | **6.9** | 144 ms | 116.69 ms | 284.23 ms | 464.47 ms | 100% | 39 | 5065.2 MB |
| **Res 1920x1200 (2.30M (100%))** | **8.9** | 112.61 ms | 102.03 ms | 186.18 ms | 316.45 ms | 100% | 117 | 5210.9 MB |
| **Res 1600x1000 (1.60M (70%))** | **12.2** | 82.25 ms | 75.25 ms | 111.75 ms | 251.11 ms | 100% | 120 | 5400.7 MB |
| **Res 1280x800 (1.02M (44%))** | **40.2** | 24.9 ms | 18.89 ms | 49 ms | 69.88 ms | 81.6% | 103 | 5446.1 MB |

---

## 2. A/B Bottleneck Isolation Analysis

### 2.1 ART Compilation Impact (JIT vs AOT speed filter)
- **Launch Time Before AOT**: 2776 ms
- **Launch Time After AOT**: 3928 ms (Delta: 1152 ms)
- **Scroll Avg FPS (Before)**: 10 FPS
- **Scroll Avg FPS (After)**: 6.9 FPS (Delta: -3.1 FPS)

> **Interpretation**:
> ART compilation improved launch time, but framerate during active scrolling remained relatively flat (Delta: +-3.1 FPS). This indicates the bottleneck is primarily in the Graphics/Surface rendering and IPC composition pipeline.

### 2.2 Resolution Scaling Impact
- **1920x1200**: 8.9 FPS
- **1600x1000**: 12.2 FPS
- **1280x800**: 40.2 FPS

> **Interpretation**:
> Framerate scaled dramatically when lowering resolution (8.9 -> 40.2 FPS). This is strong evidence that **pixel throughput / framebuffer IPC transfer** is the primary bottleneck.

---

## 3. Recommended Architectural Decision for v0.1
- Reference Ticket: `perf: establish v0.1 rendering baseline and isolate frame bottleneck`
- Next Step: `research: validate external GPU surface path for TabletDroid Host`
