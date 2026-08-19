using System.Windows;
using System.Windows.Media;
using System.Windows.Threading;
using TabletDroid.Bridge.Adb;
using TabletDroid.Bridge.Clipboard;
using TabletDroid.Bridge.Emulator;
using TabletDroid.Bridge.Guest;
using TabletDroid.Bridge.Rotation;
using TabletDroid.Core.Models;
using TabletDroid.Core.Services;
using TabletDroid.Runtime;

namespace TabletDroid.Host;

public partial class MainWindow : Window
{
    private readonly ISettingsService _settingsService;
    private readonly IAdbClient _adbClient;
    private readonly IEmulatorConsoleClient _consoleClient;
    private readonly IGuestAgentClient _guestClient;
    private readonly IClipboardBridge _clipboardBridge;
    private readonly IRotationBridge _rotationBridge;
    private readonly IWindowsOrientationWatcher _orientationWatcher;
    private readonly AndroidEmulatorBackend _runtimeBackend;

    private DispatcherTimer? _clipboardPollingTimer;
    private string _lastObservedWindowsClipboard = string.Empty;

    public MainWindow()
    {
        InitializeComponent();

        _settingsService = new SettingsService();
        _adbClient = new AdbClient();
        _consoleClient = new EmulatorConsoleClient();
        _guestClient = new GuestAgentClient();
        _clipboardBridge = new ClipboardBridge(_guestClient);
        _rotationBridge = new RotationBridge(_adbClient, _consoleClient, _guestClient);
        _orientationWatcher = new DebouncedOrientationWatcher(debounceMilliseconds: 300);

        _runtimeBackend = new AndroidEmulatorBackend(_adbClient, _consoleClient, _guestClient);
        _runtimeBackend.StateChanged += OnRuntimeStateChanged;

        // Android ➔ Windows 클립보드 수신 이벤트 연결
        _clipboardBridge.AndroidClipboardReceived += OnAndroidClipboardReceived;

        // Windows 센서 방향 변경 ➔ Android 회전 브릿지 연결
        _orientationWatcher.OrientationChanged += OnWindowsOrientationChanged;

        Loaded += OnMainWindowLoaded;
        Closing += OnMainWindowClosing;
    }

    private async void OnMainWindowLoaded(object sender, RoutedEventArgs e)
    {
        await _settingsService.LoadAsync();
        UpdateStatusUi(RuntimeState.Stopped);

        _clipboardBridge.Start();
        _orientationWatcher.Start();

        // Windows 클립보드 변경 폴링 타이머 (500ms 주기)
        _clipboardPollingTimer = new DispatcherTimer
        {
            Interval = TimeSpan.FromMilliseconds(500)
        };
        _clipboardPollingTimer.Tick += OnCheckWindowsClipboard;
        _clipboardPollingTimer.Start();
    }

    private async void OnMainWindowClosing(object? sender, System.ComponentModel.CancelEventArgs e)
    {
        _clipboardPollingTimer?.Stop();
        _orientationWatcher.Stop();
        _clipboardBridge.Stop();

        await _runtimeBackend.StopAsync();
    }

    private void OnCheckWindowsClipboard(object? sender, EventArgs e)
    {
        try
        {
            if (System.Windows.Clipboard.ContainsText())
            {
                var currentText = System.Windows.Clipboard.GetText();
                if (!string.IsNullOrEmpty(currentText) && currentText != _lastObservedWindowsClipboard)
                {
                    _lastObservedWindowsClipboard = currentText;
                    _ = _clipboardBridge.HandleWindowsClipboardChangedAsync(currentText);
                }
            }
        }
        catch
        {
            // Clipboard lock 충돌 방지
        }
    }

    private void OnAndroidClipboardReceived(object? sender, string text)
    {
        Dispatcher.Invoke(() =>
        {
            try
            {
                _lastObservedWindowsClipboard = text;
                System.Windows.Clipboard.SetText(text);
                LogText.Text = $"Synced clipboard from Android: \"{(text.Length > 20 ? text[..20] + "..." : text)}\"";
            }
            catch
            {
                // ignore
            }
        });
    }

    private async void OnWindowsOrientationChanged(object? sender, Protocol.DeviceOrientation orientation)
    {
        if (_runtimeBackend.State == RuntimeState.Ready)
        {
            await _rotationBridge.SetOrientationAsync(
                orientation,
                OrientationPolicy.Auto,
                deviceSerial: _runtimeBackend.DeviceSerial);

            Dispatcher.Invoke(() =>
            {
                LogText.Text = $"Rotated display to {orientation} (auto sensor).";
            });
        }
    }

    private void OnRuntimeStateChanged(object? sender, RuntimeState state)
    {
        Dispatcher.Invoke(() => UpdateStatusUi(state));
    }

    private void UpdateStatusUi(RuntimeState state)
    {
        StatusText.Text = state.ToString().ToUpperInvariant();

        var (bg, fg, dotColor) = state switch
        {
            RuntimeState.Ready => ("#064E3B", "#6EE7B7", "#10B981"),
            RuntimeState.Booting or RuntimeState.Starting => ("#78350F", "#FDE68A", "#F59E0B"),
            RuntimeState.Suspended => ("#1E293B", "#94A3B8", "#64748B"),
            RuntimeState.Faulted => ("#7F1D1D", "#FCA5A5", "#EF4444"),
            _ => ("#334155", "#E2E8F0", "#94A3B8")
        };

        StatusBadge.Background = new BrushConverter().ConvertFromString(bg) as Brush;
        StatusText.Foreground = new BrushConverter().ConvertFromString(fg) as Brush;
        StatusDot.Fill = new BrushConverter().ConvertFromString(dotColor) as Brush;

        BtnStartRuntime.IsEnabled = (state == RuntimeState.Stopped || state == RuntimeState.Faulted);
        BtnStopRuntime.IsEnabled = (state != RuntimeState.Stopped);
    }

    private async void OnStartRuntimeClicked(object sender, RoutedEventArgs e)
    {
        LogText.Text = "Starting Android Emulator with WHPX acceleration...";
        var config = new RuntimeConfiguration
        {
            AvdName = _settingsService.Settings.DefaultAvdName
        };

        var success = await _runtimeBackend.StartAsync(config);
        if (success)
        {
            LogText.Text = $"Android Runtime is READY on {_runtimeBackend.DeviceSerial}. Fullscreen mode active.";
        }
        else
        {
            LogText.Text = "Failed to start Android Runtime. Check WHPX / AVD configuration.";
        }
    }

    private async void OnStopRuntimeClicked(object sender, RoutedEventArgs e)
    {
        LogText.Text = "Stopping Android Runtime...";
        await _runtimeBackend.StopAsync();
        LogText.Text = "Android Runtime stopped.";
    }

    private async void OnLaunchInstagramClicked(object sender, RoutedEventArgs e)
    {
        await LaunchOrStartAppAsync("com.instagram.android", DisplayProfile.PortraitApp, "Instagram");
    }

    private async void OnLaunchYouTubeClicked(object sender, RoutedEventArgs e)
    {
        await LaunchOrStartAppAsync("com.google.android.youtube", DisplayProfile.DefaultTablet, "YouTube");
    }

    private async void OnLaunchDiscordClicked(object sender, RoutedEventArgs e)
    {
        await LaunchOrStartAppAsync("com.discord", DisplayProfile.DefaultTablet, "Discord");
    }

    private async Task LaunchOrStartAppAsync(string packageName, DisplayProfile profile, string appName)
    {
        if (_runtimeBackend.State != RuntimeState.Ready)
        {
            LogText.Text = $"Starting runtime to launch {appName}...";
            var started = await _runtimeBackend.StartAsync(new RuntimeConfiguration
            {
                AvdName = _settingsService.Settings.DefaultAvdName
            });

            if (!started)
            {
                LogText.Text = $"Could not start runtime for {appName}.";
                return;
            }
        }

        LogText.Text = $"Setting display orientation and launching {appName}...";

        // 화면 방향 정책 적용
        var targetOrientation = profile.Orientation == OrientationPolicy.PortraitPreferred
            ? Protocol.DeviceOrientation.OrientationRight90
            : Protocol.DeviceOrientation.OrientationNatural;

        await _rotationBridge.SetOrientationAsync(
            targetOrientation,
            profile.Orientation,
            deviceSerial: _runtimeBackend.DeviceSerial);

        // 앱 실행 (GuestAgent RPC 우선 시도 후 ADB Fallback)
        bool launched = false;
        if (_guestClient.IsReady)
        {
            launched = await _guestClient.SendLaunchAppAsync(packageName);
        }

        if (!launched)
        {
            launched = await _adbClient.LaunchAppAsync(_runtimeBackend.DeviceSerial, packageName);
        }

        if (launched)
        {
            LogText.Text = $"{appName} launched successfully in fullscreen.";
        }
        else
        {
            LogText.Text = $"Failed to launch {appName}. Is the APK installed?";
        }
    }
}