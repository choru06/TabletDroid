# TabletDroid Protocol Definition

이 디렉토리는 Windows Host와 Android GuestAgent 간의 통신 프로토콜 정의를 포함합니다.

- `tabletdroid.proto`: Protobuf 정의 파일
- C# 빌드 시 `Google.Protobuf` 및 `Grpc.Tools`에 의해 자동으로 C# 클래스가 생성됩니다.
- Android 빌드 시 Gradle `protobuf` 플러그인에 의해 Java/Kotlin 클래스가 생성됩니다.
