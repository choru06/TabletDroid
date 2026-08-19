# TabletDroid 개발 및 빌드 환경 구성 가이드

TabletDroid 프로젝트는 **AOSP 빌드 머신(Linux)**과 **타깃 실행 머신(Windows 11)**의 역할을 명확히 분리하여 운영합니다.

---

## 1. 아키텍처 환경 분리

```text
┌─────────────────────────────────────────┐
│     AOSP Build Machine (Linux Server)   │
│                                         │
│ - OS: Ubuntu 22.04 / 24.04 LTS (64-bit) │
│ - RAM: 64 GB+ (권장 128 GB)              │
│ - Storage: 400 GB+ NVMe SSD             │
│ - Role: AOSP tabletdroid_x86_64 빌드,   │
│         System Image 및 패키지 릴리스   │
└────────────────────┬────────────────────┘
                     │
                     │ system-qemu.img, userdata.img, etc.
                     ▼
┌─────────────────────────────────────────┐
│     Target Device (ASUS ROG Flow Z13)   │
│                                         │
│ - OS: Windows 11 (22H2+)                │
│ - Hypervisor: WHPX (가속)               │
│ - RAM: 16 GB+                           │
│ - Display: 1920x1200 / Touch / Sensor   │
│ - Role: TabletDroid.Host 실행,          │
│         Android Emulator 런타임 구동    │
└─────────────────────────────────────────┘
```

---

## 2. Windows 타깃 및 호스트 개발 환경 (ROG Flow Z13)

### 필수 요구사항
1. **.NET 9 SDK** (`dotnet --info` 확인)
2. **Windows App SDK / WinUI 3 개발 도구**
3. **Android SDK Command-line Tools & Android Emulator**
4. **Windows 기능 활성화**:
   - `Windows Hypervisor Platform` (WHPX)
   - `Virtual Machine Platform` (가상 머신 플랫폼)

### 환경 변수 권장 설정
```powershell
$env:ANDROID_HOME = "C:\Users\<User>\AppData\Local\Android\Sdk"
$env:PATH += ";$env:ANDROID_HOME\emulator;$env:ANDROID_HOME\platform-tools"
```

---

## 3. Linux AOSP 빌드 서버 환경

### 사전 필수 패키지 설치
```bash
sudo apt update && sudo apt install -y \
    git-core gnupg flex bison build-essential zip curl zlib1g-dev \
    libc6-dev-i386 libncurses5 x11proto-core-dev libx11-dev \
    lib32z1-dev libgl1-mesa-dev libxml2-utils xsltproc unzip fontconfig python3 openjdk-17-jdk
```

### 소스 동기화 및 타깃 빌드
```bash
# Repo 초기화 (Android 14/15 x86_64 기반)
repo init -u https://android.googlesource.com/platform/manifest -b android-14.0.0_rXX

# TabletDroid 디바이스 트리 추가
git clone <repo_url>/android/device/tabletdroid_x86_64 device/tabletdroid/x86_64

# 빌드 환경 설정 및 타깃 컴파일
source build/envsetup.sh
lunch tabletdroid_x86_64-userdebug
m
```
