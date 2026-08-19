namespace TabletDroid.Core.Models;

/// <summary>
/// TabletDroid 런타임 수명주기 상태
/// </summary>
public enum RuntimeState
{
    Stopped = 0,
    Starting = 1,
    Booting = 2,
    Ready = 3,
    Suspended = 4,
    Stopping = 5,
    Faulted = 6
}

/// <summary>
/// 런타임 시작 또는 동작 실패 원인 코드
/// </summary>
public enum RuntimeFailureReason
{
    None = 0,
    EmulatorNotFound = 1,
    AvdNotFound = 2,
    EmulatorStartFailed = 3,
    AdbTimeout = 4,
    AndroidBootTimeout = 5,
    PortForwardFailed = 6,
    GuestAgentUnavailable = 7,
    HandshakeTimeout = 8,
    AppNotInstalled = 9,
    AppLaunchFailed = 10,
    UnknownError = 99
}

/// <summary>
/// 런타임 상태 변경 및 상세 진단 정보
/// </summary>
public class RuntimeDiagnosticInfo
{
    public RuntimeState State { get; set; } = RuntimeState.Stopped;
    public RuntimeFailureReason FailureReason { get; set; } = RuntimeFailureReason.None;
    public string DiagnosticMessage { get; set; } = string.Empty;
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
}
