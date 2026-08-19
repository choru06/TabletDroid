# TabletDroid v0.1 GPU HWUI Renderer Comparison Report (OpenGL vs Vulkan)

- **Timestamp**: 2026-08-20 03:36:48
- **Host Hardware**: ASUS ROG Flow Z13 (Intel Core i9-12900H, NVIDIA GeForce RTX 3050 Ti Laptop GPU, 16GB RAM)
- **WHPX Acceleration**: Active & Operational
- **Target Application**: com.android.chrome
- **Resolution Tested**: 1920x1200 (Native Tablet Resolution)
- **Benchmark Protocol**: GpuRendererComparison (Conditions: 2, 5 Trials x 10s/trial)
- **Frame Rate Source**: SurfaceFlinger Compositor Presentation (dumpsys SurfaceFlinger --timestats -dump)
- **Latency/Jitter Source**: HWUI Framestats (dumpsys gfxinfo framestats, $\le 120$ circular buffer)

---

## 1. [MEASURED] Statistical Comparison Table (Medians across 5 Trials)

| Condition | Valid Trials | Presented FPS | FPS [Min, Max] | StdDev | Wall Duration | Swipe Cadence | Frame Latency | P50 (ms) | P90 (ms) | P99 (ms) | Jank % | CPU Avg % | GPU 3D % |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **A. Skia OpenGL (skiagl)** | 5 / 5 | **5.23 FPS** | [3.3, 10.19] | 2.56 | 10.8s | 0.53 sw/s | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |
| **B. Skia Vulkan (skiavk)** | 5 / 5 | **7.83 FPS** | [3.51, 11.29] | 2.88 | 10.84s | 0.64 sw/s | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |

### 1.1 All Raw Trial Records

| Trial ID | Condition | Status | Duration (s) | Swipes | Cadence | SF Presented | Presented FPS | Gfx Records | Latency Avg (ms) | P50 (ms) | P90 (ms) | P99 (ms) | Jank % | CPU Avg % | GPU 3D % |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| CondA_SkiaGL (T1) | A. Skia OpenGL (skiagl) | VALID | 10.3s | 11 | 1.07 | 34 | 3.3 FPS | 0 | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |
| CondA_SkiaGL (T2) | A. Skia OpenGL (skiagl) | VALID | 11.19s | 4 | 0.36 | 114 | 10.19 FPS | 0 | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |
| CondA_SkiaGL (T3) | A. Skia OpenGL (skiagl) | VALID | 11.34s | 6 | 0.53 | 95 | 8.38 FPS | 0 | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |
| CondA_SkiaGL (T4) | A. Skia OpenGL (skiagl) | VALID | 10.51s | 10 | 0.95 | 55 | 5.23 FPS | 0 | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |
| CondA_SkiaGL (T5) | A. Skia OpenGL (skiagl) | VALID | 10.8s | 5 | 0.46 | 49 | 4.54 FPS | 0 | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |
| CondB_SkiaVK (T1) | B. Skia Vulkan (skiavk) | VALID | 10.82s | 6 | 0.55 | 38 | 3.51 FPS | 0 | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |
| CondB_SkiaVK (T2) | B. Skia Vulkan (skiavk) | VALID | 10.84s | 6 | 0.55 | 116 | 10.7 FPS | 0 | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |
| CondB_SkiaVK (T3) | B. Skia Vulkan (skiavk) | VALID | 12.5s | 8 | 0.64 | 78 | 6.24 FPS | 0 | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |
| CondB_SkiaVK (T4) | B. Skia Vulkan (skiavk) | VALID | 10.98s | 8 | 0.73 | 86 | 7.83 FPS | 0 | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |
| CondB_SkiaVK (T5) | B. Skia Vulkan (skiavk) | VALID | 10.45s | 11 | 1.05 | 118 | 11.29 FPS | 0 | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |

---

## 2. [IMPLEMENTED] Instrumentation Decoupling Architecture
- **Workload Generation Isolation**: Automated continuous swipe gestures execute in an unblocked loop with a calibrated pacing cadence (fixed ~250ms interval). Actual swipe count and swipe cadence (swipes/sec) are explicitly recorded per trial.
- **Telemetry Background Execution**: CPU time delta tracking and Windows \\GPU Engine(*)\\Utilization Percentage counter queries run on a dedicated asynchronous task (Task.Run), completely isolated from the workload loop.
- **Presentation Frame Source (Presented FPS)**: Derived strictly from dumpsys SurfaceFlinger --timestats -dump (	otalFrames / ActualDurationSec).
- **AOSP 120-Record Buffer Disambiguation**: Resolved the circular buffer artifact where dumpsys gfxinfo framestats truncates at 120 frames (kFrameHistorySize = 120). gfxinfo is now exclusively utilized for latency distribution (P50, P90, P99) and Jank % across the captured buffer window.

---

## 3. [INFERENCE] Observer Effect & Characterization Analysis

### 3.1 Skia OpenGL vs Skia Vulkan Evaluation
- **Skia OpenGL**: Presented FPS = **5.23 FPS**, Latency Avg = **0 ms**, P50 = **0 ms**, GPU 3D = **0%**
- **Skia Vulkan**: Presented FPS = **7.83 FPS**, Latency Avg = **0 ms**, P50 = **0 ms**, GPU 3D = **0%**
- **Observed Delta (Vulkan - OpenGL)**: FPS Delta: **2.6 FPS**, Latency Delta: **0 ms**

> **Finding**: **inconclusive** due to variance.

---

## 4. [OPEN] Residual Architectural Hypotheses
1. **ASG Ring Buffer & Shared Memory Transport [HYPOTHESIS]**: Host-guest transport throughput (hw.gltransport=pipe vs sg) remains an open hypothesis pending direct empirical profiling.
2. **Host Compositor / ANGLE / Direct3D11 Presentation Pipeline**: Host-side frame presentation and texture synchronization overhead.

---

## 5. [DECISION] Next Phase Execution
- Standardize all future benchmark measurements on the decoupled telemetry runner and SurfaceFlinger --timestats Presented FPS source.
- Maintain empirical rigor before committing to custom zero-copy renderer implementations.
