# TabletDroid v0.1 Performance Baseline Protocol & Analysis

- **Target Device**: ASUS ROG Flow Z13 (Intel Core i9-12900H, NVIDIA GeForce RTX 3050 Ti Laptop GPU, Windows 11)
- **Target App**: Instagram (`com.instagram.android`)
- **Benchmark Suite**: [`scripts/windows/benchmark-spike.ps1`](../../scripts/windows/benchmark-spike.ps1)
- **Status**: Framework Ready for Physical Execution

---

## 1. Benchmark Execution Methodology

The benchmark measures real frame timings from Android's `dumpsys gfxinfo framestats` and `SurfaceFlinger`:

1. **Cold Launch Time**: `am start -W -S` measuring `TotalTime` in ms.
2. **Scroll Gesture Stress Test**: 8-second automated swipe gestures generating continuous frame load.
3. **Per-Frame Timing Metrics**:
   - Total Frame Time: `(FrameCompleted - IntendedVsync) / 1,000,000.0` ms.
   - **Average FPS**: `1000.0 / AvgFrameTime`.
   - **P50 / P90 / P99 Frame Time**: 50th, 90th, 99th percentile frame completion latencies.
   - **Jank Rate (%)**: Percentage of frames exceeding the 16.67ms (60fps) threshold.
   - **QEMU Process Memory**: Host RAM consumption.

---

## 2. A/B Isolation Hypotheses

### Hypothesis A: ART JIT Compiler Thrashing
* **Test**: Baseline (Default JIT) vs. `cmd package compile -m speed -f com.instagram.android` (Full AOT).
* **Criteria**: If FPS increases by >10 FPS, ART JIT overhead was a key factor. If flat, bottleneck is in the rendering pipeline.

### Hypothesis B: Framebuffer Pixel Transport Bandwidth
* **Test**: Resolution scaling across `1920x1200` (2.3M px) ➔ `1600x1000` (1.6M px) ➔ `1280x800` (1.0M px).
* **Criteria**:
  - If FPS scales proportionally (e.g. 20 ➔ 35 ➔ 55 FPS), **framebuffer IPC transport / pixel fill rate** is the bottleneck.
  - If FPS remains flat (e.g. 20 ➔ 22 ➔ 23 FPS), **VM thread scheduling, SurfaceFlinger pacing, or guest app logic** is the bottleneck.

---

## 3. How to Run

While the emulator is running with Instagram installed:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\benchmark-spike.ps1
```
This will automatically execute the test matrix and overwrite this document with the real live metrics.
