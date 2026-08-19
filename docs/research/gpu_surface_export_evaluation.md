# Technical Research: External GPU Surface Path & Embedding for TabletDroid Host

- **Ticket**: `research: validate external GPU surface path for TabletDroid Host`
- **Date**: 2026-08-20
- **Target Platform**: Windows 11 / ASUS ROG Flow Z13 (NVIDIA GeForce RTX 3050 Ti Laptop GPU)
- **Primary Objective**: Determine the optimal, zero-copy display integration architecture between Stock Android Emulator and TabletDroid Host (.NET 9 / WPF / WinUI).

---

## 1. Executive Summary & Architectural Evaluation

| Approach | Feasibility | Frame Latency / Throughput | Implementation Complexity | Recommendation |
| :--- | :---: | :---: | :---: | :---: |
| **Option A: DXGI Shared Handle via Stock Emulator** | **Low** | Zero-Copy (~120 FPS) | Very High (No public API in stock Google binary) | Reject (Stock binary lack export API) |
| **Option B: Win32 Zero-Copy Window Embedding (`SetParent` + `HwndHost`)** | **High** | **Native Zero-Copy (60~120 FPS)** | **Low / Robust (Win32 Native)** | **Adopt (Primary Recommended Architecture)** |
| **Option C: Custom AOSP Emulator Source Fork** | **Medium** | Zero-Copy (~120 FPS) | Prohibitive (Massive build & maintenance overhead) | Reject for v0.1 |
| **Option D: Emulator gRPC / WebRTC Stream** | **High** | Compressed (~30-60 FPS, Encode Lag) | Medium | Fallback for remote/headless scenarios only |

---

## 2. Detailed Technical Findings

### 2.1 Option A: Direct DXGI D3D11 Shared Handle Export in Stock Emulator
* **Investigation**: Analyzed Google Android SDK Emulator v37.1.11.0 binary export table and graphics architecture (`gfxstream_backend.dll`, `libOpenglRender.dll`, `qemu-system-x86_64.exe`).
* **Result**:
  * Stock Google emulator does **not** expose a public C/COM API to export `ID3D11Texture2D` shared handles (`IDXGIResource::GetSharedHandle`) to external arbitrary Win32 processes.
  * Internal surface textures are bound directly to the Emulator's native swapchain window (`qemu_desktop_window`).

### 2.2 Option B: Native Win32 Window Embedding (`SetParent` + Style Stripping)
* **Mechanism**:
  1. TabletDroid Host launches emulator with `-no-skin -gpu host`.
  2. Host identifies the HWND of `qemu-system-x86_64.exe` (Window Class `SDL_app` or `Qt5152QWindowIcon`).
  3. Modifies window styles: strips `WS_POPUP`, `WS_CAPTION`, `WS_THICKFRAME`, `WS_MINIMIZEBOX`, `WS_MAXIMIZEBOX` and applies `WS_CHILD | WS_VISIBLE`.
  4. Calls `SetParent(emulatorHwnd, hostContainerHwnd)`.
  5. Resizes child HWND to exactly match Host Viewport.
* **Performance Characteristics**:
  * **Zero-Copy**: The GPU (NVIDIA RTX 3050 Ti) presents directly to the DWM swapchain surface without copying pixels over CPU IPC pipes.
  * **Framerate**: Full native 60~120 FPS capability with zero CPU encoding/decoding overhead.
  * **Clean UI**: Completely removes Google emulator toolbars, titlebars, and window borders, seamlessly integrating into TabletDroid Host.

---

## 3. Decision & v0.1 Implementation Plan

1. **Adopt Option B (Win32 Zero-Copy Window Embedding)** as the core display engine for TabletDroid v0.1.
2. Implement `IWindowEmbedderService` in `TabletDroid.Bridge.Window`:
   * Automatic HWND discovery for QEMU/Emulator process.
   * Atomic style stripping and `SetParent` parenting.
   * DPI-aware viewport synchronization on window resize and display orientation change.
