# TabletDroid v0.1 Benchmark Correctness & Canonical Workload Validation Report

- **Timestamp**: 2026-08-20 04:16:00
- **Host Hardware**: ASUS ROG Flow Z13 (Intel Core i9-12900H, NVIDIA GeForce RTX 3050 Ti Laptop GPU, 16GB RAM)
- **Host Operating System**: Windows 11 Home 23H2
- **Hypervisor**: Windows Hypervisor Platform (WHPX) Acceleration Active
- **Target Guest OS**: Android 14.0 (Google Play x86_64, API Level 34)
- **Resolution Tested**: 1920x1200 @ 280dpi (Native Tablet Viewport)
- **Canonical Benchmark Probe**: `com.tabletdroid.benchmark/.BenchmarkActivity`

---

## 1. [IMPLEMENTED] Canonical Workload Architecture & Correctness Guardrails

### 1.1 In-Guest Deterministic Benchmark Application (`TabletDroid.Benchmark`)
- **Package**: `com.tabletdroid.benchmark`
- **Location**: `android/guest/TabletDroid.Benchmark/`
- **Workload Structure**: 100 fixed structured UI cards featuring rounded card backgrounds, elevation shadows, gradient hero banners, colored oval avatars, category chips, and multi-line typography.
- **Zero-External Dependencies & Determinism**:
  - No network connectivity or external HTTP requests.
  - Zero randomized data generation; deterministic color and card sequence.
  - No user-input dependency or `adb shell input swipe` commands.
- **In-App Auto-Scroll Motion Engine**:
  - Driven by Android `Choreographer.FrameCallback` for sub-pixel smooth scrolling at a strictly controlled velocity ($800\text{ px/s}$).
  - Automatic direction inversion at scroll boundaries.
- **Broadcast Protocol Interface**:
  - `com.tabletdroid.benchmark.ACTION_START`: Accepts `--ei warmup_sec`, `--ei measure_sec`, `--ef velocity_px_s`.
  - `com.tabletdroid.benchmark.ACTION_RESET`: Resets scroll offset, timing accumulators, and distance metrics.
  - Emits JSON structured status to Logcat (`BENCHMARK_STATUS_JSON`) containing actual scroll distance, elapsed measurement milliseconds, and frame counts.

### 1.2 Fail-Closed Automated Harness (`scripts/windows/benchmark-spike.ps1`)
- **No-Fallback Policy**: If `com.tabletdroid.benchmark` is not verified on the target device, the harness fails immediately (`FAIL FAST`). Automatic fallback to Chrome or Settings is completely eliminated.
- **Exact Target Layer Resolution**: SurfaceFlinger timestats dumps are parsed specifically for `com.tabletdroid.benchmark/com.tabletdroid.benchmark.BenchmarkActivity#<id>`, dynamically resolving the latest active layer ID and ignoring dead historical layers and splash screens.
- **Decoupled Out-of-Process Runspace Telemetry**: CPU and Windows Performance Counter GPU metrics (`\GPU Engine(*)\Utilization Percentage`) are sampled asynchronously in a dedicated PowerShell Runspace using synchronized memory buffers.

---

## 2. [MEASURED] Empirical Characterization Matrix

### 2.1 Canonical 5-Trial Baseline (30-second Measurement Phase)
| Metric | Median | Min | Max | StdDev | CV (%) |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **SurfaceFlinger Presented FPS** | **15.43 FPS** | 14.39 | 16.66 | 0.85 | **5.5%** |
| **Actual Scroll Distance** | **23,147 px** | 23,000 | 23,573 | 215 px | **0.9%** |
| **HWUI P50 Frame Latency** | **174.32 ms** | 108.11 | 180.64 | - | - |
| **HWUI P90 Frame Latency** | **253.59 ms** | 187.40 | 306.59 | - | - |
| **Host QEMU CPU Load** | **16.7%** | 16.5% | 17.3% | - | - |
| **Host RTX 3050 Ti GPU 3D Load**| **3.5%** | 2.5% | 4.1% | - | - |

> **Validation Outcome**: The canonical workload demonstrated exceptional determinism with a scroll distance coefficient of variation (CV) of **0.9%** and a presentation FPS CV of **5.5%**.

### 2.2 Telemetry Observer Effect Evaluation (4 Conditions x 5 Trials)
| Condition | Median Presented FPS | FPS CV% | Actual Distance | Distance CV% | P50 Latency (ms) |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **A. No Telemetry (Pure Workload)** | **23.67 FPS** | 19.5% | 8,000 px | 1.7% | 98.48 ms |
| **B. CPU Telemetry Only** | **7.69 FPS** | 8.0% | 5,187 px | 9.5% | 383.17 ms |
| **C. GPU Telemetry Only** | **5.19 FPS** | 1.6% | 3,440 px | 3.0% | 483.69 ms |
| **D. CPU + GPU Telemetry** | **18.59 FPS** | 14.3% | 7,933 px | 5.2% | 162.13 ms |

> **Validation Outcome**: Heavy continuous synchronous Windows counter polling introduces noticeable host CPU/GPU contention. Telemetry sampling in production benchmarks is now decoupled into low-frequency asynchronous background intervals.

### 2.3 GPU HWUI Renderer Comparison (Skia OpenGL vs Skia Vulkan)
| HWUI Backend | Median Presented FPS | Min | Max | Distance (px) | P50 Latency (ms) |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Skia OpenGL (`skiagl`)** | **5.89 FPS** | 4.20 | 18.86 | 3,746 px | 487.98 ms |
| **Skia Vulkan (`skiavk`)** | **17.39 FPS** | 15.78 | 18.49 | 7,933 px | 170.95 ms |

> **Validation Outcome**: Under the canonical deterministic workload, **Skia Vulkan outperforms Skia OpenGL by +11.5 FPS** (17.39 vs 5.89 FPS), cutting P50 frame latency from 487.98 ms down to 170.95 ms.

---

## 3. [DECISION] Architectural & Benchmarking Standards

1. **Standardization of Benchmark Probe**:
   - `com.tabletdroid.benchmark/.BenchmarkActivity` is formally designated as the single canonical workload for all TabletDroid v0.1 rendering and transport investigations.
   - All historical benchmarks based on external apps (`com.instagram.android`, Google Chrome, Android Settings) are archived as non-canonical.
2. **Standardization of Fail-Closed Protocol**:
   - Any trial failing package verification, target layer discovery, gfxinfo acquisition, or distance cadence limits ($\pm 10\%$) is strictly discarded as `INVALID`.
3. **Default HWUI Backend**:
   - Skia Vulkan (`debug.hwui.renderer=skiavk`) is confirmed as the standard guest rendering backend for Android 14 AVD environments.

---

## 4. [OPEN] Residual Architectural Hypotheses

1. **ASG (Address Space Graphics) Transport Ring Buffer Bottleneck [OPEN / HYPOTHESIS]**:
   - The host GPU 3D utilization remains low ($< 5\%$) even when guest UI frame latency exceeds 100 ms.
   - Hypothesis: The virtualized PCI transport / shared memory command ring buffer between guest libOpenglRender and host emulator processes throttles command throughput.
2. **Host Presentation & Window Embedding Pipeline [OPEN / HYPOTHESIS]**:
   - Direct DXGI shared texture presentation path vs Win32 SetParent hosting.
