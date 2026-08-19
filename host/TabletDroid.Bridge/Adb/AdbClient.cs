using System.Diagnostics;
using System.Text;

namespace TabletDroid.Bridge.Adb;

public class AdbClient : IAdbClient
{
    private readonly string _adbPath;

    public AdbClient(string? adbPath = null)
    {
        _adbPath = !string.IsNullOrWhiteSpace(adbPath) ? adbPath : ResolveAdbPath();
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

        return (process.ExitCode, await outputTask, await errorTask);
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
        catch
        {
            return false;
        }
    }

    public async Task<bool> WaitForBootCompletedAsync(string deviceSerial, TimeSpan timeout, CancellationToken ct = default)
    {
        var sw = Stopwatch.StartNew();
        while (sw.Elapsed < timeout && !ct.IsCancellationRequested)
        {
            try
            {
                var (exitCode, output, _) = await RunAdbAsync($"-s {deviceSerial} shell getprop sys.boot_completed", ct);
                if (exitCode == 0 && output.Trim() == "1")
                {
                    return true;
                }
            }
            catch
            {
                // 부팅 중 ADB 연결 시도 간 오류는 무시하고 재시도
            }

            await Task.Delay(1000, ct);
        }

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
                // 기본 런처 액티비티 자동 실행 (monkey 유틸 활용)
                cmd = $"-s {deviceSerial} shell monkey -p {packageName} -c android.intent.category.LAUNCHER 1";
            }

            var (exitCode, output, _) = await RunAdbAsync(cmd, ct);
            return exitCode == 0 && !output.Contains("Error");
        }
        catch
        {
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
        catch
        {
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
        catch
        {
            return false;
        }
    }

    public async Task<bool> ApplyImmersivePolicyAsync(string deviceSerial, CancellationToken ct = default)
    {
        try
        {
            // v0.1 임시 workaround: 모든 앱에 상태바/네비게이션바 숨김 정책 주입
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
