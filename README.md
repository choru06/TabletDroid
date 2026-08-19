# TabletDroid

> **Windows 태블릿을 위한 경량 네이티브형 Android 런타임**

TabletDroid는 Windows 태블릿(ASUS ROG Flow Z13 등 x86_64 터치 디바이스)에서 게임이 아닌 일반 Android 앱(Instagram, YouTube, Discord, 웹툰, 전자책 등)을 Windows 네이티브 앱처럼 사용할 수 있도록 설계된 전용 런타임입니다.

기존 게이밍 에뮬레이터(BlueStacks, LDPlayer, MuMuPlayer 등)의 불필요한 게이밍 요소(키매핑, 매크로, 광고, 복잡한 툴바)와 기본 Android System UI(상태바, 네비게이션바)를 완전히 제거하고, **터치스크린 태블릿 사용자 경험, 클린 전체화면(1920×1200), Windows 하드웨어 통합(자동 화면 회전, 클립보드 동기화)**에 집중합니다.

---

## 🌟 핵심 특징

1. **Pure Tablet App UX**: 게이밍 오버레이 및 불필요한 기능 제거, 오직 앱 화면에 집중
2. **Clean Fullscreen**: Status Bar / Navigation Bar 없는 완벽한 전체화면 (1920×1200)
3. **Windows 11 네이티브 통합**:
   - **자동 화면 회전**: Windows `SimpleOrientationSensor` 감지 후 Android 즉시 동기화
   - **양방향 클립보드**: Windows ↔ Android 간 텍스트 동기화 (Revision ID/Hash 루프 방지)
   - **터치 & 펜**: Windows Multi-Touch 제스처 완벽 지원
4. **모듈식 분리 아키텍처**:
   - **관리/생명주기**: ADB 제어
   - **실시간 통신**: Protocol Buffers (`tabletdroid.proto`) 기반 `TabletDroid.GuestAgent` (Android Background/Privileged App) 연동
   - **가상화**: Android Emulator + x86_64 AVD + WHPX(Windows Hypervisor Platform) 하드웨어 가속

---

## 📁 저장소 구조

```text
TabletDroid/
├─ host/                                # Windows Native Host (.NET 9 / C#)
│  ├─ TabletDroid.sln
│  ├─ TabletDroid.Host/                 # WinUI 3 터치 친화적 런처 UI & 윈도우 관리
│  ├─ TabletDroid.Core/                 # Models, Settings, Display Profile 정책
│  ├─ TabletDroid.Runtime/              # IRuntimeBackend, AndroidEmulatorBackend, StateMachine
│  ├─ TabletDroid.Bridge/               # Adb/, Emulator/, Guest/, Rotation/, Clipboard/
│  └─ TabletDroid.Tests/                # 단위 및 모의(Mock) 통합 테스트
│
├─ android/                             # Android Guest 및 AOSP 커스텀 컴포넌트
│  ├─ guest/
│  │  └─ TabletDroid.GuestAgent/        # Android Privileged System App (Kotlin/Java)
│  ├─ product/
│  │  └─ tabletdroid_x86_64/            # AOSP Product Definition (Makefile/Soong)
│  ├─ launcher/                         # 초경량 태블릿 런처
│  ├─ overlays/                         # RRO (Resource Overlays) - Insets & Bar 제거
│  └─ patches/                          # Framework 패치 (WindowInsets/WindowManager)
│
├─ protocol/                            # Host ↔ Guest 통신 규약
│  ├─ tabletdroid.proto                 # Protobuf 메시지 정의
│  └─ README.md                         # 프로토콜 명세 문서
│
├─ scripts/                             # 개발 및 배포 자동화
│  ├─ windows/                          # 환경 점검, Emulator 실행, AVD 생성 스크립트
│  └─ linux/                            # AOSP 빌드 및 이미지 패키징 스크립트
│
├─ docs/                                # 기술 문서
│  ├─ specs/                            # 기획서 원본 아카이브
│  ├─ architecture.md                   # 시스템 아키텍처 상세
│  ├─ protocol.md                       # 통신 프로토콜 명세
│  ├─ build-environment.md              # Linux 빌드 머신 및 Windows 타깃 구성 가이드
│  └─ roadmap.md                        # 단계별 마일스톤
│
└─ README.md
```

---

## 🚀 빠른 시작 가이드 (Windows Target)

### 요구 사양
- **OS**: Windows 11 (22H2 이상 권장)
- **가상화**: Windows Hypervisor Platform (WHPX) 활성화
- **CPU**: Intel x86-64 / AMD64 (VT-x / AMD-V 활성화)
- **개발 환경**: .NET 9 SDK, Android SDK Command-line Tools / Emulator

### 실행 방법
```powershell
# 1. 개발 환경 점검
./scripts/windows/check-env.ps1

# 2. 호스트 솔루션 빌드
dotnet build host/TabletDroid.sln

# 3. 테스트 실행
dotnet test host/TabletDroid.sln
```

---

## 📖 문서 링크

- [시스템 아키텍처 상세](docs/architecture.md)
- [통신 프로토콜 명세 (Protocol Buffers)](docs/protocol.md)
- [빌드 및 개발 환경 가이드](docs/build-environment.md)
- [개발 로드맵 (v0.0 ~ v0.5)](docs/roadmap.md)
- [기획서 원본 v0.1](docs/specs/project_spec_v0.1.md)
