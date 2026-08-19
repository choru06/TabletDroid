using TabletDroid.Core.Models;

namespace TabletDroid.Runtime;

public class RuntimeStateMachine
{
    private RuntimeState _currentState = RuntimeState.Stopped;
    private readonly object _lock = new();

    public RuntimeState CurrentState => _currentState;
    public event EventHandler<RuntimeState>? StateChanged;

    public bool TransitionTo(RuntimeState newState)
    {
        lock (_lock)
        {
            if (_currentState == newState)
            {
                return false;
            }

            // 유효한 상태 전이 확인
            var isValid = (_currentState, newState) switch
            {
                (RuntimeState.Stopped, RuntimeState.Starting) => true,
                (RuntimeState.Starting, RuntimeState.Booting) => true,
                (RuntimeState.Starting, RuntimeState.Faulted) => true,
                (RuntimeState.Booting, RuntimeState.Ready) => true,
                (RuntimeState.Booting, RuntimeState.Faulted) => true,
                (RuntimeState.Ready, RuntimeState.Suspended) => true,
                (RuntimeState.Ready, RuntimeState.Stopping) => true,
                (RuntimeState.Suspended, RuntimeState.Ready) => true,
                (RuntimeState.Suspended, RuntimeState.Stopping) => true,
                (RuntimeState.Stopping, RuntimeState.Stopped) => true,
                (RuntimeState.Stopping, RuntimeState.Faulted) => true,
                (RuntimeState.Faulted, RuntimeState.Stopped) => true,
                (RuntimeState.Faulted, RuntimeState.Starting) => true,
                _ => false
            };

            if (!isValid)
            {
                return false;
            }

            _currentState = newState;
        }

        StateChanged?.Invoke(this, newState);
        return true;
    }

    public void Reset()
    {
        lock (_lock)
        {
            _currentState = RuntimeState.Stopped;
        }
        StateChanged?.Invoke(this, RuntimeState.Stopped);
    }
}
