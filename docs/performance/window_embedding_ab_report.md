# TabletDroid v0.1 Win32 Window Embedding A/B Benchmark Report

- **Timestamp**: 2026-08-20 00:34:44
- **Host Hardware**: ASUS ROG Flow Z13 (Intel Core i9-12900H, NVIDIA GeForce RTX 3050 Ti Laptop GPU, 16GB RAM)
- **WHPX Accelerator**: Active & Operational
- **Target App**: com.instagram.android
- **Emulator Serial**: emulator-5554
- **Benchmark Mode**: Standalone (Trials per condition: 1)

---

## 1. [MEASURED] Frame & Host Telemetry Summary

| Test Scenario | Mode | Avg FPS | Avg FrameTime | P50 (ms) | P90 (ms) | P99 (ms) | Jank % | QEMU CPU | QEMU RAM | GPU 3D | GPU Copy | Frames |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **1920x1200 (2.30M (100%))** | **Standalone** | **23.3** | 42.86 ms | 49.03 ms | 68.43 ms | 85.24 ms | 100% | 13.8% | 1585.2 MB | 0% | 0% | 120 |
| **1280x800 (1.02M (44%))** | **Standalone** | **4** | 246.92 ms | 259.38 ms | 259.38 ms | 259.38 ms | 100% | 7.5% | 1614.8 MB | 0% | 0% | 2 |

---

## 2. [IMPLEMENTED] Window Embedding Spike Details
- Implemented IWindowEmbedderService and Win32WindowEmbedderService in TabletDroid.Bridge.Window.
- Implemented dynamic HWND search for qemu-system-x86_64 / emulator rendering child windows.
- Applied Win32 SetParent + Style-stripping (WS_POPUP, WS_CAPTION, WS_THICKFRAME) to embed into Host viewport.
- Added automated detachment / state restoration on shutdown or test completion.

---

## 3. [INFERENCE] A/B Hypothesis Evaluation


---

## 4. [OPEN] Residual Questions & Blockers
1. **Guest Graphics Path**: Is gfxstream OpenGL-to-ANGLE Direct3D11 translation vs ANGLE Vulkan translation the primary bottleneck?
2. **Touch Routing in Embedded Mode**: Does Win32 SetParent preserve multi-touch gestures directly from Windows Touch to guest pointer events, or does it require explicit WM_TOUCH forwarding?

---

## 5. [DECISION] Architectural Next Steps
- Keep IWindowEmbedderService for seamless Host UI encapsulation.
- Investigate internal emulator GPU backends (-gpu host vs -gpu angle_indirect vs -gpu vulkan) to target the real 1920x1200 rendering bottleneck.
