using TabletDroid.Protocol;

namespace TabletDroid.Bridge.Rotation;

public interface IWindowsOrientationWatcher : IDisposable
{
    DeviceOrientation LastOrientation { get; }
    event EventHandler<DeviceOrientation>? OrientationChanged;
    void Start();
    void Stop();
    void SimulateOrientationChange(DeviceOrientation orientation);
}

public class DebouncedOrientationWatcher : IWindowsOrientationWatcher
{
    private readonly int _debounceMilliseconds;
    private DeviceOrientation _lastReportedOrientation = DeviceOrientation.OrientationNatural;
    private DeviceOrientation _pendingOrientation = DeviceOrientation.OrientationNatural;
    private Timer? _debounceTimer;
    private readonly object _lock = new();
    private bool _isRunning = false;

    public DeviceOrientation LastOrientation => _lastReportedOrientation;
    public event EventHandler<DeviceOrientation>? OrientationChanged;

    public DebouncedOrientationWatcher(int debounceMilliseconds = 300)
    {
        _debounceMilliseconds = debounceMilliseconds;
    }

    public void Start()
    {
        lock (_lock)
        {
            if (_isRunning) return;
            _isRunning = true;
        }
    }

    public void Stop()
    {
        lock (_lock)
        {
            if (!_isRunning) return;
            _isRunning = false;
            _debounceTimer?.Dispose();
            _debounceTimer = null;
        }
    }

    public void SimulateOrientationChange(DeviceOrientation orientation)
    {
        OnRawOrientationDetected(orientation);
    }

    public void OnRawOrientationDetected(DeviceOrientation newOrientation)
    {
        lock (_lock)
        {
            if (!_isRunning) return;

            // 이미 보고된 방향과 동일하면 타이머 취소 및 무시
            if (newOrientation == _lastReportedOrientation)
            {
                _debounceTimer?.Dispose();
                _debounceTimer = null;
                return;
            }

            _pendingOrientation = newOrientation;

            // 디바운스 타이머 재설정
            _debounceTimer?.Dispose();
            _debounceTimer = new Timer(OnDebounceTimerFired, _pendingOrientation, _debounceMilliseconds, Timeout.Infinite);
        }
    }

    private void OnDebounceTimerFired(object? state)
    {
        if (state is not DeviceOrientation orientation) return;

        lock (_lock)
        {
            if (!_isRunning) return;
            if (orientation == _lastReportedOrientation) return;

            _lastReportedOrientation = orientation;
        }

        OrientationChanged?.Invoke(this, orientation);
    }

    public void Dispose()
    {
        Stop();
        GC.SuppressFinalize(this);
    }
}
