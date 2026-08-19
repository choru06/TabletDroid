# TabletDroid v0.1 GPU HWUI Renderer Comparison Report (OpenGL vs Vulkan - Telemetry OFF)

- **Timestamp**: 2026-08-20 04:29:47
- **Host Hardware**: ASUS ROG Flow Z13 (Intel Core i9-12900H, NVIDIA GeForce RTX 3050 Ti Laptop GPU, 16GB RAM)
- **WHPX Acceleration**: Active & Operational
- **Target Package**: com.tabletdroid.benchmark
- **Target Activity**: com.tabletdroid.benchmark/.BenchmarkActivity
- **Target App Verified**: YES
- **Resolution Tested**: 1920x1200 @ 280dpi (Native Tablet Resolution)
- **Benchmark Protocol**: GpuRendererComparison (Conditions: 2, 5 Trials x Warmup:5s, Measure:10s)
- **Frame Rate Source**: SurfaceFlinger Compositor Presentation (dumpsys SurfaceFlinger --timestats -dump) on target layer
- **Latency/Jitter Source**: HWUI Framestats (dumpsys gfxinfo framestats)

---

## 1. [MEASURED] Statistical Comparison Table (Medians across 5 Trials)

| Condition | Valid Trials | Presented FPS | FPS [Min, Max] | StdDev | FPS CV% | Distance (px) | Dist CV% | Latency Avg | P50 (ms) | P90 (ms) | P99 (ms) | Jank % | CPU Avg % | GPU 3D % |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **A. Skia OpenGL (skiagl)** | 5 / 5 | **11.7 FPS** | [8.29, 16.98] | 2.88 | 24% | 8133 px | 0.9% | 257.86 ms | 211.25 ms | 519.17 ms | 748.22 ms | 100% | OFF | OFF |
| **B. Skia Vulkan (skiavk)** | 5 / 5 | **10 FPS** | [6.89, 12.48] | 2.3 | 23.8% | 8134 px | 0.6% | 279.14 ms | 238.61 ms | 496.55 ms | 724.54 ms | 100% | OFF | OFF |

### 1.1 All Raw Trial Records

| Trial ID | Condition | Status | Duration (s) | Target Layer | SF Start | SF End | Delta | Presented FPS | Actual Dist (px) | Expected Dist (px) | Gfx Records | Latency Avg (ms) | P50 (ms) | P90 (ms) | Jank % | CPU % (Samples) | GPU 3D % (Samples, Matched) |
| :--- | :--- | :---: | :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| CondA_SkiaGL (T1) | A. Skia OpenGL (skiagl) | VALID | 10.011s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#2508 | 74 | 244 | 170 | 16.98 FPS | 8120 px | 8008.8 px | 120 | 157.46 ms | 137.23 ms | 249 ms | 100% | 0% (0) | 0% (0, 0) |
| CondA_SkiaGL (T2) | A. Skia OpenGL (skiagl) | VALID | 10.001s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#2508 | 311 | 428 | 117 | 11.7 FPS | 8133 px | 8000.8 px | 120 | 257.86 ms | 206.52 ms | 519.17 ms | 100% | 0% (0) | 0% (0, 0) |
| CondA_SkiaGL (T3) | A. Skia OpenGL (skiagl) | VALID | 10.005s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#2508 | 506 | 610 | 104 | 10.39 FPS | 8280 px | 8004 px | 120 | 306.73 ms | 273.47 ms | 573.86 ms | 100% | 0% (0) | 0% (0, 0) |
| CondA_SkiaGL (T4) | A. Skia OpenGL (skiagl) | VALID | 10.013s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#2508 | 658 | 784 | 126 | 12.58 FPS | 8147 px | 8010.4 px | 120 | 236.5 ms | 211.25 ms | 367.38 ms | 100% | 0% (0) | 0% (0, 0) |
| CondA_SkiaGL (T5) | A. Skia OpenGL (skiagl) | VALID | 10.015s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#2508 | 844 | 927 | 83 | 8.29 FPS | 8054 px | 8012 px | 120 | 310.83 ms | 265.01 ms | 705.76 ms | 100% | 0% (0) | 0% (0, 0) |
| CondB_SkiaVK (T1) | B. Skia Vulkan (skiavk) | VALID | 10.013s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#2533 | 58 | 183 | 125 | 12.48 FPS | 8173 px | 8010.4 px | 120 | 230.9 ms | 211.42 ms | 353.87 ms | 100% | 0% (0) | 0% (0, 0) |
| CondB_SkiaVK (T2) | B. Skia Vulkan (skiavk) | VALID | 10.009s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#2533 | 252 | 370 | 118 | 11.79 FPS | 8134 px | 8007.2 px | 120 | 256.17 ms | 229.14 ms | 426.77 ms | 100% | 0% (0) | 0% (0, 0) |
| CondB_SkiaVK (T3) | B. Skia Vulkan (skiavk) | VALID | 10.001s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#2533 | 440 | 540 | 100 | 10 FPS | 8107 px | 8000.8 px | 120 | 279.14 ms | 238.61 ms | 496.55 ms | 100% | 0% (0) | 0% (0, 0) |
| CondB_SkiaVK (T4) | B. Skia Vulkan (skiavk) | VALID | 10.013s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#2533 | 592 | 664 | 72 | 7.19 FPS | 8093 px | 8010.4 px | 120 | 393.05 ms | 310.08 ms | 792.88 ms | 100% | 0% (0) | 0% (0, 0) |
| CondB_SkiaVK (T5) | B. Skia Vulkan (skiavk) | VALID | 10.012s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#2533 | 698 | 767 | 69 | 6.89 FPS | 8226 px | 8009.6 px | 101 | 480.65 ms | 406.99 ms | 846.37 ms | 100% | 0% (0) | 0% (0, 0) |

---

## 2. [IMPLEMENTED] Fail-Closed Validation & Decoupled Measurement Protocol
- **Workload Distance Gate**: ExpectedDistance = Velocity * Duration. Fails as INVALID / WORKLOAD_DISTANCE_OUT_OF_RANGE if distance error > 10%.
- **In-App Lifecycle Gate**: Validates status == COMPLETE, elapsedMeasureMs within 10% tolerance, and workloadVersion == 1.0.0.
- **Exact Target Layer Extraction**: SurfaceFlinger timestats resolves com.tabletdroid.benchmark/...#<id>, dynamically choosing highest active instance.
- **Telemetry Decoupling Policy**: Production performance benchmarks run with Telemetry OFF to prevent host threadpool observer skew.

---

## 3. [INFERENCE] Findings & Conclusions
### 3.1 Skia OpenGL vs Skia Vulkan Evaluation (Telemetry OFF)
- **Skia OpenGL**: Presented FPS = **11.7 FPS**, Distance = **8133 px** (CV: 0.9%), P50 = **211.25 ms**
- **Skia Vulkan**: Presented FPS = **10 FPS**, Distance = **8134 px** (CV: 0.6%), P50 = **238.61 ms**
- **Observed Delta (Vulkan - OpenGL)**: FPS Delta: **-1.7 FPS**

> **Finding**: **no meaningful difference**

---

## 4. [DECISION] Next Phase Execution
- All architectural decisions require passing all 8 validation gates.
- Proceed to ASG and host compositor transport analysis with verified deterministic probe.
