# TabletDroid v0.1 Canonical Deterministic Benchmark Workload Report (Telemetry OFF)

- **Timestamp**: 2026-08-20 04:25:54
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
| **Canonical BenchmarkApp (Telemetry OFF)** | 5 / 5 | **12.46 FPS** | [11.57, 14.23] | 0.94 | 7.3% | 24200 px | 0.4% | 218.01 ms | 166.43 ms | 353.56 ms | 424.86 ms | 100% | OFF | OFF |

### 1.1 All Raw Trial Records

| Trial ID | Condition | Status | Duration (s) | Target Layer | SF Start | SF End | Delta | Presented FPS | Actual Dist (px) | Expected Dist (px) | Gfx Records | Latency Avg (ms) | P50 (ms) | P90 (ms) | Jank % | CPU % (Samples) | GPU 3D % (Samples, Matched) |
| :--- | :--- | :---: | :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| Canonical_Workload (T1) | Canonical BenchmarkApp (Telemetry OFF) | VALID | 30.012s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#2483 | 118 | 525 | 407 | 13.56 FPS | 24186 px | 24009.6 px | 120 | 218.01 ms | 135 ms | 547.15 ms | 100% | 0% (0) | 0% (0, 0) |
| Canonical_Workload (T2) | Canonical BenchmarkApp (Telemetry OFF) | VALID | 30.003s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#2483 | 652 | 999 | 347 | 11.57 FPS | 24200 px | 24002.4 px | 120 | 304.05 ms | 193.06 ms | 808.2 ms | 100% | 0% (0) | 0% (0, 0) |
| Canonical_Workload (T3) | Canonical BenchmarkApp (Telemetry OFF) | VALID | 30.006s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#2483 | 1128 | 1555 | 427 | 14.23 FPS | 24413 px | 24004.8 px | 120 | 126.77 ms | 131.23 ms | 159.55 ms | 100% | 0% (0) | 0% (0, 0) |
| Canonical_Workload (T4) | Canonical BenchmarkApp (Telemetry OFF) | VALID | 30.013s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#2483 | 1701 | 2075 | 374 | 12.46 FPS | 24200 px | 24010.4 px | 120 | 226.07 ms | 212.9 ms | 353.56 ms | 100% | 0% (0) | 0% (0, 0) |
| Canonical_Workload (T5) | Canonical BenchmarkApp (Telemetry OFF) | VALID | 30.001s | com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#2483 | 2206 | 2578 | 372 | 12.4 FPS | 24213 px | 24000.8 px | 120 | 189.46 ms | 166.43 ms | 322.65 ms | 100% | 0% (0) | 0% (0, 0) |

---

## 2. [IMPLEMENTED] Fail-Closed Validation & Decoupled Measurement Protocol
- **Workload Distance Gate**: ExpectedDistance = Velocity * Duration. Fails as INVALID / WORKLOAD_DISTANCE_OUT_OF_RANGE if distance error > 10%.
- **In-App Lifecycle Gate**: Validates status == COMPLETE, elapsedMeasureMs within 10% tolerance, and workloadVersion == 1.0.0.
- **Exact Target Layer Extraction**: SurfaceFlinger timestats resolves com.tabletdroid.benchmark/...#<id>, dynamically choosing highest active instance.
- **Telemetry Decoupling Policy**: Production performance benchmarks run with Telemetry OFF to prevent host threadpool observer skew.

---

## 3. [INFERENCE] Findings & Conclusions
### 3.1 Canonical Workload Evaluation (Telemetry OFF)
- **Presented FPS**: **12.46 FPS** (StdDev: 0.94, CV: 7.3%)
- **Workload Distance**: **24200 px** (CV: 0.4%)
- **Frame Latency**: P50 = **166.43 ms**, P90 = **353.56 ms**, Jank = **100%**

> **Conclusion**: Workload determinism is strictly verified (Distance CV = 0.4% <= 10%).

---

## 4. [DECISION] Next Phase Execution
- All architectural decisions require passing all 8 validation gates.
- Proceed to ASG and host compositor transport analysis with verified deterministic probe.
