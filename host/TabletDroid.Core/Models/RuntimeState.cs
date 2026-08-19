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
