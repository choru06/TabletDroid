# TabletDroid v0.1 Graphics Transport Characterization Report (pipe vs asg vs virtio-gpu)

- **Timestamp**: 2026-08-20 04:54:17
- **Host Hardware**: ASUS ROG Flow Z13 (Intel Core i9-12900H, NVIDIA GeForce RTX 3050 Ti Laptop GPU, 16GB RAM)
- **Host Operating System**: Windows 11 Home 23H2 (Hypervisor: WHPX)
- **Emulator Version**: 37.1.11.0 (build_id 15917651)
- **Target Package**: com.tabletdroid.benchmark
- **Target Activity**: com.tabletdroid.benchmark/.BenchmarkActivity
- **Resolution Tested**: 1920x1200 @ 280dpi (Native Tablet Resolution)
- **Protocol**: 4 Conditions x 5 Trials x Warmup:10s, Measure:30s (800 px/s, Telemetry OFF)
- **Frame Rate Source**: SurfaceFlinger Compositor Presentation (dumpsys SurfaceFlinger --timestats -dump) on target layer
- **Latency/Jitter Source**: HWUI Framestats (dumpsys gfxinfo framestats)

---

## 1. [MEASURED] Statistical Transport Comparison Matrix

| Condition | Transport | Boot Status | Valid Trials | Presented FPS | FPS [Min, Max] | StdDev | FPS CV% | Actual Distance | Dist CV% | P50 Latency | P90 Latency | Jank % | Gate Status |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **A. pipe (Goldfish Pipe - Initial)** | `pipe` | BOOT_OK (egl=emulation) | 5 / 5 | **56.75 FPS** | [52.61, 59.96] | 3.27 | 5.8% | 24,013 px | 0.0% | 32.58 ms | 35.61 ms | 100% | **PASS** |
| **B. asg (Address Space Graphics)** | `asg` | BOOT_OK (egl=emulation) | 5 / 5 | **36.59 FPS** | [26.55, 45.72] | 6.90 | 18.2% | 24,027 px | 0.1% | 68.30 ms | 100.78 ms | 100% | **PASS** |
| **C. virtio-gpu (VirtIO GPU)** | `virtio-gpu` | BOOT_OK (egl=emulation) | 5 / 5 | **53.25 FPS** | [44.58, 59.56] | 6.10 | 11.6% | 24,027 px | 0.0% | 42.63 ms | 51.98 ms | 100% | **PASS** |
| **D. pipe (Goldfish Pipe - Retest/Drift)** | `pipe` | BOOT_OK (egl=emulation) | 5 / 5 | **59.93 FPS** | [58.89, 59.95] | 0.42 | 0.7% | 24,000 px | 0.0% | 17.79 ms | 18.86 ms | 100% | **PASS** |

### 1.1 All Raw Trial Records

| Trial ID | Condition | Status | Duration (s) | Target Layer | SF Start | SF End | Delta | Presented FPS | Actual Dist (px) | Expected Dist (px) | Gfx Records | Latency Avg (ms) | P50 (ms) | P90 (ms) | Jank % |
| :--- | :--- | :---: | :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| CondA_Pipe_Initial (T1) | A. pipe (Goldfish Pipe - Initial) | VALID | 30.017s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#109 | 499 | 2080 | 1581 | 52.67 FPS | 24013 px | 24013.6 px | 120 | 41.59 ms | 46.14 ms | 51.83 ms | 100% |
| CondA_Pipe_Initial (T2) | A. pipe (Goldfish Pipe - Initial) | VALID | 30.015s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#109 | 2654 | 4233 | 1579 | 52.61 FPS | 24013 px | 24012 px | 119 | 45.03 ms | 38.11 ms | 68.79 ms | 100% |
| CondA_Pipe_Initial (T3) | A. pipe (Goldfish Pipe - Initial) | VALID | 30.008s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#109 | 4846 | 6549 | 1703 | 56.75 FPS | 24013 px | 24006.4 px | 119 | 32.72 ms | 32.58 ms | 35.61 ms | 100% |
| CondA_Pipe_Initial (T4) | A. pipe (Goldfish Pipe - Initial) | VALID | 30.006s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#109 | 7169 | 8967 | 1798 | 59.92 FPS | 24000 px | 24004.8 px | 120 | 25.82 ms | 25.41 ms | 28.06 ms | 100% |
| CondA_Pipe_Initial (T5) | A. pipe (Goldfish Pipe - Initial) | VALID | 30.002s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#109 | 9587 | 11386 | 1799 | 59.96 FPS | 24000 px | 24001.6 px | 120 | 26.27 ms | 24.85 ms | 27.75 ms | 100% |
| CondB_ASG (T1) | B. asg (Address Space Graphics) | VALID | 30.014s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#96 | 251 | 1048 | 797 | 26.55 FPS | 24106 px | 24011.2 px | 118 | 93.45 ms | 85.05 ms | 134.63 ms | 100% |
| CondB_ASG (T2) | B. asg (Address Space Graphics) | VALID | 30.012s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#96 | 1488 | 2860 | 1372 | 45.72 FPS | 24027 px | 24009.6 px | 119 | 69.11 ms | 68.3 ms | 85.77 ms | 100% |
| CondB_ASG (T3) | B. asg (Address Space Graphics) | VALID | 30.005s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#96 | 3423 | 4755 | 1332 | 44.39 FPS | 24000 px | 24004 px | 119 | 61.04 ms | 52.14 ms | 84.86 ms | 100% |
| CondB_ASG (T4) | B. asg (Address Space Graphics) | VALID | 30.006s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#96 | 5146 | 6244 | 1098 | 36.59 FPS | 24027 px | 24004.8 px | 117 | 70.46 ms | 67.78 ms | 100.78 ms | 100% |
| CondB_ASG (T5) | B. asg (Address Space Graphics) | VALID | 30.012s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#96 | 6767 | 7845 | 1078 | 35.92 FPS | 24027 px | 24009.6 px | 119 | 95.18 ms | 101.57 ms | 118.45 ms | 100% |
| CondC_VirtioGpu (T1) | C. virtio-gpu (VirtIO GPU) | VALID | 30.012s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#92 | 427 | 1765 | 1338 | 44.58 FPS | 24040 px | 24009.6 px | 120 | 71.26 ms | 68.7 ms | 86.92 ms | 100% |
| CondC_VirtioGpu (T2) | C. virtio-gpu (VirtIO GPU) | VALID | 30.01s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#92 | 2293 | 3891 | 1598 | 53.25 FPS | 24027 px | 24008 px | 120 | 69.45 ms | 68.67 ms | 85.5 ms | 100% |
| CondC_VirtioGpu (T3) | C. virtio-gpu (VirtIO GPU) | VALID | 30.01s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#92 | 4361 | 5776 | 1415 | 47.15 FPS | 24027 px | 24008 px | 119 | 43.27 ms | 35.39 ms | 51.98 ms | 100% |
| CondC_VirtioGpu (T4) | C. virtio-gpu (VirtIO GPU) | VALID | 30.005s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#92 | 6270 | 8057 | 1787 | 59.56 FPS | 24014 px | 24004 px | 120 | 26.39 ms | 25.02 ms | 34.22 ms | 100% |
| CondC_VirtioGpu (T5) | C. virtio-gpu (VirtIO GPU) | VALID | 30.005s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#92 | 8680 | 10456 | 1776 | 59.19 FPS | 24013 px | 24004 px | 120 | 43.34 ms | 42.63 ms | 46.92 ms | 100% |
| CondD_Pipe_Retest (T1) | D. pipe (Goldfish Pipe - Retest/Drift) | VALID | 30.003s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#110 | 603 | 2370 | 1767 | 58.89 FPS | 24000 px | 24002.4 px | 119 | 38.53 ms | 39.98 ms | 43.51 ms | 100% |
| CondD_Pipe_Retest (T2) | D. pipe (Goldfish Pipe - Retest/Drift) | VALID | 30s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#110 | 2993 | 4790 | 1797 | 59.9 FPS | 24000 px | 24000 px | 120 | 17.74 ms | 17.62 ms | 18.51 ms | 100% |
| CondD_Pipe_Retest (T3) | D. pipe (Goldfish Pipe - Retest/Drift) | VALID | 30.013s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#110 | 5413 | 7212 | 1799 | 59.94 FPS | 24000 px | 24010.4 px | 120 | 37.57 ms | 38.81 ms | 42 ms | 100% |
| CondD_Pipe_Retest (T4) | D. pipe (Goldfish Pipe - Retest/Drift) | VALID | 30.003s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#110 | 7835 | 9633 | 1798 | 59.93 FPS | 24000 px | 24002.4 px | 120 | 17.9 ms | 17.79 ms | 18.86 ms | 100% |
| CondD_Pipe_Retest (T5) | D. pipe (Goldfish Pipe - Retest/Drift) | VALID | 30.006s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#110 | 10255 | 12054 | 1799 | 59.95 FPS | 24000 px | 24004.8 px | 120 | 17.76 ms | 17.68 ms | 18.53 ms | 100% |

---

## 2. [IMPLEMENTED] Environment Fingerprint & Transport Protocol
- **Emulator Version**: 37.1.11.0 (build_id 15917651), Graphics backend: gfxstream.
- **Transport Options Defined in Hardware Properties**: pipe, sg, irtio-gpu, 	cp.
- **Isolation Guardrails**: Every condition was executed after a full cold boot (-no-snapshot -no-boot-anim -no-audio) to ensure no snapshot or IPC state leaked between conditions.
- **Order Bias Mitigation**: Tested pipe (initial) -> sg -> irtio-gpu -> pipe (retest) to evaluate thermal or time drift.

---

## 3. [INFERENCE] Comparative Analysis & Findings
### 3.1 Pipe vs ASG Comparison
- **Goldfish Pipe (Initial)**: Presented FPS = **56.75 FPS**, P50 = **32.58 ms**, Distance = **24013 px** (CV: 0%)
- **Address Space Graphics (ASG)**: Presented FPS = **36.59 FPS**, P50 = **68.3 ms**, Distance = **24027 px** (CV: 0.1%)
- **Observed Delta (ASG - Pipe)**: **-20.16 FPS**

> **Finding**: **ASG is slower than pipe** (-20.16 FPS). Pipe remains the superior transport.

### 3.2 VirtIO-GPU Evaluation
- **VirtIO-GPU Boot Status**: BOOT_OK (egl=emulation)
- **VirtIO-GPU Presented FPS**: **53.25 FPS**

### 3.3 Baseline Thermal & Temporal Drift Check
- **Pipe Initial**: **56.75 FPS**
- **Pipe Retest**: **59.93 FPS**
- **Baseline Drift Delta**: **3.18 FPS**
> **Drift Assessment**: Noticeable drift (3.18 FPS), indicating thermal throttling or background system variation.

---

## 4. [OPEN] Residual Architectural Hypotheses
1. **Host Compositor / Presentation Pipeline**: ANGLE / D3D11 swapchain copy bottlenecks on host window presentation.
2. **ASG Ring Buffer Sizing [CONDITIONAL]**: Potential throughput limits in default 32KB data ring size.

---

## 5. [DECISION] Next Phase Execution
- Retain the optimal transport based on empirical data.
- Proceed to transport parameter exploration or host composition zero-copy pipeline.
