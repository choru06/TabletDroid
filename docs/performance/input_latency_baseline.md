# TabletDroid Canonical Software Input-to-Frame Latency Baseline Report (Final Provenance Verified)

> [!WARNING]
> **Measurement Scope & Boundary**:
> This document establishes the **Guest Synthetic Software Input-to-Frame Baseline** for TabletDroid. It strictly measures the guest software pipeline:
> $$\text{MotionEvent Injection} \longrightarrow \text{App Event Dispatch} \longrightarrow \text{Choreographer VSYNC Tick} \longrightarrow \text{Callback Execution} \longrightarrow \text{onDraw Start} \longrightarrow \text{onDraw Content End}$$
>
> **It is NOT a physical touch-to-photon measurement** and does not capture host hardware digitizer scanning delays, Windows HID stack routing, or optical display scanout time.

---

## 1. Purpose

The purpose of this benchmark is to provide a **rigorous, methodologically hardened, provenance-verified, and repeatable canonical measurement** of software input latency in TabletDroid on the 120Hz production stack, and to determine whether **Win32 `SetParent` child-window embedding** introduces measurable software latency regression compared to standalone emulator execution when experimental order bias, warm-state effects, embedding status, and source tree provenance are strictly verified under fatal gates.

---

## 2. Measurement Definition & Schema v3 Architecture

### Pipeline Breakdown

```text
MotionEvent Event Time (eventUptime, CLOCK_MONOTONIC ms)
        │
        ▼  [eventToDispatchMs] = receiveUptime - eventUptime
App onTouchEvent Receive (receiveUptime ms, receiveNano ns)
        │
        ▼  [dispatchToVsyncMs] = (choreographerFrameNano - receiveNano)
Choreographer VSYNC Frame Timestamp (choreographerFrameNano ns)
        │
        ▼  [vsyncToCallbackMs] = (choreographerCallbackNano - choreographerFrameNano)
Choreographer Callback Actual Execution (choreographerCallbackNano ns)
        │
        ▼  [callbackToDrawStartMs] = (drawStartNano - choreographerCallbackNano)
View Canvas onDraw Entry (drawStartNano ns)
        │
        ▼  [drawContentDurationMs] = (drawContentEndNano - drawStartNano)
View Canvas onDraw Workload Exit (drawContentEndNano ns)
        │
        ▼  [eventToDrawStartMs] = eventToDispatchMs + (drawStartNano - receiveNano)
Total Software Event-to-Draw Delivery
```

### Schema v3 Key Specifications
1. **Choreographer VSYNC Time vs Callback Execution**: `choreographerFrameNano` represents the VSYNC frame timestamp, while `choreographerCallbackNano` captures actual `doFrame()` callback execution in monotonic nanoseconds.
2. **`onDraw` Entry vs Workload Exit**: `drawStartNano` captures traversal entry into `onDraw()`. `drawContentEndNano` captures the completion of the canonical drawing commands before metric formatting/logging. `drawContentDurationMs` ($< 0.02\text{ ms}$) strictly measures drawing workload duration, not literal Java method exit.
3. **Batching & Coalescing Visibility**: `frameSequenceId` and `eventsInFrame` record multi-event batching during rapid continuous drags.
4. **Zero-Clamping Elimination**: Negative or inverted timestamps are not clamped to `0.0 ms`; they are marked with `valid = false` and an explicit `invalidReason`.

---

## 3. What This Benchmark Does NOT Measure

1. **Physical Digitizer-to-Photon Delay**: Hardware touch digitizer scanning rate (120Hz/240Hz), HID report descriptors, and panel liquid crystal response/scanout are not captured.
2. **Host OS Windows Touch Routing**: Synthetic injection via ADB (`adb shell input ...`) delivers events directly to Android's `InputManagerService`, bypassing Windows `WM_POINTER` message queues.
3. **End-to-End Glass Latency**: This benchmark evaluates software runtime overhead only.

---

## 4. Hardware / Software Environment (Provenance & Readback Verified)

The following system fingerprint was dynamically queried, read back post-boot, and verified from a clean Git source tree:

| Parameter | Readback Value | Verification Status |
| :--- | :--- | :---: |
| **Source Git Commit** | `f032cc5b8aa55d3b2f12ea65e3ddcfa81bf0fc5e` | **PASS (Clean Tree Verified)** |
| **Source Tree Dirty at Start** | `false` (`CanonicalSourceTree = true`) | **PASS (Pre-Run Enforced)** |
| **Host System** | ASUS ROG Flow Z13 (GZ301ZE) | **VERIFIED** |
| **Host OS** | Microsoft Windows 11 Home Insider Preview (Build 10.0.26340) | **VERIFIED** |
| **CPU** | 12th Gen Intel(R) Core(TM) i9-12900H (14 Cores, 20 Logical Processors) | **VERIFIED** |
| **Host Memory** | 15.7 GB LPDDR5 | **VERIFIED** |
| **Host GPUs** | Intel(R) Iris(R) Xe Graphics, NVIDIA GeForce RTX 3050 Ti Laptop GPU | **VERIFIED** |
| **Emulator Version** | `Android emulator version 37.1.11.0 (build_id 15917651)` | **PASS (Direct Binary Readback)** |
| **ADB Version** | `Android Debug Bridge version 1.0.41` | **VERIFIED** |
| **AVD Config `hw.gpu.mode`** | `host` (`gfxstream`) | **PASS (config.ini Readback)** |
| **AVD Config `hw.gltransport`** | `pipe` | **PASS (config.ini Readback)** |
| **AVD Config `hw.lcd.vsync`** | `120` | **PASS (config.ini Readback)** |
| **Guest Build Fingerprint** | `google/sdk_gphone64_x86_64/emu64xa:14/UE1A.230829.036.A4/12096271:user/release-keys` | **PASS (Non-Empty)** |
| **Guest OS Version** | Android 14 (Release 14, API Level 34) | **VERIFIED** |
| **Display Geometry** | `Physical size: 1920x1200 @ 280 dpi` | **PASS (Post-Boot Readback)** |
| **Refresh Rate Policy** | `peak_refresh_rate = 120.0`, `min_refresh_rate = 120.0` | **PASS (120Hz Fail-Closed Checked)** |
| **Emulator VSYNC Prop** | `ro.boot.qemu.vsync = 120` | **PASS (120Hz Synced)** |
| **Hypervisor** | Windows Hypervisor Platform (WHPX, `-accel on`) | **VERIFIED** |
| **Host Embedding** | Win32 `SetParent` Child Window Embedding | **VERIFIED (Fatal Gate)** |

---

## 5. Counter-Balanced Experimental Design & Fatal Verification Gates

To eliminate order bias and warm-state contamination, the benchmark executes a **6-trial counter-balanced alternating design**:

```text
Trial 1: Standalone ──> Embedded (Fatal Embedding Verification Gate)
Trial 2: Embedded   ──> Standalone (Fatal Embedding Verification Gate)
Trial 3: Standalone ──> Embedded (Fatal Embedding Verification Gate)
Trial 4: Embedded   ──> Standalone (Fatal Embedding Verification Gate)
Trial 5: Standalone ──> Embedded (Fatal Embedding Verification Gate)
Trial 6: Embedded   ──> Standalone (Fatal Embedding Verification Gate)
```

### Deterministic Invariant Reset
Before executing each condition in every trial, the harness enforces:
1. `adb shell am force-stop com.tabletdroid.benchmark`
2. `adb shell am start -n com.tabletdroid.benchmark/.InputProbeActivity --ez canonical_mode true`
3. 1,500 ms stabilization interval
4. `adb logcat -c` (logcat purge)
5. Standardized synthetic workload injection

### Per-Trial Fatal Embedding Verification Gate
Before each embedded condition run, host IPC is polled for `GET_GEOMETRY`. Embedding is accepted only if `isEmbedded == true`, `embeddedHwnd` is valid, and viewport dimensions $> 0$. If unverified within timeout, the run terminates immediately with a fatal exception.

---

## 6. Workload & Event Integrity Accounting

Each condition per trial executes 70 discrete gestures (50 Taps, 10 continuous 400ms Drags, 10 rapid 150ms Swipes).

### Event Integrity Accounting (Across 6 Clean-Tree Trials)

| Accounting Metric | Standalone (6 Trials) | Embedded (6 Trials) | Accounting Status |
| :--- | :---: | :---: | :---: |
| **Embedding Verification Gate** | N/A (Standalone) | **6 / 6 Trials Verified (100%)** | **PASS (`HWND=0x46050C`, `1566x760`)** |
| **Expected `ACTION_DOWN` Gestures** | 420 (70 × 6) | 420 (70 × 6) | **100% Accounted** |
| **Observed `ACTION_DOWN` Events** | 420 | 420 | **0 Missing (100% Match)** |
| **Expected `ACTION_UP` Gestures** | 420 (70 × 6) | 420 (70 × 6) | **100% Accounted** |
| **Observed `ACTION_UP` Events** | 420 | 420 | **0 Missing (100% Match)** |
| **Total `ACTION_MOVE` Events** | 3,903 | 3,908 | **Normal Batching Stream** |
| **Total Valid Records** | **4,743** | **4,748** | **$\ge 100$ Target Met (9,491 Total)** |
| **Invalid JSON / Timestamp Records** | **0** | **0** | **0 Rejections (100% Valid)** |

---

## 7. Clean-Tree Canonical Results (6-Trial Counter-Balanced, $N=9,491$)

- **Session Timestamp**: `20260823-230134`
- **Total Valid Events Evaluated**: **9,491 records**

### 7.1 Across-Trial Distribution (Medians across 6 Trials)

| Pipeline Metric | Standalone (Median) | Embedded (Median) | Delta (ms) | Delta (%) | Gate Status |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **DOWN Event $\rightarrow$ Dispatch P50** | 1.000 ms | 1.000 ms | **+0.000 ms** | **+0.0%** | **PASS** |
| **DOWN Event $\rightarrow$ Dispatch P95** | 1.000 ms | 1.000 ms | **+0.000 ms** | **+0.0%** | **PASS** |
| **DOWN Dispatch $\rightarrow$ Callback P50** | 5.958 ms | 5.288 ms | **-0.670 ms** | **-11.25%** | **PASS** |
| **DOWN Draw Content Duration P50** | 0.008 ms | 0.008 ms | **+0.000 ms** | **+0.0%** | **PASS (< 0.02 ms)** |
| **DOWN Event $\rightarrow$ DrawStart P50** | **6.958 ms** | **6.141 ms** | **-0.817 ms** | **-11.74%** | **PASS** |
| **DOWN Event $\rightarrow$ DrawStart P95** | **10.361 ms** | **10.568 ms** | **+0.207 ms** | **+2.00%** | **PASS** |
| **DOWN Event $\rightarrow$ DrawStart P99** | **11.776 ms** | **11.346 ms** | **-0.430 ms** | **-3.65%** | **PASS** |
| **MOVE Event $\rightarrow$ DrawStart P50** | **6.388 ms** | **6.332 ms** | **-0.056 ms** | **-0.88%** | **PASS** |
| **MOVE Event $\rightarrow$ DrawStart P95** | **8.426 ms** | **8.411 ms** | **-0.015 ms** | **-0.18%** | **PASS** |
| **MOVE Event $\rightarrow$ DrawStart P99** | **11.668 ms** | **10.860 ms** | **-0.808 ms** | **-6.92%** | **PASS** |

### 7.2 Pooled Distribution (All 9,491 Raw Events Combined)

| Metric | Standalone (Pooled) | Embedded (Pooled) | Delta (ms) | Delta (%) |
| :--- | :---: | :---: | :---: | :---: |
| **Pooled DOWN P50** | 6.818 ms | 6.086 ms | **-0.732 ms** | **-10.74%** |
| **Pooled DOWN P95** | 10.465 ms | 10.753 ms | **+0.288 ms** | **+2.75%** |
| **Pooled DOWN P99** | 11.865 ms | 11.437 ms | **-0.428 ms** | **-3.61%** |
| **Pooled MOVE P50** | 6.373 ms | 6.328 ms | **-0.045 ms** | **-0.71%** |
| **Pooled MOVE P95** | 8.486 ms | 8.443 ms | **-0.043 ms** | **-0.51%** |
| **Pooled MOVE P99** | 11.448 ms | 11.230 ms | **-0.218 ms** | **-1.90%** |

---

## 8. Order Effect Analysis

Comparing runs executed first in a trial against runs executed second in a trial:

| Condition | First-Run Mean P50 | Second-Run Mean P50 | Order Delta | Interpretation |
| :--- | :---: | :---: | :---: | :--- |
| **Standalone Emulator** | 6.632 ms | 6.995 ms | **+0.363 ms** | State reset completely eliminated warm-start disparity ($\Delta < 0.4\text{ ms}$) |
| **Host Embedded (`SetParent`)** | 5.915 ms | 6.276 ms | **+0.361 ms** | Host embedded runs remain completely stable ($\Delta < 0.4\text{ ms}$) |

---

## 9. Dynamic Acceptance Verification Matrix (`acceptance.json` Verified)

All acceptance criteria are computed dynamically without hardcoding:

| Acceptance Gate | Evaluated Property | Result | Status |
| :--- | :--- | :---: | :---: |
| **1. Source Tree Cleanliness** | Pre-run `git status --porcelain` is empty | `true` | **PASS** |
| **2. Source Commit Identity** | `f032cc5b8aa55d3b2f12ea65e3ddcfa81bf0fc5e` (40 chars) | `true` | **PASS** |
| **3. Guest Build Fingerprint** | `google/sdk_gphone64_x86_64/...` verified non-empty | `true` | **PASS** |
| **4. Display Resolution & Density** | `1920x1200 @ 280 dpi` post-boot readback | `true` | **PASS** |
| **5. 120Hz Refresh Policy** | `peak=120.0`, `min=120.0`, `ro.boot.qemu.vsync=120` | `true` | **PASS** |
| **6. Graphics & Transport** | `hw.gpu.mode=host`, `hw.gltransport=pipe` (config.ini) | `true` | **PASS** |
| **7. Fatal Embedding Gate** | 6 / 6 Embedded trials verified `isEmbedded = true` | `6 / 6` | **PASS** |
| **8. Host Solution Build** | `dotnet build TabletDroid.slnx` passed (0 Errors) | `true` | **PASS** |
| **9. TRX Unit Test Suite** | 19 / 19 unit tests passed (XML counter verified) | `19 / 19` | **PASS** |
| **10. Event Stream Integrity** | 0 missing DOWN/UP, 0 invalid timestamps, 0 invalid JSON | `true` (0 Rejections) | **PASS** |
| **CANONICAL RESULT** | **Logical AND of Gates 1 through 10** | **PASS** | **CLOSED** |

---

## 10. Architectural Decision & Baseline Closure

### Decision: **GUEST SYNTHETIC INPUT-TO-FRAME BASELINE CLOSED (CASE A CONFIRMED)**

```text
Measured Outcome:
Across-Trial DOWN P50 : Standalone 6.958 ms vs Embedded 6.141 ms (Delta = -0.817 ms)
Across-Trial MOVE P50 : Standalone 6.388 ms vs Embedded 6.332 ms (Delta = -0.056 ms)
```

- **No meaningful regression was observed in the Android guest software input-to-draw pipeline while the emulator window was embedded through Win32 SetParent under synthetic ADB input.**
- The observed differences remained below the predefined practical regression threshold ($\pm 1.0\text{ ms}$ / sub-frame variance at 120Hz).
- **The Guest Synthetic Input-to-Frame benchmark is officially CLOSED.**
- Next milestone proceeds directly to **Physical Windows Input Routing Characterization** (`WM_POINTER` / `WM_TOUCH` delivery latency).

---

## 11. Historical Baseline Archive

### Baseline v2 (`artifacts/input-latency/20260823-211204/`)
- Single fixed Standalone $\rightarrow$ Embedded run.
- Superseded due to order bias.

### Baseline v3 Initial Hardening (`artifacts/input-latency/20260823-212910/`)
- 6-trial counter-balanced run. Superseded by fatal embedding gate candidate.

### Baseline v3 Final Integrity Candidate (`artifacts/input-latency/20260823-223035/`)
- Fatal embedding verified 6-trial run. Clean tree verification polluted by benchmark artifact generation.

---

## 12. Final Raw Artifact References (Clean-Tree Run)

All raw event streams, per-trial summaries, build verification, and synthesis CSVs are permanently preserved in:
- `artifacts/input-latency/20260823-230134/acceptance.json`
- `artifacts/input-latency/20260823-230134/build-verification.json`
- `artifacts/input-latency/20260823-230134/environment.json`
- `artifacts/input-latency/20260823-230134/methodology.json`
- `artifacts/input-latency/20260823-230134/trial-01/` .. `trial-06/`
- `artifacts/input-latency/20260823-230134/trial-summary.csv`
- `artifacts/input-latency/20260823-230134/condition-summary.json`
- `artifacts/input-latency/20260823-230134/comparison.csv`
- `artifacts/input-latency/20260823-230134/order-effect.csv`
