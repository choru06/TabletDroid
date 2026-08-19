namespace TabletDroid.Bridge.Window;

public interface IWindowEmbedderService : IDisposable
{
    bool IsEmbedded { get; }
    IntPtr EmbeddedHwnd { get; }
    IntPtr OriginalParentHwnd { get; }
    long OriginalStyle { get; }
    long OriginalExStyle { get; }

    Task<bool> EmbedWindowAsync(IntPtr hostContainerHwnd, string processName = "qemu-system-x86_64", CancellationToken ct = default);
    bool DetachWindow();
    bool UpdateViewport(int x, int y, int width, int height);
}
