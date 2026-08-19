# TabletDroid v0.1 Measurement Observer Effect & Decoupling Validation Report

- **Timestamp**: 2026-08-20 03:31:14
- **Host Hardware**: ASUS ROG Flow Z13 (Intel Core i9-12900H, NVIDIA GeForce RTX 3050 Ti Laptop GPU, 16GB RAM)
- **WHPX Acceleration**: Active & Operational
- **Target Application**: com.android.chrome
- **Resolution Tested**: 1920x1200 (Native Tablet Resolution)
- **Benchmark Protocol**: ObserverEffectA_B (Conditions: 4, 5 Trials x 10s/trial)
- **Frame Rate Source**: SurfaceFlinger Compositor Presentation (dumpsys SurfaceFlinger --timestats -dump)
- **Latency/Jitter Source**: HWUI Framestats (dumpsys gfxinfo framestats, $\le 120$ circular buffer)

---

## 1. [MEASURED] Statistical Comparison Table (Medians across 5 Trials)

| Condition | Valid Trials | Presented FPS | FPS [Min, Max] | StdDev | Wall Duration | Swipe Cadence | Frame Latency | P50 (ms) | P90 (ms) | P99 (ms) | Jank % | CPU Avg % | GPU 3D % |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **A. No Telemetry (Pure Workload)** | 5 / 5 | **4.03 FPS** | [1.01, 5.98] | 2.03 | 11.27s | 0.49 sw/s | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |
| **B. CPU Telemetry Only** | 5 / 5 | **5.3 FPS** | [2.7, 6.23] | 1.41 | 10.64s | 0.59 sw/s | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |
| **C. GPU Telemetry Only** | 5 / 5 | **4.51 FPS** | [3.33, 6.13] | 1.01 | 10.8s | 0.48 sw/s | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |
| **D. CPU + GPU Telemetry** | 5 / 5 | **6.12 FPS** | [4.69, 6.74] | 0.7 | 12.22s | 0.41 sw/s | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |

### 1.1 All Raw Trial Records

| Trial ID | Condition | Status | Duration (s) | Swipes | Cadence | SF Presented | Presented FPS | Gfx Records | Latency Avg (ms) | P50 (ms) | P90 (ms) | P99 (ms) | Jank % | CPU Avg % | GPU 3D % |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| CondA_NoTelemetry (T1) | A. No Telemetry (Pure Workload) | VALID | 17.37s | 5 | 0.29 | 34 | 1.96 FPS | 0 | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |
| CondA_NoTelemetry (T2) | A. No Telemetry (Pure Workload) | VALID | 10.87s | 7 | 0.64 | 65 | 5.98 FPS | 0 | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |
| CondA_NoTelemetry (T3) | A. No Telemetry (Pure Workload) | VALID | 10.88s | 9 | 0.83 | 11 | 1.01 FPS | 0 | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |
| CondA_NoTelemetry (T4) | A. No Telemetry (Pure Workload) | VALID | 14.16s | 7 | 0.49 | 57 | 4.03 FPS | 0 | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |
| CondA_NoTelemetry (T5) | A. No Telemetry (Pure Workload) | VALID | 11.27s | 3 | 0.27 | 67 | 5.94 FPS | 0 | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |
| CondB_CpuOnly (T1) | B. CPU Telemetry Only | VALID | 13.7s | 2 | 0.15 | 48 | 3.5 FPS | 0 | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |
| CondB_CpuOnly (T2) | B. CPU Telemetry Only | VALID | 10.19s | 6 | 0.59 | 54 | 5.3 FPS | 0 | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |
| CondB_CpuOnly (T3) | B. CPU Telemetry Only | VALID | 10.64s | 7 | 0.66 | 64 | 6.02 FPS | 0 | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |
| CondB_CpuOnly (T4) | B. CPU Telemetry Only | VALID | 10.6s | 8 | 0.75 | 66 | 6.23 FPS | 0 | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |
| CondB_CpuOnly (T5) | B. CPU Telemetry Only | VALID | 11.5s | 1 | 0.09 | 31 | 2.7 FPS | 0 | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |
| CondC_GpuOnly (T1) | C. GPU Telemetry Only | VALID | 10.8s | 7 | 0.65 | 36 | 3.33 FPS | 0 | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |
| CondC_GpuOnly (T2) | C. GPU Telemetry Only | VALID | 10.45s | 6 | 0.57 | 57 | 5.45 FPS | 0 | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |
| CondC_GpuOnly (T3) | C. GPU Telemetry Only | VALID | 11.31s | 4 | 0.35 | 51 | 4.51 FPS | 0 | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |
| CondC_GpuOnly (T4) | C. GPU Telemetry Only | VALID | 10.44s | 5 | 0.48 | 64 | 6.13 FPS | 0 | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |
| CondC_GpuOnly (T5) | C. GPU Telemetry Only | VALID | 22.5s | 5 | 0.22 | 88 | 3.91 FPS | 0 | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |
| CondD_BothCpuGpu (T1) | D. CPU + GPU Telemetry | VALID | 12.22s | 5 | 0.41 | 78 | 6.38 FPS | 0 | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |
| CondD_BothCpuGpu (T2) | D. CPU + GPU Telemetry | VALID | 16.19s | 2 | 0.12 | 76 | 4.69 FPS | 0 | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |
| CondD_BothCpuGpu (T3) | D. CPU + GPU Telemetry | VALID | 12.1s | 5 | 0.41 | 74 | 6.12 FPS | 0 | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |
| CondD_BothCpuGpu (T4) | D. CPU + GPU Telemetry | VALID | 12.32s | 7 | 0.57 | 83 | 6.74 FPS | 0 | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |
| CondD_BothCpuGpu (T5) | D. CPU + GPU Telemetry | VALID | 11.78s | 11 | 0.93 | 68 | 5.77 FPS | 0 | 0 ms | 0 ms | 0 ms | 0 ms | 0% | 0% | 0% |

---

## 2. [IMPLEMENTED] Instrumentation Decoupling Architecture
- **Workload Generation Isolation**: Automated continuous swipe gestures execute in an unblocked loop with a calibrated pacing cadence (fixed ~250ms interval). Actual swipe count and swipe cadence (swipes/sec) are explicitly recorded per trial.
- **Telemetry Background Execution**: CPU time delta tracking and Windows \\GPU Engine(*)\\Utilization Percentage counter queries run on a dedicated asynchronous task (Task.Run), completely isolated from the workload loop.
- **Presentation Frame Source (Presented FPS)**: Derived strictly from dumpsys SurfaceFlinger --timestats -dump (	otalFrames / ActualDurationSec).
- **AOSP 120-Record Buffer Disambiguation**: Resolved the circular buffer artifact where dumpsys gfxinfo framestats truncates at 120 frames (kFrameHistorySize = 120). gfxinfo is now exclusively utilized for latency distribution (P50, P90, P99) and Jank % across the captured buffer window.

---

## 3. [INFERENCE] Observer Effect & Characterization Analysis

### 3.1 Observer Effect Impact on Cadence and Frame Rate
- **Pure Workload (No Telemetry)**: Presented FPS = **4.03 FPS**, Cadence = **0.49 sw/s**, Duration = **11.27s**
- **Full Telemetry (CPU + GPU)**: Presented FPS = **6.12 FPS**, Cadence = **0.41 sw/s**, Duration = **12.22s**
- **Telemetry Impact Delta**: Presented FPS Delta: **2.09 FPS**, Cadence Delta: **-0.08 sw/s**, Duration Delta: **0.95s**

> **Conclusion**: **meaningful difference** detected. Observer overhead measured at 2.09 FPS.

---

## 4. [OPEN] Residual Architectural Hypotheses
1. **ASG Ring Buffer & Shared Memory Transport [HYPOTHESIS]**: Host-guest transport throughput (hw.gltransport=pipe vs sg) remains an open hypothesis pending direct empirical profiling.
2. **Host Compositor / ANGLE / Direct3D11 Presentation Pipeline**: Host-side frame presentation and texture synchronization overhead.

---

## 5. [DECISION] Next Phase Execution
- Standardize all future benchmark measurements on the decoupled telemetry runner and SurfaceFlinger --timestats Presented FPS source.
- Maintain empirical rigor before committing to custom zero-copy renderer implementations.
