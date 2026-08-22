# TabletDroid v0.1 SurfaceFlinger Tuning Regression Isolation Report

- **Timestamp**: 2026-08-23 05:21:36
- **Host Hardware**: ASUS ROG Flow Z13 (Intel Core i9-12900H, NVIDIA GeForce RTX 3050 Ti Laptop GPU, 16GB RAM)
- **Host Operating System**: Windows 11 Home 23H2 (Hypervisor: WHPX)
- **Emulator Version**: 37.1.11.0 (build_id 15917651)
- **Target Package**: com.tabletdroid.benchmark
- **Target Activity**: com.tabletdroid.benchmark/.BenchmarkActivity
- **Resolution Tested**: 1920x1200 @ 280dpi (Native Tablet Resolution)
- **Transport**: hw.gltransport=pipe, hw.gpu.mode=host (Fixed)
- **Protocol**: 4 Conditions x 5 Trials x Warmup:10s, Measure:30s (800 px/s, Telemetry OFF)
- **Frame Rate Source**: SurfaceFlinger Compositor Presentation (dumpsys SurfaceFlinger --timestats -dump) on target layer
- **Latency/Jitter Source**: HWUI Framestats (dumpsys gfxinfo framestats)

---

## 1. [MEASURED] Statistical Comparison Matrix

| Condition | latch_unsignaled | disable_backpressure | Valid Trials | Presented FPS | FPS [Min, Max] | StdDev | FPS CV% | Actual Distance | Dist CV% | P50 Latency | P90 Latency | Gate Status |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **A. Baseline (Default / Unset)** | `<unset>` | `<unset>` | 5 / 5 | **59.90 FPS** | [55.25, 59.95] | 1.84 | 3.1% | 24,000 px | 0.0% | 22.83 ms | 24.99 ms | **PASS** |
| **B. Latch Only (latch_unsignaled=1)** | `1` | `<unset>` | 5 / 5 | **59.87 FPS** | [55.26, 59.99] | 1.86 | 3.2% | 24,000 px | 0.0% | 41.76 ms | 47.35 ms | **PASS** |
| **C. Backpressure Only (disable_bp=1)** | `<unset>` | `1` | 5 / 5 | **59.89 FPS** | [54.82, 59.97] | 1.99 | 3.4% | 24,000 px | 0.0% | 24.86 ms | 27.04 ms | **PASS** |
| **D. Both (latch=1 + disable_bp=1)** | `1` | `1` | 5 / 5 | **59.97 FPS** | [55.08, 60.00] | 1.96 | 3.3% | 24,000 px | 0.0% | 25.24 ms | 29.61 ms | **PASS** |

### 1.1 All Raw Trial Records

| Trial ID | Condition | Status | Duration (s) | Target Layer | SF Start | SF End | Delta | Presented FPS | Actual Dist (px) | Expected Dist (px) | Gfx Records | Latency Avg (ms) | P50 (ms) | P90 (ms) | Jank % |
| :--- | :--- | :---: | :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| CondA_Baseline (T1) | A. Baseline (Default / Unset) | VALID | 30.007s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#95 | 572 | 2230 | 1658 | 55.25 FPS | 24000 px | 24005.6 px | 120 | 33.91 ms | 31.24 ms | 50.75 ms | 99.2% |
| CondA_Baseline (T2) | A. Baseline (Default / Unset) | VALID | 30s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#95 | 2839 | 4576 | 1737 | 57.9 FPS | 24014 px | 24000 px | 120 | 23.09 ms | 22.83 ms | 25.02 ms | 100% |
| CondA_Baseline (T3) | A. Baseline (Default / Unset) | VALID | 30.01s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#95 | 5199 | 6997 | 1798 | 59.91 FPS | 24000 px | 24008 px | 120 | 22.08 ms | 21.73 ms | 23.21 ms | 100% |
| CondA_Baseline (T4) | A. Baseline (Default / Unset) | VALID | 30.01s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#95 | 7617 | 9416 | 1799 | 59.95 FPS | 24000 px | 24008 px | 120 | 23.39 ms | 23.3 ms | 24.99 ms | 100% |
| CondA_Baseline (T5) | A. Baseline (Default / Unset) | VALID | 30.015s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#95 | 10039 | 11837 | 1798 | 59.9 FPS | 24000 px | 24012 px | 120 | 17.87 ms | 17.81 ms | 18.86 ms | 100% |
| CondB_LatchOnly (T1) | B. Latch Only (latch_unsignaled=1) | VALID | 30.02s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#96 | 385 | 2044 | 1659 | 55.26 FPS | 24013 px | 24016 px | 120 | 37.97 ms | 36.05 ms | 51.74 ms | 100% |
| CondB_LatchOnly (T2) | B. Latch Only (latch_unsignaled=1) | VALID | 30.009s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#96 | 2667 | 4463 | 1796 | 59.85 FPS | 24000 px | 24007.2 px | 120 | 45.09 ms | 44.07 ms | 50.86 ms | 100% |
| CondB_LatchOnly (T3) | B. Latch Only (latch_unsignaled=1) | VALID | 30.003s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#96 | 5081 | 6881 | 1800 | 59.99 FPS | 24013 px | 24002.4 px | 120 | 25.31 ms | 25.07 ms | 26.62 ms | 100% |
| CondB_LatchOnly (T4) | B. Latch Only (latch_unsignaled=1) | VALID | 30.004s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#96 | 7502 | 9299 | 1797 | 59.89 FPS | 24000 px | 24003.2 px | 120 | 43.36 ms | 42.84 ms | 47.35 ms | 100% |
| CondB_LatchOnly (T5) | B. Latch Only (latch_unsignaled=1) | VALID | 30.013s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#96 | 9921 | 11718 | 1797 | 59.87 FPS | 24000 px | 24010.4 px | 120 | 42.64 ms | 41.76 ms | 47.11 ms | 100% |
| CondC_BackpressureOnly (T1) | C. Backpressure Only (disable_bp=1) | VALID | 30.009s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#106 | 468 | 2113 | 1645 | 54.82 FPS | 24013 px | 24007.2 px | 118 | 29.76 ms | 28.06 ms | 34.13 ms | 100% |
| CondC_BackpressureOnly (T2) | C. Backpressure Only (disable_bp=1) | VALID | 30.007s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#106 | 2735 | 4534 | 1799 | 59.95 FPS | 24000 px | 24005.6 px | 120 | 25.15 ms | 24.86 ms | 27.04 ms | 100% |
| CondC_BackpressureOnly (T3) | C. Backpressure Only (disable_bp=1) | VALID | 30.007s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#106 | 5155 | 6952 | 1797 | 59.89 FPS | 24000 px | 24005.6 px | 120 | 26.22 ms | 25.79 ms | 28.87 ms | 100% |
| CondC_BackpressureOnly (T4) | C. Backpressure Only (disable_bp=1) | VALID | 30.013s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#106 | 7571 | 9371 | 1800 | 59.97 FPS | 24000 px | 24010.4 px | 120 | 24.23 ms | 24.05 ms | 25.2 ms | 100% |
| CondC_BackpressureOnly (T5) | C. Backpressure Only (disable_bp=1) | VALID | 30.004s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#106 | 9993 | 11766 | 1773 | 59.09 FPS | 24000 px | 24003.2 px | 120 | 24.94 ms | 24.69 ms | 26.68 ms | 100% |
| CondD_Both (T1) | D. Both (latch=1 + disable_bp=1) | VALID | 30.01s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#92 | 472 | 2125 | 1653 | 55.08 FPS | 24027 px | 24008 px | 120 | 29.54 ms | 28.85 ms | 34.79 ms | 100% |
| CondD_Both (T2) | D. Both (latch=1 + disable_bp=1) | VALID | 30.006s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#92 | 2747 | 4546 | 1799 | 59.95 FPS | 24000 px | 24004.8 px | 120 | 25.2 ms | 24.46 ms | 28.37 ms | 100% |
| CondD_Both (T3) | D. Both (latch=1 + disable_bp=1) | VALID | 30.014s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#92 | 5166 | 6966 | 1800 | 59.97 FPS | 24000 px | 24011.2 px | 120 | 26.12 ms | 25.22 ms | 30.34 ms | 100% |
| CondD_Both (T4) | D. Both (latch=1 + disable_bp=1) | VALID | 30.002s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#92 | 7586 | 9386 | 1800 | 60 FPS | 24000 px | 24001.6 px | 120 | 25.94 ms | 25.34 ms | 29.61 ms | 100% |
| CondD_Both (T5) | D. Both (latch=1 + disable_bp=1) | VALID | 30s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#92 | 10006 | 11806 | 1800 | 60 FPS | 24013 px | 24000 px | 120 | 25.57 ms | 25.24 ms | 27.26 ms | 100% |

---

## 2. [IMPLEMENTED] Experimental Protocol & Property Isolation
- **Fresh Cold Boot Isolation**: Each condition was executed after an independent cold boot (-no-snapshot -no-boot-anim -no-audio) to ensure no previous property injection state leaked across conditions.
- **Readback Verification**: Verified debug.sf.latch_unsignaled and debug.sf.disable_backpressure before and after injection via getprop.
- **Deterministic Probe**: Canonical com.tabletdroid.benchmark workload with sub-pixel Choreographer motion and 8 Fail-Closed Validity Gates.

---

## 3. [INFERENCE] Comparative Analysis & Findings
### 3.1 Baseline (Default) vs Both (latch=1 + disable_backpressure=1)
- **A. Baseline (Default/Unset)**: Presented FPS = **59.9 FPS**, P50 = **22.83 ms**
- **D. Both (latch=1 + disable_bp=1)**: Presented FPS = **59.97 FPS**, P50 = **25.24 ms**
- **Observed Delta (Both - Baseline)**: **0.07 FPS**

> **Finding**: No significant impact (0.07 FPS delta).

### 3.2 Individual Property Impact
- **Latch Only**: **59.87 FPS** (Delta vs Baseline: -0.03 FPS)
- **Backpressure Only**: **59.89 FPS** (Delta vs Baseline: -0.01 FPS)

---

## 4. [DECISION] Architectural Rectification & Action Items
1. **Remove Injected SurfaceFlinger Properties**: Purge debug.sf.latch_unsignaled=1 and debug.sf.disable_backpressure=1 from all runner scripts and runtime launch paths.
2. **Historical Invalidation**: Mark all prior claims that SurfaceFlinger property injection improved performance as SUPERSEDED / INVALIDATED.
3. **Lock Default SurfaceFlinger Configuration**: Maintain default Android SurfaceFlinger pipeline settings for production and benchmark executions.
