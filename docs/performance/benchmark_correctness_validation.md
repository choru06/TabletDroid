# TabletDroid v0.1 Benchmark Correctness & Canonical Workload Validation Report

- **Timestamp**: 2026-08-20 04:31:00
- **Host Hardware**: ASUS ROG Flow Z13 (Intel Core i9-12900H, NVIDIA GeForce RTX 3050 Ti Laptop GPU, 16GB RAM)
- **Host Operating System**: Windows 11 Home 23H2
- **Hypervisor**: Windows Hypervisor Platform (WHPX) Acceleration Active
- **Target Guest OS**: Android 14.0 (Google Play x86_64, API Level 34)
- **Resolution Tested**: 1920x1200 @ 280dpi (Native Tablet Viewport)
- **Canonical Benchmark Probe**: `com.tabletdroid.benchmark/.BenchmarkActivity`

---

## 1. [IMPLEMENTED] Canonical Workload Architecture & Fail-Closed Validity Gates

### 1.1 In-Guest Deterministic Benchmark Application (`TabletDroid.Benchmark`)
- **Package**: `com.tabletdroid.benchmark` (`BenchmarkActivity`)
- **Location**: `android/guest/TabletDroid.Benchmark/`
- **Workload Structure**: 100 fixed structured UI cards featuring rounded card backgrounds, elevation shadows, gradient hero banners, colored oval avatars, category chips, and multi-line typography.
- **Strict Determinism**: Zero network calls, zero randomized data structures, and zero external asset dependencies.
- **In-App Auto-Scroll Motion Engine**: Driven by Android `Choreographer.FrameCallback` executing sub-pixel smooth scrolling at constant velocity ($800\text{ px/s}$) with exact boundary reflection math, ensuring total distance moved is strictly $V \times T$ regardless of frame rate.
- **Broadcast Protocol Interface**: `ACTION_START` (with `--ei warmup_sec`, `--ei measure_sec`, `--ef velocity_px_s`), `ACTION_RESET`, and `BENCHMARK_STATUS_JSON` emission to Logcat.

### 1.2 8-Point Fail-Closed Validation Matrix
Every trial and experimental series must satisfy all 8 validity gates; any breach flags the trial as `INVALID` or the series as `INCONCLUSIVE`:

| Gate # | Validation Gate | Rule / Condition | Status |
| :---: | :--- | :--- | :---: |
| **G1** | **Target App Verification** | `pm path com.tabletdroid.benchmark` verified (No fallback) | **PASS** |
| **G2** | **Workload Version** | `workloadVersion == "1.0.0"` in Logcat status | **PASS** |
| **G3** | **Workload Lifecycle State**| In-app status == `COMPLETE` | **PASS** |
| **G4** | **Measurement Duration** | `elapsedMeasureMs` within $\pm 10\%$ of requested time | **PASS** |
| **G5** | **Distance Error Gate** | $\vert \text{ActualDistance} - \text{ExpectedDistance} \vert / \text{ExpectedDistance} \le 10\%$ | **PASS** |
| **G6** | **Target SF Active Layer** | SurfaceFlinger resolves latest active `#<id>` layer | **PASS** |
| **G7** | **Gfxinfo Framestats** | `dumpsys gfxinfo framestats` records $> 0$ | **PASS** |
| **G8** | **5-Trial Distance CV** | Workload distance coefficient of variation $< 10\%$ | **PASS** |

### 1.3 Telemetry Observer Decoupling Policy
- **Primary Performance Runs**: Executed with Telemetry OFF (`enableCpu=$false`, `enableGpu=$false`) to completely prevent host threadpool and performance counter polling observer skew.
- **Diagnostic Runs**: Executed separately with Telemetry ON solely to inspect CPU/GPU resource allocation patterns.

---

## 2. [MEASURED] Empirical Characterization Matrix

### 2.1 Canonical 5-Trial Baseline (Telemetry OFF, 30s Measurement Phase)
- **Report Document**: [`docs/performance/canonical_benchmark_workload.md`](canonical_benchmark_workload.md)

| Metric | Median | Min | Max | StdDev | CV (%) | Status |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **SurfaceFlinger Presented FPS** | **12.46 FPS** | 11.57 | 14.23 | 0.94 | **7.3%** | **PASS** |
| **Actual Scroll Distance** | **24,200 px** | 24,186 | 24,413 | 97 px | **0.4%** | **PASS (0.4% CV)** |
| **HWUI P50 Frame Latency** | **166.43 ms** | 131.23 | 212.90 | - | - | **PASS** |
| **HWUI P90 Frame Latency** | **353.56 ms** | 159.55 | 808.20 | - | - | **PASS** |
| **Workload Validity Gates** | **5 / 5 Trials Valid** | - | - | - | - | **PASS** |

### 2.2 Corrected GPU HWUI Renderer Comparison (Telemetry OFF, 5 Trials Each)
- **Report Document**: [`docs/performance/gpu_backend_comparison.md`](gpu_backend_comparison.md)

> [!NOTE]
> **CORRECTION / SUPERSEDED RECORD**: The initial OpenGL vs Vulkan benchmark in commit `1ed463f` had distance cadence drift in OpenGL (CV: 43.5%). That initial comparison has been invalidated and replaced by this strictly gated evaluation.

| HWUI Backend | Valid Trials | Median Presented FPS | FPS Range | Actual Distance | Distance CV% | P50 Latency | Gate Status |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Skia OpenGL (`skiagl`)** | **5 / 5** | **11.70 FPS** | [8.29, 16.98] | **8,133 px** | **0.9%** | 211.25 ms | **PASS** |
| **Skia Vulkan (`skiavk`)** | **5 / 5** | **10.00 FPS** | [6.89, 12.48] | **8,134 px** | **0.6%** | 238.61 ms | **PASS** |
| **Delta (Vulkan - OpenGL)** | - | **-1.70 FPS** | - | **+1 px** | - | **+27.36 ms** | **no meaningful difference** |

> **Validation Outcome**: When both backends execute with verified deterministic distance ($8,133\text{ px}$ vs $8,134\text{ px}$, $\text{CV} < 1\%$), there is **no meaningful difference** ($\le 1.7\text{ FPS}$) between Skia OpenGL and Skia Vulkan. Neither guest graphics API backend is the root cause of the ~12-15 FPS limit.

### 2.3 Diagnostic Telemetry Profile (Reference Only)
- **QEMU Host CPU Load**: ~17.7%
- **RTX 3050 Ti Host GPU 3D Load**: ~4.5%

---

## 3. [DECISION] Architectural Decisions

1. **Standardization of Benchmark Probe**: `com.tabletdroid.benchmark/.BenchmarkActivity` is the single canonical probe.
2. **Measurement Separation**: Telemetry OFF is the mandatory standard for all performance headline numbers; Telemetry ON is reserved for diagnostic isolation.
3. **HWUI Neutrality**: HWUI backend selection (OpenGL vs Vulkan) does not resolve the bottleneck. The default remains Skia Vulkan (`debug.hwui.renderer=skiavk`).
4. **ASG Readiness**: All 8 validation gates are verified and passing. The measurement framework is locked. Proceed directly to **ASG Transport & Host Compositor A/B experiments**.

---

## 4. [OPEN] Residual Architectural Hypotheses

1. **ASG Transport Ring Buffer Protocol**: Host-guest PCI/IPC command serialization bottlenecks.
2. **Host Presenter Pipeline**: D3D11 / ANGLE swapchain copy overhead in host window presentation.
