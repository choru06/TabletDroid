namespace TabletDroid.Bridge.Emulator;

public interface IEmulatorConsoleClient : IAsyncDisposable
{
    bool IsConnected { get; }
    Task<bool> ConnectAsync(string host = "127.0.0.1", int port = 5554, string? authToken = null, CancellationToken ct = default);
    Task<bool> RotateAsync(int angle, CancellationToken ct = default);
    Task<bool> SetOrientationSensorAsync(float x, float y, float z, CancellationToken ct = default);
    Task<string> SendCommandAsync(string command, CancellationToken ct = default);
    Task DisconnectAsync();
}
