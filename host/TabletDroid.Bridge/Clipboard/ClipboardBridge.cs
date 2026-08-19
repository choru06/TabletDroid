using System.Security.Cryptography;
using System.Text;
using TabletDroid.Bridge.Guest;
using TabletDroid.Protocol;

namespace TabletDroid.Bridge.Clipboard;

public interface IClipboardBridge
{
    void Start();
    void Stop();
    Task HandleWindowsClipboardChangedAsync(string text);
    event EventHandler<string>? AndroidClipboardReceived;
}

public class ClipboardBridge : IClipboardBridge
{
    private readonly IGuestAgentClient _guestClient;
    private long _revisionCounter = 0;
    private string _lastSentHash = string.Empty;
    private string _lastReceivedHash = string.Empty;
    private bool _isRunning = false;

    public event EventHandler<string>? AndroidClipboardReceived;

    public ClipboardBridge(IGuestAgentClient guestClient)
    {
        _guestClient = guestClient;
    }

    public void Start()
    {
        if (_isRunning) return;
        _isRunning = true;
        _guestClient.ClipboardSyncReceived += OnGuestClipboardSyncReceived;
    }

    public void Stop()
    {
        if (!_isRunning) return;
        _isRunning = false;
        _guestClient.ClipboardSyncReceived -= OnGuestClipboardSyncReceived;
    }

    public async Task HandleWindowsClipboardChangedAsync(string text)
    {
        if (!_isRunning || string.IsNullOrEmpty(text)) return;

        var hash = ComputeHash(text);
        // 방금 Android로부터 수신된 내용과 동일하면 다시 보낼 필요 없음 (Echo Loop 방지)
        if (hash == _lastReceivedHash || hash == _lastSentHash)
        {
            return;
        }

        _lastSentHash = hash;
        var rev = Interlocked.Increment(ref _revisionCounter);

        await _guestClient.SendClipboardAsync(text, rev);
    }

    private void OnGuestClipboardSyncReceived(object? sender, ClipboardSyncEvent e)
    {
        if (!_isRunning || string.IsNullOrEmpty(e.TextContent)) return;

        // Windows가 보낸 것이 돌아온 경우 무시
        if (e.Source == ClipboardSource.SourceWindows) return;

        var hash = ComputeHash(e.TextContent);
        if (hash == _lastSentHash) return;

        _lastReceivedHash = hash;
        AndroidClipboardReceived?.Invoke(this, e.TextContent);
    }

    public static string ComputeHash(string input)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(input));
        return Convert.ToHexString(bytes);
    }
}
