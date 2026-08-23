using System.Windows;
using System.Windows.Media;
using System.Windows.Threading;
using TabletDroid.Bridge.Adb;
using TabletDroid.Bridge.Clipboard;
using TabletDroid.Bridge.Emulator;
using TabletDroid.Bridge.Guest;
using TabletDroid.Bridge.Rotation;
using TabletDroid.Bridge.Window;
using TabletDroid.Core.Models;
using TabletDroid.Core.Services;
using TabletDroid.Runtime;

namespace TabletDroid.Host;

public partial class MainWindow : Window
{
    private readonly IDiagnosticLogService _logService;
    private readonly ISettingsService _settingsService;
    private readonly IAdbClient _adbClient;
    private readonly IEmulatorConsoleClient _consoleClient;
    private readonly IGuestAgentClient _guestClient;
    private readonly IClipboardBridge _clipboardBridge;
    private readonly IRotationBridge _rotationBridge;
    private readonly IWindowsOrientationWatcher _orientationWatcher;
    private readonly IWindowEmbedderService _windowEmbedder;
    private readonly AndroidEmulatorBackend _runtimeBackend;

    private DispatcherTimer? _clipboardPollingTimer;
    private string _lastObservedWindowsClipboard = string.Empty;

    public MainWindow()
    {
        InitializeComponent();

        _logService = new DiagnosticLogService();
        _settingsService = new SettingsService();
        _adbClient = new AdbClient(logger: _logService);
        _consoleClient = new EmulatorConsoleClient();
        _guestClient = new GuestAgentClient();
        _clipboardBridge = new ClipboardBridge(_guestClient);
        _rotationBridge = new RotationBridge(_adbClient, _consoleClient, _guestClient, _logService);
        _orientationWatcher = new DebouncedOrientationWatcher(debounceMilliseconds: 300);
        _windowEmbedder = new TabletDroid.Bridge.Window.Win32WindowEmbedderService(_logService);

        _runtimeBackend = new AndroidEmulatorBackend(_adbClient, _consoleClient, _guestClient, _logService);
        _runtimeBackend.StateChanged += OnRuntimeStateChanged;
        _runtimeBackend.DiagnosticReported += OnDiagnosticReported;

        _clipboardBridge.AndroidClipboardReceived += OnAndroidClipboardReceived;
        _orientationWatcher.OrientationChanged += OnWindowsOrientationChanged;

        Loaded += OnMainWindowLoaded;
        Closing += OnMainWindowClosing;
        SizeChanged += (s, e) => UpdateEmbeddedViewport();
    }

    private async void OnMainWindowLoaded(object sender, RoutedEventArgs e)
    {
        await _settingsService.LoadAsync();
        _logService.Log(LogCategory.Host, "TabletDroid MainWindow loaded.");
        UpdateStatusUi(RuntimeState.Stopped);

        _clipboardBridge.Start();
        _orientationWatcher.Start();

        _clipboardPollingTimer = new DispatcherTimer
        {
            Interval = TimeSpan.FromMilliseconds(500)
        };
        _clipboardPollingTimer.Tick += OnCheckWindowsClipboard;
        _clipboardPollingTimer.Start();

        var args = Environment.GetCommandLineArgs();
        if (args.Contains("--auto-embed"))
        {
            _ = Task.Run(async () =>
            {
                await Task.Delay(1000);
                await Dispatcher.InvokeAsync(async () =>
                {
                    await TriggerEmbedAsync();
                });
            });
        }
    }

    private async void OnMainWindowClosing(object? sender, System.ComponentModel.CancelEventArgs e)
    {
        _logService.Log(LogCategory.Host, "TabletDroid MainWindow closing.");
        _clipboardPollingTimer?.Stop();
        _orientationWatcher.Stop();
        _clipboardBridge.Stop();
        _windowEmbedder.DetachWindow();

        await _runtimeBackend.StopAsync();
    }

    public async Task<bool> TriggerEmbedAsync()
    {
        var hostHwnd = new System.Windows.Interop.WindowInteropHelper(this).Handle;
        if (hostHwnd == IntPtr.Zero) return false;

        _logService.Log(LogCategory.Host, $"Attempting Host embedding (Host HWND: 0x{hostHwnd:X})...");
        LogText.Text = "Embedding Android Emulator window into Host...";

        var success = await _windowEmbedder.EmbedWindowAsync(hostHwnd);
        if (success)
        {
            AppGridScrollViewer.Visibility = Visibility.Collapsed;
            EmulatorViewport.Visibility = Visibility.Visible;
            BtnToggleEmbed.Content = "Detach Window";
            UpdateEmbeddedViewport();

            var source = PresentationSource.FromVisual(this);
            double dpiX = source?.CompositionTarget?.TransformToDevice.M11 ?? 1.0;
            double dpiY = source?.CompositionTarget?.TransformToDevice.M22 ?? 1.0;
            var point = EmulatorViewport.TransformToAncestor(this).Transform(new Point(0, 0));
            int vx = (int)(point.X * dpiX);
            int vy = (int)(point.Y * dpiY);
            int vw = (int)(EmulatorViewport.ActualWidth * dpiX);
            int vh = (int)(EmulatorViewport.ActualHeight * dpiY);

            _logService.Log(LogCategory.Host, $"[HOST_EMBED_SUCCESS] IsEmbedded={_windowEmbedder.IsEmbedded}, EmbeddedHwnd=0x{_windowEmbedder.EmbeddedHwnd:X}, HostHwnd=0x{hostHwnd:X}, Viewport=[{vx},{vy},{vw},{vh}], DpiScale={dpiX:F2}");
            LogText.Text = "Android Emulator embedded into TabletDroid Host (Win32 SetParent child-window embedding).";
            return true;
        }
        else
        {
            LogText.Text = "Failed to find/embed emulator window. Ensure runtime is running.";
            return false;
        }
    }

    public bool TriggerDetach()
    {
        if (!_windowEmbedder.IsEmbedded) return false;

        _windowEmbedder.DetachWindow();
        AppGridScrollViewer.Visibility = Visibility.Visible;
        EmulatorViewport.Visibility = Visibility.Collapsed;
        BtnToggleEmbed.Content = "Embed Window";
        LogText.Text = "Detached emulator window to standalone.";
        _logService.Log(LogCategory.Host, "[HOST_DETACH_SUCCESS] Emulator detached to standalone.");
        return true;
    }

    private async void OnToggleEmbedClicked(object sender, RoutedEventArgs e)
    {
        if (_windowEmbedder.IsEmbedded)
        {
            TriggerDetach();
        }
        else
        {
            await TriggerEmbedAsync();
        }
    }

    private void OnEmulatorViewportSizeChanged(object sender, SizeChangedEventArgs e)
    {
        UpdateEmbeddedViewport();
    }

    private void UpdateEmbeddedViewport()
    {
        if (!_windowEmbedder.IsEmbedded) return;

        var source = PresentationSource.FromVisual(this);
        double dpiX = source?.CompositionTarget?.TransformToDevice.M11 ?? 1.0;
        double dpiY = source?.CompositionTarget?.TransformToDevice.M22 ?? 1.0;

        var point = EmulatorViewport.TransformToAncestor(this).Transform(new Point(0, 0));
        int x = (int)(point.X * dpiX);
        int y = (int)(point.Y * dpiY);
        int w = (int)(EmulatorViewport.ActualWidth * dpiX);
        int h = (int)(EmulatorViewport.ActualHeight * dpiY);

        if (w > 0 && h > 0)
        {
            _windowEmbedder.UpdateViewport(x, y, w, h);
            _logService.Log(LogCategory.Host, $"[HOST_VIEWPORT_GEOMETRY] Logical=[{EmulatorViewport.ActualWidth:F1}x{EmulatorViewport.ActualHeight:F1}], DpiScale={dpiX:F2}, Physical=[{x},{y},{w},{h}], EmbeddedHwnd=0x{_windowEmbedder.EmbeddedHwnd:X}");
        }
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
            // Clipboard lock conflict ignore
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

    private void OnDiagnosticReported(object? sender, RuntimeDiagnosticInfo diag)
    {
        Dispatcher.Invoke(() =>
        {
            LogText.Text = $"[Error] {diag.FailureReason}: {diag.DiagnosticMessage} (Logs at: {_logService.LogDirectory})";
        });
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
        else if (_runtimeBackend.State != RuntimeState.Faulted)
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
            LogText.Text = $"Starting runtime for {appName}...";
            var started = await _runtimeBackend.StartAsync(new RuntimeConfiguration
            {
                AvdName = _settingsService.Settings.DefaultAvdName
            });

            if (!started)
            {
                LogText.Text = $"Could not start runtime for {appName}. Check logs.";
                return;
            }
        }

        // 설치 여부 사전 확인
        var isInstalled = await _adbClient.IsAppInstalledAsync(_runtimeBackend.DeviceSerial, packageName);
        if (!isInstalled)
        {
            LogText.Text = $"{appName} ({packageName}) is NOT installed on {_runtimeBackend.DeviceSerial}. Please install it from Play Store or APK.";
            return;
        }

        LogText.Text = $"Applying {profile.Orientation} orientation and launching {appName}...";

        var targetOrientation = profile.Orientation == OrientationPolicy.PortraitPreferred
            ? Protocol.DeviceOrientation.OrientationRight90
            : Protocol.DeviceOrientation.OrientationNatural;

        await _rotationBridge.SetOrientationAsync(
            targetOrientation,
            profile.Orientation,
            deviceSerial: _runtimeBackend.DeviceSerial);

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
            LogText.Text = $"Failed to launch {appName}.";
        }
    }
}