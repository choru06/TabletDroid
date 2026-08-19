using System.Diagnostics;
using System.Text;
using TabletDroid.Bridge.Adb;
using TabletDroid.Bridge.Emulator;
using TabletDroid.Bridge.Guest;
using TabletDroid.Core.Models;
using TabletDroid.Core.Services;

namespace TabletDroid.Runtime;

public class AndroidEmulatorBackend : IRuntimeBackend
{
    private readonly IAdbClient _adbClient;
    private readonly IEmulatorConsoleClient _consoleClient;
    private readonly IGuestAgentClient _guestClient;
    private readonly IDiagnosticLogService? _logger;
    private readonly RuntimeStateMachine _stateMachine = new();

    private Process? _emulatorProcess;
    private RuntimeConfiguration? _currentConfig;
    private string _deviceSerial = "emulator-5554";

    public RuntimeState State => _stateMachine.CurrentState;
    public RuntimeConfiguration? CurrentConfig => _currentConfig;
    public string DeviceSerial => _deviceSerial;
    public RuntimeFailureReason LastFailureReason { get; private set; } = RuntimeFailureReason.None;
    public string LastDiagnosticMessage { get; private set; } = string.Empty;

    public event EventHandler<RuntimeState>? StateChanged;
    public event EventHandler<RuntimeDiagnosticInfo>? DiagnosticReported;

    public AndroidEmulatorBackend(
        IAdbClient adbClient,
        IEmulatorConsoleClient consoleClient,
        IGuestAgentClient guestClient,
        IDiagnosticLogService? logger = null)
    {
        _adbClient = adbClient;
        _consoleClient = consoleClient;
        _guestClient = guestClient;
        _logger = logger;

        _stateMachine.StateChanged += (s, e) => StateChanged?.Invoke(this, e);
    }

    public async Task<bool> StartAsync(RuntimeConfiguration config, CancellationToken ct = default)
    {
        if (State != RuntimeState.Stopped && State != RuntimeState.Faulted)
        {
            _logger?.Log(LogCategory.Runtime, $"StartAsync ignored. Current state is {State}", "WARN");
            return false;
        }

        _currentConfig = config;
        _deviceSerial = $"emulator-{config.ConsolePort}";
        LastFailureReason = RuntimeFailureReason.None;
        LastDiagnosticMessage = "Starting runtime...";

        _logger?.Log(LogCategory.Runtime, $"=== Starting Android Runtime (AVD: {config.AvdName}, Port: {config.ConsolePort}, Device: {_deviceSerial}) ===");
        _stateMachine.TransitionTo(RuntimeState.Starting);

        try
        {
            var emulatorBinary = ResolveEmulatorBinary(config.EmulatorBinaryPath);
            if (!File.Exists(emulatorBinary) && emulatorBinary != "emulator")
            {
                SetFailure(RuntimeFailureReason.EmulatorNotFound, $"Android Emulator binary not found at '{emulatorBinary}'");
                return false;
            }

            var argsBuilder = new StringBuilder();
            argsBuilder.Append($"-avd {config.AvdName} ");
            argsBuilder.Append($"-port {config.ConsolePort} ");

            if (config.UseWhpxAcceleration)
            {
                argsBuilder.Append("-accel on ");
            }

            if (!string.IsNullOrWhiteSpace(config.GpuMode))
            {
                argsBuilder.Append($"-gpu {config.GpuMode} ");
            }

            if (config.NoSkin)
            {
                argsBuilder.Append("-no-skin ");
            }

            if (config.NoSnapshotSave)
            {
                argsBuilder.Append("-no-snapshot-save ");
            }

            argsBuilder.Append("-no-boot-anim ");

            var psi = new ProcessStartInfo
            {
                FileName = emulatorBinary,
                Arguments = argsBuilder.ToString().Trim(),
                UseShellExecute = false,
                CreateNoWindow = false
            };

            _logger?.Log(LogCategory.Runtime, $"Launching Emulator process: {emulatorBinary} {psi.Arguments}");
            _emulatorProcess = new Process { StartInfo = psi, EnableRaisingEvents = true };
            _emulatorProcess.Exited += OnEmulatorProcessExited;

            if (!_emulatorProcess.Start())
            {
                SetFailure(RuntimeFailureReason.EmulatorStartFailed, "Process.Start() returned false for emulator binary.");
                return false;
            }

            _stateMachine.TransitionTo(RuntimeState.Booting);

            // 1. ADB Boot 완료 대기
            var bootTimeout = TimeSpan.FromSeconds(config.BootTimeoutSeconds);
            var isBooted = await _adbClient.WaitForBootCompletedAsync(_deviceSerial, bootTimeout, ct);

            if (!isBooted)
            {
                SetFailure(RuntimeFailureReason.AndroidBootTimeout, $"Android boot_completed timed out after {config.BootTimeoutSeconds}s.");
                return false;
            }

            // 2. 포트 포워딩 설정 (GuestAgent Protobuf 통신용)
            var forwarded = await _adbClient.ForwardPortAsync(_deviceSerial, config.GuestAgentPort, config.GuestAgentPort, ct);
            if (!forwarded)
            {
                _logger?.Log(LogCategory.Runtime, $"Port forwarding failed on port {config.GuestAgentPort}", "WARN");
            }

            // 3. v0.1 Immersive 전체화면 정책 적용
            await _adbClient.ApplyImmersivePolicyAsync(_deviceSerial, ct);

            // 4. Dev Mode: Host가 ADB를 통해 명시적으로 GuestAgent 서비스 기동
            _logger?.Log(LogCategory.Runtime, "Triggering GuestAgent Service start via ADB...");
            await _adbClient.StartGuestAgentServiceAsync(_deviceSerial, ct);

            // 5. Experimental: SurfaceFlinger 저지연/버퍼링 최적화 프로퍼티 주입 및 검증
            if (config.EnableSurfaceFlingerLowLatencyTuning)
            {
                try
                {
                    _logger?.Log(LogCategory.Runtime, "Applying experimental SurfaceFlinger low-latency tuning...");
                    await _adbClient.ExecuteShellCommandAsync(_deviceSerial, "setprop debug.sf.latch_unsignaled 1", ct);
                    await _adbClient.ExecuteShellCommandAsync(_deviceSerial, "setprop debug.sf.disable_backpressure 1", ct);

                    var latchVal = (await _adbClient.ExecuteShellCommandAsync(_deviceSerial, "getprop debug.sf.latch_unsignaled", ct)).Trim();
                    var bpVal = (await _adbClient.ExecuteShellCommandAsync(_deviceSerial, "getprop debug.sf.disable_backpressure", ct)).Trim();

                    if (latchVal == "1" && bpVal == "1")
                    {
                        _logger?.Log(LogCategory.Runtime, "SurfaceFlinger tuning verified and active (latch_unsignaled=1, disable_backpressure=1).");
                    }
                    else
                    {
                        _logger?.Log(LogCategory.Runtime, $"SurfaceFlinger tuning read-back mismatch: latch='{latchVal}', backpressure='{bpVal}'", "WARN");
                    }
                }
                catch (Exception ex)
                {
                    _logger?.Log(LogCategory.Runtime, $"Failed to configure SurfaceFlinger tuning: {ex.Message}", "WARN");
                }
            }

            // 6. Emulator Console 연결
            await _consoleClient.ConnectAsync("127.0.0.1", config.ConsolePort, ct: ct);

            // 6. GuestAgent 연결 및 Handshake 대기 (백그라운드 비동기)
            _ = Task.Run(async () =>
            {
                for (int i = 0; i < 15; i++)
                {
                    if (await _guestClient.ConnectAsync("127.0.0.1", config.GuestAgentPort))
                    {
                        _logger?.Log(LogCategory.Runtime, $"GuestAgent connected and handshaked on port {config.GuestAgentPort} (API: {_guestClient.GuestInfo?.AndroidApiLevel})");
                        break;
                    }
                    await Task.Delay(1000);
                }
            });

            _logger?.Log(LogCategory.Runtime, "Android Runtime is READY.");
            LastDiagnosticMessage = "Runtime ready and operational.";
            _stateMachine.TransitionTo(RuntimeState.Ready);
            return true;
        }
        catch (Exception ex)
        {
            SetFailure(RuntimeFailureReason.UnknownError, $"Unexpected error starting runtime: {ex.Message}", ex);
            return false;
        }
    }

    private void SetFailure(RuntimeFailureReason reason, string message, Exception? ex = null)
    {
        LastFailureReason = reason;
        LastDiagnosticMessage = message;
        _logger?.LogError(LogCategory.Runtime, $"[FAULT] {reason}: {message}", ex);

        _stateMachine.TransitionTo(RuntimeState.Faulted);
        DiagnosticReported?.Invoke(this, new RuntimeDiagnosticInfo
        {
            State = RuntimeState.Faulted,
            FailureReason = reason,
            DiagnosticMessage = message
        });
    }

    private static string ResolveEmulatorBinary(string? specifiedPath)
    {
        if (!string.IsNullOrWhiteSpace(specifiedPath) && File.Exists(specifiedPath))
        {
            return specifiedPath;
        }

        var sdkEmulator = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            @"Android\Sdk\emulator\emulator.exe");

        if (File.Exists(sdkEmulator))
        {
            return sdkEmulator;
        }

        return "emulator";
    }

    public async Task<bool> StopAsync(CancellationToken ct = default)
    {
        if (State == RuntimeState.Stopped || State == RuntimeState.Stopping)
        {
            return true;
        }

        _logger?.Log(LogCategory.Runtime, "Stopping Android Runtime...");
        _stateMachine.TransitionTo(RuntimeState.Stopping);

        try
        {
            await _guestClient.DisconnectAsync();
            await _consoleClient.DisconnectAsync();

            if (_emulatorProcess != null && !_emulatorProcess.HasExited)
            {
                try
                {
                    await _adbClient.ExecuteShellCommandAsync(_deviceSerial, "reboot -p", ct);
                    await _emulatorProcess.WaitForExitAsync(CancellationTokenSource.CreateLinkedTokenSource(ct, new CancellationTokenSource(5000).Token).Token);
                }
                catch
                {
                    if (!_emulatorProcess.HasExited)
                    {
                        _emulatorProcess.Kill(entireProcessTree: true);
                    }
                }
            }

            _logger?.Log(LogCategory.Runtime, "Android Runtime stopped successfully.");
            _stateMachine.TransitionTo(RuntimeState.Stopped);
            return true;
        }
        catch (Exception ex)
        {
            SetFailure(RuntimeFailureReason.UnknownError, $"Error stopping runtime: {ex.Message}", ex);
            return false;
        }
        finally
        {
            _emulatorProcess?.Dispose();
            _emulatorProcess = null;
        }
    }

    public async Task<bool> SuspendAsync(CancellationToken ct = default)
    {
        if (State != RuntimeState.Ready) return false;

        _logger?.Log(LogCategory.Runtime, "Suspending Android instance (Screen off)...");
        await _adbClient.ExecuteShellCommandAsync(_deviceSerial, "input keyevent 26", ct);
        _stateMachine.TransitionTo(RuntimeState.Suspended);
        return true;
    }

    public async Task<bool> ResumeAsync(CancellationToken ct = default)
    {
        if (State != RuntimeState.Suspended) return false;

        _logger?.Log(LogCategory.Runtime, "Resuming Android instance (Wakeup)...");
        await _adbClient.ExecuteShellCommandAsync(_deviceSerial, "input keyevent 224", ct);
        _stateMachine.TransitionTo(RuntimeState.Ready);
        return true;
    }

    private void OnEmulatorProcessExited(object? sender, EventArgs e)
    {
        _logger?.Log(LogCategory.Runtime, "Emulator process exited.");
        _stateMachine.TransitionTo(RuntimeState.Stopped);
    }

    public async ValueTask DisposeAsync()
    {
        await StopAsync();
        GC.SuppressFinalize(this);
    }
}
