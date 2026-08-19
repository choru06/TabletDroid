# TabletDroid 개발 로드맵 (Roadmap)

## 마일스톤 개요

```text
v0.0 Technical Spike
  │  (WHPX + Emulator + 1920x1200 + Touch/Reels 검증)
  ▼
v0.1 Minimal Viable Host (MVP)
  │  (WinUI 3 Host + Stock Android + ADB + Emulator Control + Instagram 원클릭)
  ▼
v0.2 GuestAgent & Real-time Integration
  │  (Protobuf TCP Socket + Bi-directional Clipboard + Orientation + Custom Launcher)
  ▼
v0.3 Custom AOSP System Image
  │  (tabletdroid_x86_64 Product + SystemUI Overlay Insets=0 + Privileged GuestAgent)
  ▼
v0.4 Snapshot & Fast Boot
  │  (Background Suspend/Resume + 1초 이내 앱 로딩)
  ▼
v0.5 Windows Start Menu Integration
     (개별 Android 앱 Windows 바로가기 + WSA 스타일 경험)
```

---

## 단계별 세부 계획

### v0.0 Technical Spike
- [x] WHPX 기반 Android Emulator 호환성 점검
- [ ] 1920×1200 AVD 생성 및 기본 터치/오디오/회전 반응성 검증

### v0.1 Minimal Viable Host (MVP)
- **목표**: ROG Flow Z13에서 Instagram 하나를 원클릭으로 완벽하게 실행
- [ ] `TabletDroid.Runtime` (`IRuntimeBackend`, `AndroidEmulatorBackend`) 구현
- [ ] `TabletDroid.Bridge` (ADB 프로세스 감시, Console 제어) 구현
- [ ] `TabletDroid.Host` (WinUI 3 미니멀 터치 런처)
- [ ] `policy_control` 임시 전체화면(상태바/네비바 숨김) 적용

### v0.2 GuestAgent & 실시간 통합
- **목표**: ADB 폴링 없는 고성능 양방향 통합
- [ ] `TabletDroid.GuestAgent` (Android 백그라운드 서비스 및 Protobuf 서버)
- [ ] 양방향 텍스트 클립보드 동기화 (Revision ID & Hash 루프 방지)
- [ ] Windows `SimpleOrientationSensor` 감지 ➔ 실시간 회전 브릿지
- [ ] TabletDroid 전용 경량 태블릿 런처

### v0.3 Custom AOSP Image (Clean OS)
- **목표**: 별도 명령 없이 OS 자체에서 상태바/네비바가 존재하지 않는 퓨어 태블릿 런타임
- [ ] AOSP `tabletdroid_x86_64` 제품 정의 (불필요 시스템 서비스 제거)
- [ ] RRO(Resource Overlay) 기반 WindowInsets(0,0,0,0) 적용
- [ ] GuestAgent를 `/system/priv-app`으로 내장

### v0.4 Fast Boot & Lifecycle
- **목표**: 사용자가 에뮬레이터 부팅을 체감하지 못하는 빠른 로딩
- [ ] Quickboot / Snapshot 기반 인스턴스 복원
- [ ] Host 종료/최소화 시 Android 인스턴스 Suspend/Resume

### v0.5 Windows Deep Integration (WSA Alternative)
- **목표**: Windows 시작 메뉴에서 Android 앱 단독 실행
- [ ] Windows 시작 메뉴 바로가기 자동 등록
- [ ] APK 아이콘 자동 추출 및 Windows 바로가기 아이콘화
- [ ] 독립 앱 윈도우 모드 프로토타입
