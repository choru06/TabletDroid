# TabletDroid Fixed 120Hz Feasibility & VSYNC Property-Path Mismatch Analysis

- **Date / Timestamp**: 2026-08-23 18:00:28
- **Target Hardware**: ASUS ROG Flow Z13 (Intel Core i9-12900H, NVIDIA GeForce RTX 3050 Ti Laptop GPU, 16GB RAM)
- **Target OS**: Windows 11 Home 23H2 (Hypervisor: WHPX)
- **Host Physical Panel**: 1920x1200 @ 120 Hz
- **Target AVD Configuration**: `hw.lcd.vsync = 120`, `hw.gpu.mode = host`, `hw.gltransport = pipe`, `-no-snapshot`, `-no-snapshot-save`

---

## 1. Executive Summary & Experimental Conditions Matrix

| Condition | `ro.boot.qemu.vsync` | `ro.kernel.qemu.vsync` | `qemu.vsync` | DisplayManager | App Refresh | App Mode | SF Refresh | Choreographer | Evaluation |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Control A: Standard Cold Boot** | `120` | `N/A` | `N/A` | 120 Hz | 60 Hz | 120 Hz | 60 Hz | **60.0 FPS** | **~60 FPS Capped** |
| **Condition B1: `-prop` Injection** | `120` | `N/A` | `N/A` | 120 Hz | 60 Hz | 120 Hz | 60 Hz | **60.0 FPS** | **~60 FPS Capped** |
| **Condition B2: Feature Override** | `N/A` | `N/A` | `N/A` | 60 Hz | 60 Hz | 60 Hz | 60 Hz | **60.0 FPS** | **60Hz Fallback** |
| **Condition B3: `-qemu -append`** | `N/A` | `N/A` | `N/A` | BOOT_FAILED | 0 Hz | 0 Hz | N/A | **N/A** | **Boot Incompatible** |

### Architectural Decision: **STOCK EMULATOR PROPERTY PATH IMMUTABLE [OPEN]**
> **Finding**: Android 14 (API 34) enforces modern AndroidbootProps where kernel cmdline properties map exclusively to ro.boot.* (ro.boot.qemu.vsync=120). Disabling AndroidbootProps drops property propagation entirely (reverting DisplayManager to 60Hz fallback), and ro.kernel.* cannot be injected via stock emulator CLI flags. The 60Hz presentation cap is governed by the guest SurfaceFlinger HWC3 composer driver timing configuration.

---

## 2. [MEASURED] Platform & Display Subsystem Environment

| Property | Key | Value |
| :--- | :--- | :--- |
| **Hardware Composer HAL** | `ro.hardware.hwcomposer` | **** |
| **Android API Level** | `ro.build.version.sdk` | **34** |
| **Build Fingerprint** | `ro.build.fingerprint` | `google/sdk_gphone64_x86_64/emu64xa:14/UE1A.230829.036.A4/12096271:user/release-keys` |
| **Active Composer Service** | `android.hardware.graphics.composer3-service.ranchu` (AIDL Composer 3) | **Running** |

---

## 3. [INFERENCE] AOSP Source Correlation & Property Propagation Architecture
1. **Modern AndroidbootProps Path**: In Android 14 (`sdk_gphone64_x86_64`), QEMU boot parameters (`hw.lcd.vsync=120`) are transferred via device-tree / kernel boot arguments (`androidboot.qemu.vsync=120`) which Android `init` maps directly into read-only property `ro.boot.qemu.vsync=120`.
2. **Legacy `ro.kernel.*` Property Deprecation**: Modern Android `init` ignores deprecated `ro.kernel.*` namespace translations. Consequently, `ro.kernel.qemu.vsync` remains `N/A` regardless of `-prop` or `-qemu -append` injection.
3. **Display Subsystem Decoupling**: While Android `DisplayManager` parses `ro.boot.qemu.vsync=120` and registers a 120Hz display mode (`mCurrentDisplayMode` = 120 Hz, `Display.getMode()` = 120 Hz), the `SurfaceFlinger` hardware composer active display configuration and Choreographer VSYNC pulse generator remain locked to the primary 60Hz VSYNC clock (`vsyncPeriod = 16666666 ns`).

---

## 4. [OUT OF SCOPE] Scope Boundary Declaration

> [!NOTE]
> **[OUT OF SCOPE]**
> Variable Refresh Rate (VRR / NVIDIA G-Sync / AMD FreeSync / VESA Adaptive-Sync) is not a TabletDroid target. Only fixed 60Hz and fixed 120Hz modes are targeted.

---

## 5. [DECISION] Conclusion & Production Baseline Alignment
1. **Production 60Hz Baseline**: Confirmed and locked at **5/5 VALID (59.27 FPS baseline)**. Throughput, graphics transport (`pipe`), and SetParent embedding architecture are **[CLOSED]**.
2. **Fixed 120Hz Feasibility**: Stock Android emulator system image (`sdk_gphone64_x86_64` API 34) enforces 60Hz SurfaceFlinger hardware composer clocking despite 120Hz DisplayManager mode exposure. Status remains **[OPEN / UNSUPPORTED_IN_STOCK_EMULATOR]**.
3. **Production Recommendation**: Maintain stable 60Hz configuration (`hw.gpu.mode=host`, `hw.gltransport=pipe`) for TabletDroid v0.1.
