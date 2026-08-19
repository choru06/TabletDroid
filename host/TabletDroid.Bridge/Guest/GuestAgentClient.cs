using System.Buffers.Binary;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text;
using Google.Protobuf;
using TabletDroid.Protocol;

namespace TabletDroid.Bridge.Guest;

public interface IGuestAgentClient : IAsyncDisposable
{
    bool IsConnected { get; }
    event EventHandler<ClipboardSyncEvent>? ClipboardSyncReceived;
    event EventHandler<AppLifecycleEvent>? AppLifecycleReceived;
    event EventHandler<OrientationChangedEvent>? OrientationChangedReceived;

    Task<bool> ConnectAsync(string host = "127.0.0.1", int port = 28888, CancellationToken ct = default);
    Task SendMessageAsync(TabletDroidMessage message, CancellationToken ct = default);
    Task<bool> SendClipboardAsync(string text, long revisionId, CancellationToken ct = default);
    Task<bool> SendOrientationAsync(DeviceOrientation orientation, bool lockOrientation = false, CancellationToken ct = default);
    Task<bool> SendLaunchAppAsync(string packageName, string? activityName = null, CancellationToken ct = default);
    Task DisconnectAsync();
}

public class GuestAgentClient : IGuestAgentClient
{
    private TcpClient? _tcpClient;
    private NetworkStream? _stream;
    private CancellationTokenSource? _receiveCts;
    private readonly SemaphoreSlim _sendLock = new(1, 1);

    public bool IsConnected => _tcpClient?.Connected ?? false;

    public event EventHandler<ClipboardSyncEvent>? ClipboardSyncReceived;
    public event EventHandler<AppLifecycleEvent>? AppLifecycleReceived;
    public event EventHandler<OrientationChangedEvent>? OrientationChangedReceived;

    public async Task<bool> ConnectAsync(string host = "127.0.0.1", int port = 28888, CancellationToken ct = default)
    {
        try
        {
            _tcpClient = new TcpClient();
            await _tcpClient.ConnectAsync(host, port, ct);
            _stream = _tcpClient.GetStream();

            _receiveCts = new CancellationTokenSource();
            _ = Task.Run(() => ReceiveLoopAsync(_receiveCts.Token));

            // 핸드셰이크 요청 전송
            var handshake = new TabletDroidMessage
            {
                MessageId = Guid.NewGuid().ToString(),
                Timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                HandshakeRequest = new HandshakeRequest
                {
                    HostVersion = "0.2.0",
                    OsVersion = Environment.OSVersion.ToString()
                }
            };
            await SendMessageAsync(handshake, ct);

            return true;
        }
        catch
        {
            await DisconnectAsync();
            return false;
        }
    }

    public async Task SendMessageAsync(TabletDroidMessage message, CancellationToken ct = default)
    {
        if (_stream == null || !IsConnected)
        {
            throw new InvalidOperationException("GuestAgent is not connected.");
        }

        var payload = message.ToByteArray();
        var lengthHeader = new byte[4];
        BinaryPrimitives.WriteUInt32BigEndian(lengthHeader, (uint)payload.Length);

        await _sendLock.WaitAsync(ct);
        try
        {
            await _stream.WriteAsync(lengthHeader, ct);
            await _stream.WriteAsync(payload, ct);
            await _stream.FlushAsync(ct);
        }
        finally
        {
            _sendLock.Release();
        }
    }

    public async Task<bool> SendClipboardAsync(string text, long revisionId, CancellationToken ct = default)
    {
        try
        {
            var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(text)));
            var msg = new TabletDroidMessage
            {
                MessageId = Guid.NewGuid().ToString(),
                Timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                ClipboardSync = new ClipboardSyncEvent
                {
                    RevisionId = revisionId,
                    Source = ClipboardSource.SourceWindows,
                    ContentHash = hash,
                    TextContent = text
                }
            };

            await SendMessageAsync(msg, ct);
            return true;
        }
        catch
        {
            return false;
        }
    }

    public async Task<bool> SendOrientationAsync(DeviceOrientation orientation, bool lockOrientation = false, CancellationToken ct = default)
    {
        try
        {
            var msg = new TabletDroidMessage
            {
                MessageId = Guid.NewGuid().ToString(),
                Timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                SetOrientation = new SetOrientationRequest
                {
                    Orientation = orientation,
                    LockOrientation = lockOrientation
                }
            };

            await SendMessageAsync(msg, ct);
            return true;
        }
        catch
        {
            return false;
        }
    }

    public async Task<bool> SendLaunchAppAsync(string packageName, string? activityName = null, CancellationToken ct = default)
    {
        try
        {
            var msg = new TabletDroidMessage
            {
                MessageId = Guid.NewGuid().ToString(),
                Timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                LaunchApp = new LaunchAppRequest
                {
                    PackageName = packageName,
                    ActivityName = activityName ?? string.Empty,
                    ForceStopFirst = false
                }
            };

            await SendMessageAsync(msg, ct);
            return true;
        }
        catch
        {
            return false;
        }
    }

    private async Task ReceiveLoopAsync(CancellationToken ct)
    {
        var headerBuffer = new byte[4];

        try
        {
            while (!ct.IsCancellationRequested && _stream != null)
            {
                // 4바이트 길이 헤더 읽기
                if (!await ReadExactAsync(_stream, headerBuffer, 4, ct))
                {
                    break;
                }

                var length = BinaryPrimitives.ReadUInt32BigEndian(headerBuffer);
                if (length == 0 || length > 16 * 1024 * 1024) // 16MB 제한
                {
                    break;
                }

                var payloadBuffer = new byte[length];
                if (!await ReadExactAsync(_stream, payloadBuffer, (int)length, ct))
                {
                    break;
                }

                var message = TabletDroidMessage.Parser.ParseFrom(payloadBuffer);
                DispatchMessage(message);
            }
        }
        catch
        {
            // 수신 중 오류 발생 시 루프 종료
        }
        finally
        {
            await DisconnectAsync();
        }
    }

    private static async Task<bool> ReadExactAsync(NetworkStream stream, byte[] buffer, int count, CancellationToken ct)
    {
        var offset = 0;
        while (offset < count)
        {
            var read = await stream.ReadAsync(buffer.AsMemory(offset, count - offset), ct);
            if (read == 0) return false;
            offset += read;
        }
        return true;
    }

    private void DispatchMessage(TabletDroidMessage message)
    {
        switch (message.PayloadCase)
        {
            case TabletDroidMessage.PayloadOneofCase.ClipboardSync:
                ClipboardSyncReceived?.Invoke(this, message.ClipboardSync);
                break;
            case TabletDroidMessage.PayloadOneofCase.AppLifecycle:
                AppLifecycleReceived?.Invoke(this, message.AppLifecycle);
                break;
            case TabletDroidMessage.PayloadOneofCase.OrientationChanged:
                OrientationChangedReceived?.Invoke(this, message.OrientationChanged);
                break;
        }
    }

    public async Task DisconnectAsync()
    {
        try
        {
            _receiveCts?.Cancel();
            _receiveCts?.Dispose();
            _receiveCts = null;

            _stream?.Dispose();
            _tcpClient?.Dispose();
            _stream = null;
            _tcpClient = null;
        }
        catch
        {
            // ignore
        }

        await Task.CompletedTask;
    }

    public async ValueTask DisposeAsync()
    {
        await DisconnectAsync();
        _sendLock.Dispose();
        GC.SuppressFinalize(this);
    }
}
