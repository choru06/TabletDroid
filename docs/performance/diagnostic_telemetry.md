# TabletDroid v0.1 Diagnostic Host Telemetry Report

- **Timestamp**: 2026-08-20 04:30:22
- **Host Hardware**: ASUS ROG Flow Z13 (Intel Core i9-12900H, NVIDIA GeForce RTX 3050 Ti Laptop GPU, 16GB RAM)
- **WHPX Acceleration**: Active & Operational
- **Target Package**: com.tabletdroid.benchmark
- **Target Activity**: com.tabletdroid.benchmark/.BenchmarkActivity
- **Target App Verified**: YES
- **Resolution Tested**: 1920x1200 @ 280dpi (Native Tablet Resolution)
- **Benchmark Protocol**: DiagnosticTelemetry (Conditions: 1, 1 Trials x Warmup:5s, Measure:15s)
- **Frame Rate Source**: SurfaceFlinger Compositor Presentation (dumpsys SurfaceFlinger --timestats -dump) on target layer
- **Latency/Jitter Source**: HWUI Framestats (dumpsys gfxinfo framestats)

---

## 1. [MEASURED] Statistical Comparison Table (Medians across 1 Trials)

| Condition | Valid Trials | Presented FPS | FPS [Min, Max] | StdDev | FPS CV% | Distance (px) | Dist CV% | Latency Avg | P50 (ms) | P90 (ms) | P99 (ms) | Jank % | CPU Avg % | GPU 3D % |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Diagnostic Telemetry Run (CPU+GPU ON)** | 1 / 1 | **7.8 FPS** | [7.8, 7.8] | 0 | 0% | 12146 px | 0% | 386.95 ms | 385.87 ms | 566.29 ms | 924.34 ms | 100% | 17.7 | 4.5 |

### 1.1 All Raw Trial Records

| Trial ID | Condition | Status | Duration (s) | Target Layer | SF Start | SF End | Delta | Presented FPS | Actual Dist (px) | Expected Dist (px) | Gfx Records | Latency Avg (ms) | P50 (ms) | P90 (ms) | Jank % | CPU % (Samples) | GPU 3D % (Samples, Matched) |
| :--- | :--- | :---: | :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| Diag_Telemetry (T1) | Diagnostic Telemetry Run (CPU+GPU ON) | VALID | 15.005s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#2533 | 851 | 968 | 117 | 7.8 FPS | 12146 px | 12004 px | 120 | 386.95 ms | 385.87 ms | 566.29 ms | 100% | 17.7% (1) | 4.5% (1, 47) |

---

## 2. [IMPLEMENTED] Fail-Closed Validation & Decoupled Measurement Protocol
- **Workload Distance Gate**: ExpectedDistance = Velocity * Duration. Fails as INVALID / WORKLOAD_DISTANCE_OUT_OF_RANGE if distance error > 10%.
- **In-App Lifecycle Gate**: Validates status == COMPLETE, elapsedMeasureMs within 10% tolerance, and workloadVersion == 1.0.0.
- **Exact Target Layer Extraction**: SurfaceFlinger timestats resolves com.tabletdroid.benchmark/...#<id>, dynamically choosing highest active instance.
- **Telemetry Decoupling Policy**: Production performance benchmarks run with Telemetry OFF to prevent host threadpool observer skew.

---

## 3. [INFERENCE] Findings & Conclusions
### 3.1 Host Telemetry Diagnostic Profile
- **QEMU CPU Avg**: **17.7%**
- **RTX 3050 Ti GPU 3D Avg**: **4.5%**
- **Presented FPS with Telemetry**: **7.8 FPS**

---

## 4. [DECISION] Next Phase Execution
- All architectural decisions require passing all 8 validation gates.
- Proceed to ASG and host compositor transport analysis with verified deterministic probe.
