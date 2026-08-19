using System.Net.Sockets;
using System.Text;

namespace TabletDroid.Bridge.Emulator;

public class EmulatorConsoleClient : IEmulatorConsoleClient
{
    private TcpClient? _tcpClient;
    private NetworkStream? _stream;
    private readonly SemaphoreSlim _semaphore = new(1, 1);

    public bool IsConnected => _tcpClient?.Connected ?? false;

    public async Task<bool> ConnectAsync(string host = "127.0.0.1", int port = 5554, string? authToken = null, CancellationToken ct = default)
    {
        await _semaphore.WaitAsync(ct);
        try
        {
            _tcpClient = new TcpClient();
            await _tcpClient.ConnectAsync(host, port, ct);
            _stream = _tcpClient.GetStream();

            // 환영 메시지 수신 대기
            var welcome = await ReadResponseAsync(ct);

            // Auth 토큰 해결 및 인증 수행
            var token = authToken ?? ResolveAuthToken();
            if (!string.IsNullOrWhiteSpace(token))
            {
                var authResp = await SendRawCommandAsync($"auth {token}", ct);
                if (!authResp.Contains("OK"))
                {
                    return false;
                }
            }

            return true;
        }
        catch
        {
            await CleanupAsync();
            return false;
        }
        finally
        {
            _semaphore.Release();
        }
    }

    private static string? ResolveAuthToken()
    {
        var tokenPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            ".emulator_console_auth_token");

        if (File.Exists(tokenPath))
        {
            try
            {
                return File.ReadAllText(tokenPath).Trim();
            }
            catch
            {
                // ignore
            }
        }

        return null;
    }

    public async Task<bool> RotateAsync(int angle, CancellationToken ct = default)
    {
        // Emulator console 지원 회전값: 0, 90, 180, 270 (또는 0, 1, 2, 3)
        var resp = await SendCommandAsync($"rotate {angle}", ct);
        return resp.Contains("OK");
    }

    public async Task<bool> SetOrientationSensorAsync(float x, float y, float z, CancellationToken ct = default)
    {
        var resp = await SendCommandAsync($"sensor set orientation {x}:{y}:{z}", ct);
        return resp.Contains("OK");
    }

    public async Task<string> SendCommandAsync(string command, CancellationToken ct = default)
    {
        await _semaphore.WaitAsync(ct);
        try
        {
            return await SendRawCommandAsync(command, ct);
        }
        finally
        {
            _semaphore.Release();
        }
    }

    private async Task<string> SendRawCommandAsync(string command, CancellationToken ct)
    {
        if (_stream == null || !IsConnected)
        {
            throw new InvalidOperationException("Emulator console is not connected.");
        }

        var data = Encoding.ASCII.GetBytes(command + "\r\n");
        await _stream.WriteAsync(data, ct);
        await _stream.FlushAsync(ct);

        return await ReadResponseAsync(ct);
    }

    private async Task<string> ReadResponseAsync(CancellationToken ct)
    {
        if (_stream == null) return string.Empty;

        var buffer = new byte[4096];
        var sb = new StringBuilder();

        // Console 출력 끝 부분 ("OK" or "KO: ..." or 프롬프트) 확인
        while (true)
        {
            var read = await _stream.ReadAsync(buffer, ct);
            if (read == 0) break;

            var chunk = Encoding.ASCII.GetString(buffer, 0, read);
            sb.Append(chunk);

            if (chunk.Contains("OK\r\n") || chunk.Contains("KO: ") || chunk.Contains("OK\n") || chunk.EndsWith("OK"))
            {
                break;
            }

            if (!_stream.DataAvailable)
            {
                break;
            }
        }

        return sb.ToString();
    }

    public async Task DisconnectAsync()
    {
        await _semaphore.WaitAsync();
        try
        {
            await CleanupAsync();
        }
        finally
        {
            _semaphore.Release();
        }
    }

    private Task CleanupAsync()
    {
        try
        {
            _stream?.Dispose();
            _tcpClient?.Dispose();
        }
        catch
        {
            // ignore
        }
        finally
        {
            _stream = null;
            _tcpClient = null;
        }

        return Task.CompletedTask;
    }

    public async ValueTask DisposeAsync()
    {
        await DisconnectAsync();
        _semaphore.Dispose();
        GC.SuppressFinalize(this);
    }
}
