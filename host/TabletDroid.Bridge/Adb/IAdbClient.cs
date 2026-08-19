namespace TabletDroid.Bridge.Adb;

public interface IAdbClient
{
    Task<bool> IsDeviceConnectedAsync(string deviceSerial, CancellationToken ct = default);
    Task<bool> WaitForBootCompletedAsync(string deviceSerial, TimeSpan timeout, CancellationToken ct = default);
    Task<string> ExecuteShellCommandAsync(string deviceSerial, string command, CancellationToken ct = default);
    Task<bool> LaunchAppAsync(string deviceSerial, string packageName, string? activityName = null, CancellationToken ct = default);
    Task<bool> InstallApkAsync(string deviceSerial, string apkPath, CancellationToken ct = default);
    Task<bool> ForwardPortAsync(string deviceSerial, int hostPort, int guestPort, CancellationToken ct = default);
    Task<bool> ApplyImmersivePolicyAsync(string deviceSerial, CancellationToken ct = default);
}
