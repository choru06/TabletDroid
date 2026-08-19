# TabletDroid 시스템 아키텍처 명세서

## 1. 전체 시스템 구조도

```text
┌─────────────────────────────────────────────────────────────────┐
│                    Windows 11 (Host OS)                         │
│                                                                 │
│  TabletDroid.Host (WinUI 3 Modern Touch Shell)                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ TabletDroid.Core                                          │  │
│  │  ├─ AppRegistry / Catalog                                 │  │
│  │  ├─ DisplayProfile Engine (Resolution, DPI, Orientation)  │  │
│  │  └─ SettingsManager                                       │  │
│  ├───────────────────────────────────────────────────────────┤  │
│  │ TabletDroid.Runtime                                       │  │
│  │  ├─ IRuntimeBackend (Lifecycle abstraction)               │  │
│  │  ├─ AndroidEmulatorBackend (Process & WHPX acceleration)  │  │
│  │  └─ RuntimeStateMachine (Booting, Ready, Suspended, Error)│  │
│  ├───────────────────────────────────────────────────────────┤  │
│  │ TabletDroid.Bridge                                        │  │
│  │  ├─ AdbClient (Management: Boot Check, APK, Fallback)     │  │
│  │  ├─ EmulatorConsoleClient (Telnet: Rotation, Power)       │  │
│  │  ├─ GuestAgentClient (Real-time Proto over TCP/vsock)     │  │
│  │  ├─ RotationBridge (Windows SimpleOrientationSensor)      │  │
│  │  └─ ClipboardBridge (Bi-directional Sync with Loop Guard) │  │
│  └─────────────────────────────┬─────────────────────────────┘  │
└────────────────────────────────┼────────────────────────────────┘
                                 │
                 ┌───────────────┴───────────────┐
                 │ Control          Integration  │
                 │ (ADB/Telnet)     (Protobuf)   │
                 ▼                               ▼
┌─────────────────────────────────────────────────────────────────┐
│  Android Emulator (x86_64 AVD + WHPX 가속)                      │
│                                                                 │
│  Custom AOSP x86_64 (tabletdroid_x86_64)                        │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ TabletDroid.GuestAgent (Privileged System App)            │  │
│  │  ├─ Protobuf Socket Server (Port 28888 / vsock)           │  │
│  │  ├─ Android ClipboardManager Sync Listener                │  │
│  │  ├─ Display Profile / Orientation Controller              │  │
│  │  └─ App Lifecycle & SystemUI Event Dispatcher             │  │
│  ├───────────────────────────────────────────────────────────┤  │
│  │ Clean SystemUI (Overlay: Status Bar = 0, Nav Bar = 0)     │  │
│  │ WindowInsetsPolicy: Default insets (0,0,0,0)              │  │
│  │ TabletDroid Custom Launcher (Minimal Touch Grid)          │  │
│  │ Applications: Instagram, YouTube, Discord, etc.           │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. 서브시스템별 역할 및 통신 경계

### 1) TabletDroid.Host & Core
- **기술 스택**: .NET 9, C#, WinUI 3 (Windows App SDK)
- **주요 역할**:
  - 태블릿 터치 환경에 최적화된 미니멀 앱 런처 제공
  - 앱별 디스플레이 프로파일(화면비, 기본 방향, DPI) 저장 및 관리
  - 런타임 수명주기(시작, 백그라운드 전환, 종료) 제어 및 상태 모니터링

### 2) TabletDroid.Runtime
- `IRuntimeBackend`: 가상화 백엔드 추상화 인터페이스
- `AndroidEmulatorBackend`: WHPX 가속 기반 Android Emulator 프로세스 구동 및 헬스체크 관리
- `RuntimeStateMachine`: 부팅 중(Booting), 준비 완료(Ready), 일시 정지(Suspended), 오류(Faulted) 상태 머신

### 3) TabletDroid.Bridge (이원화 통신 구조)
- **관리 채널 (ADB)**:
  - Emulator 부팅 감지 (`sys.boot_completed`)
  - APK 설치 및 패키지 목록 동기화
  - 장애 복구 및 비상 제어 (Fallback)
- **실시간 통합 채널 (Protobuf / GuestAgent)**:
  - `tabletdroid.proto` 메시지 규약
  - 텍스트 클립보드 양방향 실시간 동기화 (Revision Guard)
  - Windows 센서 기반 화면 회전 제어
  - 원클릭 앱 실행 및 포그라운드 상태 모니터링

### 4) Android Guest & AOSP
- `TabletDroid.GuestAgent`: Android Background / Privileged System Service
- `overlays/`: 상태바 및 네비게이션바 크기를 0으로 축소하여 완벽한 1920×1200 전체화면 보장
- `product/tabletdroid_x86_64`: 불필요 서비스(Cellular, Telephony, SetupWizard 등)가 제거된 경량 AOSP 프로덕트
