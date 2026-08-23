# TabletDroid 120Hz Framework Refresh-Rate Policy Diagnostic Report

- **Date / Timestamp**: 2026-08-23 19:51:12
- **Target Hardware**: ASUS ROG Flow Z13 (Intel Core i9-12900H, NVIDIA GeForce RTX 3050 Ti Laptop GPU, 16GB RAM)
- **Target OS**: Windows 11 Home 23H2 (Hypervisor: WHPX)
- **Host Physical Panel**: 1920x1200 @ 120 Hz
- **Target AVD Configuration**: `hw.lcd.vsync = 120`, `hw.gpu.mode = host`, `hw.gltransport = pipe`, `-no-snapshot`, `-no-snapshot-save`

---

## 1. Executive Summary & Diagnostic Telemetry Comparison

| Pipeline Layer | Subsystem / Property | Control A (Default Policy) | Condition B (Forced 120.0 Policy) | Evaluation |
| :--- | :--- | :---: | :---: | :---: |
| **Layer A: AVD Config** | `hw.lcd.vsync` | **120** | **120** | Configured 120 |
| **Layer B: Guest Boot Prop** | `ro.boot.qemu.vsync` | **120** | **120** | [MEASURED] ro.boot=120, ro.kernel=N/A |
| **Layer C: DisplayManager** | `mCurrentDisplayMode` | 120 Hz | 120 Hz | 120Hz Mode Active |
| **Layer D: Framework Policy** | `system.peak_refresh_rate` / `min_refresh_rate` | `UNSET (default)` | `120.0` | Applied & Verified |
| **Layer E: App Display Mode** | `Display.getMode().getRefreshRate()` | 120 Hz | 120 Hz | 120Hz Mode Active |
| **Layer F: App Refresh Rate** | `Display.getRefreshRate()` | 60 Hz | **120 Hz** | **120 Hz Unlocked** |
| **Layer G: Guest Choreographer** | Workload frame callback cadence | 58.61 FPS | **119.08 FPS** | **120 FPS Render Cadence** |

### Architectural Decision: **FRAMEWORK REFRESH POLICY ROOT CAUSE PROVEN**
> **Finding**: Applying system peak_refresh_rate=120 and min_refresh_rate=120 successfully unlocks full 120 FPS cadence in Android Choreographer and SurfaceFlinger.

---

## 2. [INFERENCE] Android 14 AIDL HWC3 Architecture & Refresh Rate Control Path
1. **Active Composer Service**: `android.hardware.graphics.composer3-service.ranchu` (AIDL Hardware Composer 3).
2. **Framework Refresh-Rate Mediation**:
   - Android `DisplayManager` registers `ro.boot.qemu.vsync=120` and creates display mode ID 1 (1920x1200 @ 120Hz).
   - `DisplayModeDirector` evaluates vote priorities (thermal, power, user settings). By default without explicit system settings, `DisplayModeDirector` restricts application refresh rate to 60Hz.
   - Injecting `system.peak_refresh_rate=120.0` and `system.min_refresh_rate=120.0` unlocks the 120Hz vote priority, directly updating `Display.getRefreshRate()` to 120Hz and driving `Choreographer` frame callbacks at 120 FPS.

---

## 3. [OUT OF SCOPE] Scope Boundary Declaration

> [!NOTE]
> **[OUT OF SCOPE]**
> Variable Refresh Rate (VRR / NVIDIA G-Sync / AMD FreeSync / VESA Adaptive-Sync) is not a TabletDroid target. Only fixed 60Hz and fixed 120Hz modes are targeted.
