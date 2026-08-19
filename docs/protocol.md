# TabletDroid 통신 프로토콜 (TabletDroid Protocol)

TabletDroid Host(Windows)와 GuestAgent(Android) 간의 실시간 양방향 통신을 위한 Protocol Buffers 기반 규약입니다.

## 1. 개요

- **포맷**: Protocol Buffers v3 (`tabletdroid.proto`)
- **전송 계층**:
  - 초기/기본: TCP Socket (`127.0.0.1:28888`, `adb forward tcp:28888 tcp:28888` 또는 Emulator Port Forwarding)
  - 차기: `vsock` (virtio-vsock 지원 시)
- **프레이밍**: 4바이트 Big-Endian Length-Prefixed Framing (`[Length: uint32][Protobuf Payload]`)

---

## 2. 주요 기능 및 메시지

### 1) 클립보드 동기화 (루프 방지 메커니즘)
- `ClipboardSyncEvent`: `revision_id`, `source` (Windows / Android), `content_hash` (SHA-256), `text_content` 포함
- **루프 방지 흐름**:
  1. Windows에서 복사 발생: Host에서 `revision_id=N`, `hash=H`, `source=WINDOWS`로 전송
  2. GuestAgent가 Android `ClipboardManager.setPrimaryClip()` 호출
  3. Android 클립보드 변경 이벤트가 GuestAgent에 수신됨
  4. 수신된 텍스트의 해시가 `H`와 동일하거나 최근 수신된 `revision_id`와 일치하면 Host로 재전송하지 않고 무시

### 2) 화면 회전 제어
- `SetOrientationRequest`: Host의 `SimpleOrientationSensor` 각도를 Guest에 전달하여 부드럽고 즉각적인 화면 회전 수행

### 3) 앱 라이프사이클 및 실행
- `LaunchAppRequest` / `LaunchAppResponse`: 앱 패키지 및 Activity 즉시 실행
- `ListInstalledAppsRequest` / `ListInstalledAppsResponse`: 설치된 앱 목록 및 아이콘 바이너리 실시간 조회

### 4) 시스템 UI 제어
- `SetImmersiveModeRequest`: 상태바 / 네비게이션바 숨김 플래그 전달
