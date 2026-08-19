using System.Windows;
using System.Windows.Media;
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
    private readonly IRuntimeBackend _runtimeBackend;

    public MainWindow()
    {
        InitializeComponent();

        _settingsService = new SettingsService();
        _adbClient = new AdbClient();
        _consoleClient = new EmulatorConsoleClient();
        _guestClient = new GuestAgentClient();
        _clipboardBridge = new ClipboardBridge(_guestClient);
        _rotationBridge = new RotationBridge(_consoleClient, _guestClient);

        _runtimeBackend = new AndroidEmulatorBackend(_adbClient, _consoleClient, _guestClient);
        _runtimeBackend.StateChanged += OnRuntimeStateChanged;

        Loaded += OnMainWindowLoaded;
        Closing += OnMainWindowClosing;
    }

    private async void OnMainWindowLoaded(object sender, RoutedEventArgs e)
    {
        await _settingsService.LoadAsync();
        UpdateStatusUi(RuntimeState.Stopped);
        _clipboardBridge.Start();
    }

    private async void OnMainWindowClosing(object? sender, System.ComponentModel.CancelEventArgs e)
    {
        _clipboardBridge.Stop();
        await _runtimeBackend.StopAsync();
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
            LogText.Text = "Android Runtime is READY. Fullscreen mode active.";
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
        if (profile.Orientation == OrientationPolicy.PortraitPreferred)
        {
            await _rotationBridge.SetOrientationAsync(Protocol.DeviceOrientation.OrientationRight90, profile.Orientation);
        }
        else
        {
            await _rotationBridge.SetOrientationAsync(Protocol.DeviceOrientation.OrientationNatural, profile.Orientation);
        }

        // 앱 실행 (GuestAgent 우선 시도 후 ADB Fallback)
        bool launched = false;
        if (_guestClient.IsConnected)
        {
            launched = await _guestClient.SendLaunchAppAsync(packageName);
        }

        if (!launched)
        {
            launched = await _adbClient.LaunchAppAsync("emulator-5554", packageName);
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