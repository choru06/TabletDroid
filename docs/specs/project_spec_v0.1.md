# Windows Tablet Android Runtime — 프로젝트 기획서 v0.1

## 1. 프로젝트 개요

### 프로젝트명
가칭 **TabletDroid**

### 한 줄 정의
Windows 태블릿에서 게임이 아닌 일반 Android 앱을 네이티브 앱처럼 사용할 수 있도록 설계된 **경량 커스텀 Android 런타임**.

### 개발 배경
현재 BlueStacks, MuMuPlayer, LDPlayer 등의 Android 앱플레이어는 대부분 게임 실행을 주요 목적으로 설계되어 있다.

그 결과 일반 앱을 사용하는 경우에도 다음과 같은 불필요한 요소가 존재한다.

- 게임 런처
- 키보드/마우스 키매핑
- 멀티 인스턴스
- 매크로
- 고 FPS 기능
- 게임 광고 및 추천
- 불필요한 툴바
- Android 기본 상태바 및 네비게이션 UI
- PC 데스크톱 중심 인터페이스

TabletDroid는 이러한 요소를 제거하고 **터치스크린 Windows 태블릿에서 Android 일반 앱을 사용하는 경험**에 집중한다.

---

## 2. 핵심 목표

### Primary Goal

Windows 태블릿 사용자가 다음과 같은 Android 앱을 자연스럽게 사용할 수 있도록 한다.

- Instagram
- YouTube
- Discord
- SNS
- 전자책
- 웹툰
- 쇼핑
- 스마트홈
- Android 전용 유틸리티

최종 사용자가 Android Emulator 또는 VM을 직접 관리한다는 느낌을 최대한 없앤다.

---

## 3. 타깃 디바이스

### 1차 개발 타깃
**ASUS ROG Flow Z13 2022**

예상 환경:
- Windows 11
- Intel x86-64 CPU
- Intel Iris Xe / NVIDIA GPU
- 16 GB RAM
- 1920×1200 또는 3840×2400 디스플레이
- 터치스크린
- 자동 화면 회전
- 물리 볼륨 버튼

### 기본 가상 Android 해상도
`1920 × 1200`

### 기본 Refresh Rate
`60 Hz` (게임을 목표로 하지 않으므로 높은 FPS보다 전력 효율과 반응성을 우선)

---

## 4. 제품 철학

TabletDroid는 Android 게임 에뮬레이터가 아니다.

우선순위:
```text
터치 UX > 앱 호환성 > Windows 통합 > 전력 효율 > 성능 > 게임 성능
```

원칙:
- **호스트가 이미 잘하는 기능은 Android에서 중복 구현하지 않는다.**
- **사용자에게 가상머신/에뮬레이터의 존재를 숨긴다.**
