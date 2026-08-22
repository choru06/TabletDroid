# TabletDroid v0.1 SurfaceFlinger 4-Way A/B Statistical Validation Report

> [!WARNING]
> **SUPERSEDED & INVALIDATED**: Historical exploratory claims that `debug.sf.latch_unsignaled` or `debug.sf.disable_backpressure` improved presentation throughput were artifacts of non-deterministic input generation and Quick Boot snapshot state. The definitive deterministic characterization in [`docs/performance/surfaceflinger_regression_ab.md`](surfaceflinger_regression_ab.md) shows that in a clean cold-boot environment with `hw.gltransport=pipe`, the baseline natively runs at **59.90 ~ 59.97 FPS** without property injection. Property injection has been permanently purged from the launch pipeline.

- **Timestamp**: 2026-08-20 00:51:22
- **Host Hardware**: ASUS ROG Flow Z13 (Intel Core i9-12900H, NVIDIA GeForce RTX 3050 Ti Laptop GPU, 16GB RAM)
- **WHPX Acceleration**: Active & Operational
- **Target Application**: com.instagram.android
- **Resolution Tested**: 1920x1200 (Native Tablet Resolution)
- **Benchmark Protocol**: 4 Conditions x 1 Trials x 10s active scrolling per trial

---

## 1. [MEASURED] 4-Way Statistical Comparison Table (Medians across 5 Trials)

| Condition | Valid Trials | Observed Throughput (FPS) | Throughput [Min, Max] | StdDev | Frame Latency (ms) | Latency-Eq FPS | P50 (ms) | P90 (ms) | P99 (ms) | Jank % | QEMU CPU | GPU 3D |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |

### 1.1 All Raw Trial Records

| Trial ID | Condition | Status | Valid Frames | Duration (s) | Throughput (FPS) | Latency Avg (ms) | Latency-Eq FPS | P50 (ms) | P90 (ms) | P99 (ms) | Jank % | CPU Avg % | CPU Peak % | GPU 3D % |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |

---

## 2. [IMPLEMENTED] Benchmark Hardening & Verification Changes
- **Metric Disambiguation**: Separated Observed Throughput (ValidFrames / ActualDurationSec) from Frame Latency (ms) and Latency-Equivalent FPS (1000 / Latency).
- **Validity Thresholding**: Samples with $< 15$ frames are flagged as INVALID / INSUFFICIENT_SAMPLES and excluded from statistical comparisons.
- **Periodic Host Telemetry Sampling**: Querying QEMU CPU and Windows \\GPU Engine(*)\\Utilization Percentage every 350ms during workload.
- **Property Read-Back Verification**: Explicit read-back check (getprop) after setting SurfaceFlinger properties.
- **Runtime Experimental Flag**: EnableSurfaceFlingerLowLatencyTuning added to RuntimeConfiguration.

---

## 3. [INFERENCE] SurfaceFlinger Tuning Evaluation


---

## 4. [OPEN] Residual Architectural Blockers
1. **Host GPU Translation Overhead**: Direct3D11 / ANGLE translation layer inside gfxstream_backend.dll.
2. **Emulator GPU Backend Evaluation**: Comparing -gpu host vs -gpu angle_indirect vs -gpu vulkan at 1920x1200.

---

## 5. [DECISION] Architectural Next Steps
- Keep EnableSurfaceFlingerLowLatencyTuning as an experimental configuration option in RuntimeConfiguration.
- Proceed to the next milestone ticket: perf: compare emulator GPU backends at 1920x1200.
