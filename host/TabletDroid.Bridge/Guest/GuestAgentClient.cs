using System.Buffers.Binary;
using System.Collections.Concurrent;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text;
using Google.Protobuf;
using TabletDroid.Protocol;

namespace TabletDroid.Bridge.Guest;

public interface IGuestAgentClient : IAsyncDisposable
{
    bool IsConnected { get; }
    bool IsReady { get; }
    HandshakeResponse? GuestInfo { get; }

    event EventHandler<ClipboardSyncEvent>? ClipboardSyncReceived;
    event EventHandler<AppLifecycleEvent>? AppLifecycleReceived;
    event EventHandler<OrientationChangedEvent>? OrientationChangedReceived;
    event EventHandler<bool>? ReadyStateChanged;

    Task<bool> ConnectAsync(string host = "127.0.0.1", int port = 28888, CancellationToken ct = default);
    Task SendMessageAsync(TabletDroidMessage message, CancellationToken ct = default);
    Task<TabletDroidMessage?> SendRequestAsync(TabletDroidMessage request, TimeSpan timeout, CancellationToken ct = default);
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
    private readonly ConcurrentDictionary<string, TaskCompletionSource<TabletDroidMessage>> _pendingRequests = new();

    private bool _isReady = false;
    private HandshakeResponse? _guestInfo;

    public bool IsConnected => _tcpClient?.Connected ?? false;
    public bool IsReady => _isReady && IsConnected;
    public HandshakeResponse? GuestInfo => _guestInfo;

    public event EventHandler<ClipboardSyncEvent>? ClipboardSyncReceived;
    public event EventHandler<AppLifecycleEvent>? AppLifecycleReceived;
    public event EventHandler<OrientationChangedEvent>? OrientationChangedReceived;
    public event EventHandler<bool>? ReadyStateChanged;

    public async Task<bool> ConnectAsync(string host = "127.0.0.1", int port = 28888, CancellationToken ct = default)
    {
        try
        {
            _tcpClient = new TcpClient();
            await _tcpClient.ConnectAsync(host, port, ct);
            _stream = _tcpClient.GetStream();

            _receiveCts = new CancellationTokenSource();
            _ = Task.Run(() => ReceiveLoopAsync(_receiveCts.Token));

            // 핸드셰이크 요청 전송 및 응답 대기 (진짜 Ready 상태 보장)
            var handshakeReq = new TabletDroidMessage
            {
                MessageId = Guid.NewGuid().ToString(),
                Timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                HandshakeRequest = new HandshakeRequest
                {
                    HostVersion = "0.1.0",
                    OsVersion = Environment.OSVersion.ToString()
                }
            };

            var response = await SendRequestAsync(handshakeReq, TimeSpan.FromSeconds(5), ct);
            if (response != null && response.PayloadCase == TabletDroidMessage.PayloadOneofCase.HandshakeResponse)
            {
                _guestInfo = response.HandshakeResponse;
                _isReady = true;
                ReadyStateChanged?.Invoke(this, true);
                return true;
            }

            return false;
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

    public async Task<TabletDroidMessage?> SendRequestAsync(TabletDroidMessage request, TimeSpan timeout, CancellationToken ct = default)
    {
        var tcs = new TaskCompletionSource<TabletDroidMessage>(TaskCreationOptions.RunContinuationsAsynchronously);
        _pendingRequests[request.MessageId] = tcs;

        try
        {
            await SendMessageAsync(request, ct);

            using var cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
            cts.CancelAfter(timeout);

            using (cts.Token.Register(() => tcs.TrySetCanceled()))
            {
                return await tcs.Task;
            }
        }
        catch
        {
            return null;
        }
        finally
        {
            _pendingRequests.TryRemove(request.MessageId, out _);
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

            // RPC Request-Response Correlation 대기
            var response = await SendRequestAsync(msg, TimeSpan.FromSeconds(5), ct);
            if (response != null && response.PayloadCase == TabletDroidMessage.PayloadOneofCase.LaunchAppResponse)
            {
                return response.LaunchAppResponse.Success;
            }

            return false;
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
                if (!await ReadExactAsync(_stream, headerBuffer, 4, ct))
                {
                    break;
                }

                var length = BinaryPrimitives.ReadUInt32BigEndian(headerBuffer);
                if (length == 0 || length > 16 * 1024 * 1024)
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
            // socket error
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
        // 1. Reply_to가 있는 RPC 응답인 경우 TCS 완료 처리
        if (!string.IsNullOrEmpty(message.ReplyTo) && _pendingRequests.TryGetValue(message.ReplyTo, out var tcs))
        {
            tcs.TrySetResult(message);
        }

        // 2. 이벤트 디스패치
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
        _isReady = false;
        ReadyStateChanged?.Invoke(this, false);

        foreach (var tcs in _pendingRequests.Values)
        {
            tcs.TrySetCanceled();
        }
        _pendingRequests.Clear();

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
