using System.Diagnostics;
using System.Text;
using TabletDroid.Bridge.Adb;
using TabletDroid.Bridge.Emulator;
using TabletDroid.Bridge.Guest;
using TabletDroid.Core.Models;

namespace TabletDroid.Runtime;

public class AndroidEmulatorBackend : IRuntimeBackend
{
    private readonly IAdbClient _adbClient;
    private readonly IEmulatorConsoleClient _consoleClient;
    private readonly IGuestAgentClient _guestClient;
    private readonly RuntimeStateMachine _stateMachine = new();

    private Process? _emulatorProcess;
    private RuntimeConfiguration? _currentConfig;
    private readonly string _deviceSerial = "emulator-5554";

    public RuntimeState State => _stateMachine.CurrentState;
    public RuntimeConfiguration? CurrentConfig => _currentConfig;
    public event EventHandler<RuntimeState>? StateChanged;

    public AndroidEmulatorBackend(
        IAdbClient adbClient,
        IEmulatorConsoleClient consoleClient,
        IGuestAgentClient guestClient)
    {
        _adbClient = adbClient;
        _consoleClient = consoleClient;
        _guestClient = guestClient;

        _stateMachine.StateChanged += (s, e) => StateChanged?.Invoke(this, e);
    }

    public async Task<bool> StartAsync(RuntimeConfiguration config, CancellationToken ct = default)
    {
        if (State != RuntimeState.Stopped && State != RuntimeState.Faulted)
        {
            return false;
        }

        _currentConfig = config;
        _stateMachine.TransitionTo(RuntimeState.Starting);

        try
        {
            var emulatorBinary = ResolveEmulatorBinary(config.EmulatorBinaryPath);
            if (!File.Exists(emulatorBinary) && emulatorBinary != "emulator")
            {
                throw new FileNotFoundException($"Android Emulator binary not found: {emulatorBinary}");
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
                CreateNoWindow = false // 초기 실행 시 창 표시
            };

            _emulatorProcess = new Process { StartInfo = psi, EnableRaisingEvents = true };
            _emulatorProcess.Exited += OnEmulatorProcessExited;

            if (!_emulatorProcess.Start())
            {
                _stateMachine.TransitionTo(RuntimeState.Faulted);
                return false;
            }

            _stateMachine.TransitionTo(RuntimeState.Booting);

            // ADB Boot 완료 대기
            var bootTimeout = TimeSpan.FromSeconds(config.BootTimeoutSeconds);
            var isBooted = await _adbClient.WaitForBootCompletedAsync(_deviceSerial, bootTimeout, ct);

            if (!isBooted)
            {
                _stateMachine.TransitionTo(RuntimeState.Faulted);
                return false;
            }

            // 포트 포워딩 설정 (GuestAgent Protobuf 통신용)
            await _adbClient.ForwardPortAsync(_deviceSerial, config.GuestAgentPort, config.GuestAgentPort, ct);

            // v0.1 Immersive 정책 적용
            await _adbClient.ApplyImmersivePolicyAsync(_deviceSerial, ct);

            // Emulator Console 연결
            await _consoleClient.ConnectAsync("127.0.0.1", config.ConsolePort, ct: ct);

            // GuestAgent 연결 시도 (백그라운드)
            _ = Task.Run(async () =>
            {
                for (int i = 0; i < 10; i++)
                {
                    if (await _guestClient.ConnectAsync("127.0.0.1", config.GuestAgentPort))
                    {
                        break;
                    }
                    await Task.Delay(1000);
                }
            });

            _stateMachine.TransitionTo(RuntimeState.Ready);
            return true;
        }
        catch
        {
            _stateMachine.TransitionTo(RuntimeState.Faulted);
            return false;
        }
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

        _stateMachine.TransitionTo(RuntimeState.Stopping);

        try
        {
            await _guestClient.DisconnectAsync();
            await _consoleClient.DisconnectAsync();

            if (_emulatorProcess != null && !_emulatorProcess.HasExited)
            {
                // 콘솔 또는 ADB를 통한 우아한 종료 시도
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

            _stateMachine.TransitionTo(RuntimeState.Stopped);
            return true;
        }
        catch
        {
            _stateMachine.TransitionTo(RuntimeState.Faulted);
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

        // 절전 모드 전환 (화면 끄기 또는 snapshot save)
        await _adbClient.ExecuteShellCommandAsync(_deviceSerial, "input keyevent 26", ct); // POWER key
        _stateMachine.TransitionTo(RuntimeState.Suspended);
        return true;
    }

    public async Task<bool> ResumeAsync(CancellationToken ct = default)
    {
        if (State != RuntimeState.Suspended) return false;

        // 화면 켜기
        await _adbClient.ExecuteShellCommandAsync(_deviceSerial, "input keyevent 224", ct); // WAKEUP key
        _stateMachine.TransitionTo(RuntimeState.Ready);
        return true;
    }

    private void OnEmulatorProcessExited(object? sender, EventArgs e)
    {
        _stateMachine.TransitionTo(RuntimeState.Stopped);
    }

    public async ValueTask DisposeAsync()
    {
        await StopAsync();
        GC.SuppressFinalize(this);
    }
}
