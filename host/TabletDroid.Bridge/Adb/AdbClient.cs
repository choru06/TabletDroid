using System.Diagnostics;
using System.Text;
using TabletDroid.Core.Services;

namespace TabletDroid.Bridge.Adb;

public class AdbClient : IAdbClient
{
    private readonly string _adbPath;
    private readonly IDiagnosticLogService? _logger;

    public AdbClient(string? adbPath = null, IDiagnosticLogService? logger = null)
    {
        _adbPath = !string.IsNullOrWhiteSpace(adbPath) ? adbPath : ResolveAdbPath();
        _logger = logger;
    }

    private static string ResolveAdbPath()
    {
        var localSdk = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            @"Android\Sdk\platform-tools\adb.exe");

        if (File.Exists(localSdk))
        {
            return localSdk;
        }

        return "adb";
    }

    private async Task<(int ExitCode, string Output, string Error)> RunAdbAsync(string arguments, CancellationToken ct = default)
    {
        _logger?.Log(LogCategory.Adb, $"Running: {_adbPath} {arguments}");

        var psi = new ProcessStartInfo
        {
            FileName = _adbPath,
            Arguments = arguments,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8
        };

        using var process = new Process { StartInfo = psi };
        process.Start();

        var outputTask = process.StandardOutput.ReadToEndAsync(ct);
        var errorTask = process.StandardError.ReadToEndAsync(ct);

        await process.WaitForExitAsync(ct);

        var output = await outputTask;
        var error = await errorTask;

        if (process.ExitCode != 0)
        {
            _logger?.Log(LogCategory.Adb, $"ExitCode: {process.ExitCode} | Error: {error.Trim()}", "WARN");
        }
        else
        {
            _logger?.Log(LogCategory.Adb, $"Output: {output.Trim()}");
        }

        return (process.ExitCode, output, error);
    }

    public async Task<bool> IsDeviceConnectedAsync(string deviceSerial, CancellationToken ct = default)
    {
        try
        {
            var (exitCode, output, _) = await RunAdbAsync("devices", ct);
            if (exitCode != 0) return false;

            var lines = output.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);
            return lines.Any(l => l.StartsWith(deviceSerial) && l.Contains("device"));
        }
        catch (Exception ex)
        {
            _logger?.LogError(LogCategory.Adb, "IsDeviceConnectedAsync failed", ex);
            return false;
        }
    }

    public async Task<bool> WaitForBootCompletedAsync(string deviceSerial, TimeSpan timeout, CancellationToken ct = default)
    {
        _logger?.Log(LogCategory.Adb, $"Waiting for boot_completed on {deviceSerial} (timeout: {timeout.TotalSeconds}s)...");
        var sw = Stopwatch.StartNew();

        while (sw.Elapsed < timeout && !ct.IsCancellationRequested)
        {
            try
            {
                var (exitCode, output, _) = await RunAdbAsync($"-s {deviceSerial} shell getprop sys.boot_completed", ct);
                if (exitCode == 0 && output.Trim() == "1")
                {
                    _logger?.Log(LogCategory.Adb, $"Android on {deviceSerial} reported sys.boot_completed=1 in {sw.Elapsed.TotalSeconds:F1}s.");
                    return true;
                }
            }
            catch
            {
                // 부팅 초기 ADB 연결 시도 간 오류 무시
            }

            await Task.Delay(1000, ct);
        }

        _logger?.Log(LogCategory.Adb, $"Boot completed timed out for {deviceSerial}.", "ERROR");
        return false;
    }

    public async Task<string> ExecuteShellCommandAsync(string deviceSerial, string command, CancellationToken ct = default)
    {
        var (_, output, _) = await RunAdbAsync($"-s {deviceSerial} shell {command}", ct);
        return output.Trim();
    }

    public async Task<bool> LaunchAppAsync(string deviceSerial, string packageName, string? activityName = null, CancellationToken ct = default)
    {
        try
        {
            string cmd;
            if (!string.IsNullOrWhiteSpace(activityName))
            {
                cmd = $"-s {deviceSerial} shell am start -n {packageName}/{activityName}";
            }
            else
            {
                cmd = $"-s {deviceSerial} shell monkey -p {packageName} -c android.intent.category.LAUNCHER 1";
            }

            var (exitCode, output, _) = await RunAdbAsync(cmd, ct);
            return exitCode == 0 && !output.Contains("Error") && !output.Contains("No activities found");
        }
        catch (Exception ex)
        {
            _logger?.LogError(LogCategory.Adb, $"LaunchAppAsync failed for {packageName}", ex);
            return false;
        }
    }

    public async Task<bool> IsAppInstalledAsync(string deviceSerial, string packageName, CancellationToken ct = default)
    {
        try
        {
            var (exitCode, output, _) = await RunAdbAsync($"-s {deviceSerial} shell pm path {packageName}", ct);
            return exitCode == 0 && output.Contains("package:");
        }
        catch
        {
            return false;
        }
    }

    public async Task<bool> StartGuestAgentServiceAsync(string deviceSerial, CancellationToken ct = default)
    {
        try
        {
            _logger?.Log(LogCategory.Adb, $"Starting GuestAgent service on {deviceSerial} via ADB...");
            // Dev 모드: startservice 또는 start-foreground-service 호출
            var (exitCode, output, _) = await RunAdbAsync(
                $"-s {deviceSerial} shell am startservice -n com.tabletdroid.guestagent/.GuestService", ct);

            if (exitCode != 0 || output.Contains("Error"))
            {
                // Foreground service 대안 시도
                var (fExit, fOut, _) = await RunAdbAsync(
                    $"-s {deviceSerial} shell am start-foreground-service -n com.tabletdroid.guestagent/.GuestService", ct);
                return fExit == 0 && !fOut.Contains("Error");
            }

            return true;
        }
        catch (Exception ex)
        {
            _logger?.LogError(LogCategory.Adb, "Failed to start GuestAgent service via ADB", ex);
            return false;
        }
    }

    public async Task<bool> InstallApkAsync(string deviceSerial, string apkPath, CancellationToken ct = default)
    {
        try
        {
            var (exitCode, output, _) = await RunAdbAsync($"-s {deviceSerial} install -r \"{apkPath}\"", ct);
            return exitCode == 0 && output.Contains("Success");
        }
        catch (Exception ex)
        {
            _logger?.LogError(LogCategory.Adb, $"InstallApkAsync failed for {apkPath}", ex);
            return false;
        }
    }

    public async Task<bool> ForwardPortAsync(string deviceSerial, int hostPort, int guestPort, CancellationToken ct = default)
    {
        try
        {
            var (exitCode, _, _) = await RunAdbAsync($"-s {deviceSerial} forward tcp:{hostPort} tcp:{guestPort}", ct);
            return exitCode == 0;
        }
        catch (Exception ex)
        {
            _logger?.LogError(LogCategory.Adb, $"ForwardPortAsync failed (host:{hostPort} -> guest:{guestPort})", ex);
            return false;
        }
    }

    public async Task<bool> ApplyImmersivePolicyAsync(string deviceSerial, CancellationToken ct = default)
    {
        try
        {
            var (exitCode, _, _) = await RunAdbAsync(
                $"-s {deviceSerial} shell settings put global policy_control immersive.full=*", ct);
            return exitCode == 0;
        }
        catch
        {
            return false;
        }
    }
}
