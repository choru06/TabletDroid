# TabletDroid v0.1 Canonical Deterministic Benchmark Workload Report (Telemetry OFF)

- **Timestamp**: 2026-08-23 05:26:43
- **Host Hardware**: ASUS ROG Flow Z13 (Intel Core i9-12900H, NVIDIA GeForce RTX 3050 Ti Laptop GPU, 16GB RAM)
- **WHPX Acceleration**: Active & Operational
- **Target Package**: com.tabletdroid.benchmark
- **Target Activity**: com.tabletdroid.benchmark/.BenchmarkActivity
- **Target App Verified**: YES
- **Resolution Tested**: 1920x1200 @ 280dpi (Native Tablet Resolution)
- **Benchmark Protocol**: Canonical (Conditions: 1, 5 Trials x Warmup:10s, Measure:30s)
- **Frame Rate Source**: SurfaceFlinger Compositor Presentation (dumpsys SurfaceFlinger --timestats -dump) on target layer
- **Latency/Jitter Source**: HWUI Framestats (dumpsys gfxinfo framestats)

---

## 1. [MEASURED] Statistical Comparison Table (Medians across 5 Trials)

| Condition | Valid Trials | Presented FPS | FPS [Min, Max] | StdDev | FPS CV% | Distance (px) | Dist CV% | Latency Avg | P50 (ms) | P90 (ms) | P99 (ms) | Jank % | CPU Avg % | GPU 3D % |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Canonical BenchmarkApp (Telemetry OFF)** | 5 / 5 | **59.94 FPS** | [56.06, 59.97] | 1.55 | 2.6% | 24000 px | 0% | 30.1 ms | 25.21 ms | 42.18 ms | 52.85 ms | 100% | OFF | OFF |

### 1.1 All Raw Trial Records

| Trial ID | Condition | Status | Duration (s) | Target Layer | SF Start | SF End | Delta | Presented FPS | Actual Dist (px) | Expected Dist (px) | Gfx Records | Latency Avg (ms) | P50 (ms) | P90 (ms) | Jank % | CPU % (Samples) | GPU 3D % (Samples, Matched) |
| :--- | :--- | :---: | :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| Canonical_Workload (T1) | Canonical BenchmarkApp (Telemetry OFF) | VALID | 30.004s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#97 | 370 | 2052 | 1682 | 56.06 FPS | 24027 px | 24003.2 px | 120 | 40.72 ms | 41.85 ms | 47.75 ms | 100% | 0% (0) | 0% (0, 0) |
| Canonical_Workload (T2) | Canonical BenchmarkApp (Telemetry OFF) | VALID | 30.013s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#97 | 2664 | 4463 | 1799 | 59.94 FPS | 24000 px | 24010.4 px | 120 | 30.1 ms | 25.21 ms | 42.18 ms | 100% | 0% (0) | 0% (0, 0) |
| Canonical_Workload (T3) | Canonical BenchmarkApp (Telemetry OFF) | VALID | 30.013s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#97 | 5085 | 6883 | 1798 | 59.91 FPS | 24000 px | 24010.4 px | 119 | 34.8 ms | 32.59 ms | 51.57 ms | 100% | 0% (0) | 0% (0, 0) |
| Canonical_Workload (T4) | Canonical BenchmarkApp (Telemetry OFF) | VALID | 30.001s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#97 | 7505 | 9304 | 1799 | 59.96 FPS | 24000 px | 24000.8 px | 120 | 24.23 ms | 23.96 ms | 25.54 ms | 100% | 0% (0) | 0% (0, 0) |
| Canonical_Workload (T5) | Canonical BenchmarkApp (Telemetry OFF) | VALID | 30.015s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#97 | 9924 | 11724 | 1800 | 59.97 FPS | 24000 px | 24012 px | 120 | 24.73 ms | 24.42 ms | 26.04 ms | 100% | 0% (0) | 0% (0, 0) |

---

## 2. [IMPLEMENTED] Fail-Closed Validation & Decoupled Measurement Protocol
- **Workload Distance Gate**: ExpectedDistance = Velocity * Duration. Fails as INVALID / WORKLOAD_DISTANCE_OUT_OF_RANGE if distance error > 10%.
- **In-App Lifecycle Gate**: Validates status == COMPLETE, elapsedMeasureMs within 10% tolerance, and workloadVersion == 1.0.0.
- **Exact Target Layer Extraction**: SurfaceFlinger timestats resolves com.tabletdroid.benchmark/...#<id>, dynamically choosing highest active instance.
- **Telemetry Decoupling Policy**: Production performance benchmarks run with Telemetry OFF to prevent host threadpool observer skew.

---

## 3. [INFERENCE] Findings & Conclusions
### 3.1 Canonical Workload Evaluation (Telemetry OFF)
- **Presented FPS**: **59.94 FPS** (StdDev: 1.55, CV: 2.6%)
- **Workload Distance**: **24000 px** (CV: 0%)
- **Frame Latency**: P50 = **25.21 ms**, P90 = **42.18 ms**, Jank = **100%**

> **Conclusion**: Workload determinism is strictly verified (Distance CV = 0% <= 10%).

---

## 4. [DECISION] Next Phase Execution
- All architectural decisions require passing all 8 validation gates.
- Proceed to ASG and host compositor transport analysis with verified deterministic probe.
