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

            try
            {
                Microsoft.Win32.SystemEvents.DisplaySettingsChanged += OnDisplaySettingsChanged;
                // 초기 현재 디스플레이 방향 감지
                CheckCurrentDisplayOrientation();
            }
            catch
            {
                // Fallback if SystemEvents is restricted
            }
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

            try
            {
                Microsoft.Win32.SystemEvents.DisplaySettingsChanged -= OnDisplaySettingsChanged;
            }
            catch {}
        }
    }

    private void OnDisplaySettingsChanged(object? sender, EventArgs e)
    {
        CheckCurrentDisplayOrientation();
    }

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    private static extern int GetSystemMetrics(int nIndex);
    private const int SM_CXSCREEN = 0;
    private const int SM_CYSCREEN = 1;

    private void CheckCurrentDisplayOrientation()
    {
        try
        {
            int width = GetSystemMetrics(SM_CXSCREEN);
            int height = GetSystemMetrics(SM_CYSCREEN);

            if (width <= 0) width = 1920;
            if (height <= 0) height = 1200;

            var detected = (width >= height)
                ? DeviceOrientation.OrientationNatural      // 가로 (Landscape 1920x1200)
                : DeviceOrientation.OrientationRight90;    // 세로 (Portrait 1200x1920)

            OnRawOrientationDetected(detected);
        }
        catch
        {
            // P/Invoke fallback
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
