using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using TabletDroid.Core.Models;
using TabletDroid.Core.Services;

namespace TabletDroid.Bridge.Window;

public class Win32WindowEmbedderService : IWindowEmbedderService
{
    private readonly IDiagnosticLogService? _logger;
    private readonly object _lock = new();

    private IntPtr _hostHwnd = IntPtr.Zero;
    private IntPtr _embeddedHwnd = IntPtr.Zero;
    private IntPtr _originalParentHwnd = IntPtr.Zero;
    private long _originalStyle = 0;
    private long _originalExStyle = 0;
    private bool _isEmbedded = false;

    public bool IsEmbedded => _isEmbedded;
    public IntPtr EmbeddedHwnd => _embeddedHwnd;
    public IntPtr OriginalParentHwnd => _originalParentHwnd;
    public long OriginalStyle => _originalStyle;
    public long OriginalExStyle => _originalExStyle;

    #region Win32 Constants & Flags

    public const int GWL_STYLE = -16;
    public const int GWL_EXSTYLE = -20;

    public const long WS_POPUP = 0x80000000L;
    public const long WS_CHILD = 0x40000000L;
    public const long WS_VISIBLE = 0x10000000L;
    public const long WS_CAPTION = 0x00C00000L;
    public const long WS_BORDER = 0x00800000L;
    public const long WS_DLGFRAME = 0x00400000L;
    public const long WS_SYSMENU = 0x00080000L;
    public const long WS_THICKFRAME = 0x00040000L;
    public const long WS_MINIMIZEBOX = 0x00020000L;
    public const long WS_MAXIMIZEBOX = 0x00010000L;

    public const long WS_EX_DLGMODALFRAME = 0x00000001L;
    public const long WS_EX_NOPARENTNOTIFY = 0x00000004L;
    public const long WS_EX_WINDOWEDGE = 0x00000100L;
    public const long WS_EX_CLIENTEDGE = 0x00000200L;
    public const long WS_EX_STATICEDGE = 0x00020000L;
    public const long WS_EX_APPWINDOW = 0x00040000L;

    public const uint SWP_NOSIZE = 0x0001;
    public const uint SWP_NOMOVE = 0x0002;
    public const uint SWP_NOZORDER = 0x0004;
    public const uint SWP_NOREDRAW = 0x0008;
    public const uint SWP_NOACTIVATE = 0x0010;
    public const uint SWP_FRAMECHANGED = 0x0020;
    public const uint SWP_SHOWWINDOW = 0x0040;
    public const uint SWP_HIDEWINDOW = 0x0080;

    #endregion

    #region Win32 P/Invoke

    private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    private static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    private static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);

    [DllImport("user32.dll")]
    private static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr SetParent(IntPtr hWndChild, IntPtr hWndNewParent);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr GetParent(IntPtr hWnd);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtr", SetLastError = true)]
    private static extern IntPtr GetWindowLongPtr64(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", EntryPoint = "GetWindowLong", SetLastError = true)]
    private static extern int GetWindowLong32(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", EntryPoint = "SetWindowLongPtr", SetLastError = true)]
    private static extern IntPtr SetWindowLongPtr64(IntPtr hWnd, int nIndex, IntPtr dwNewLong);

    [DllImport("user32.dll", EntryPoint = "SetWindowLong", SetLastError = true)]
    private static extern int SetWindowLong32(IntPtr hWnd, int nIndex, int dwNewLong);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    private static long GetWindowLongCompat(IntPtr hWnd, int nIndex)
    {
        return IntPtr.Size == 8
            ? (long)GetWindowLongPtr64(hWnd, nIndex)
            : GetWindowLong32(hWnd, nIndex);
    }

    private static void SetWindowLongCompat(IntPtr hWnd, int nIndex, long dwNewLong)
    {
        if (IntPtr.Size == 8)
        {
            SetWindowLongPtr64(hWnd, nIndex, (IntPtr)dwNewLong);
        }
        else
        {
            SetWindowLong32(hWnd, nIndex, (int)dwNewLong);
        }
    }

    #endregion

    public Win32WindowEmbedderService(IDiagnosticLogService? logger = null)
    {
        _logger = logger;
    }

    public async Task<bool> EmbedWindowAsync(
        IntPtr hostContainerHwnd,
        string processName = "qemu-system-x86_64",
        CancellationToken ct = default)
    {
        if (hostContainerHwnd == IntPtr.Zero)
        {
            _logger?.Log(LogCategory.Host, "Host container HWND is null. Cannot embed.", "ERROR");
            return false;
        }

        lock (_lock)
        {
            if (_isEmbedded)
            {
                _logger?.Log(LogCategory.Host, "Window is already embedded.", "WARN");
                return true;
            }
        }

        _logger?.Log(LogCategory.Host, $"Searching for emulator window (Process: {processName})...");

        // 최대 10회 (약 5초) 동안 렌더링 윈도우 생성 대기
        IntPtr targetHwnd = IntPtr.Zero;
        for (int i = 0; i < 10; i++)
        {
            if (ct.IsCancellationRequested) return false;

            targetHwnd = FindEmulatorWindow(processName);
            if (targetHwnd != IntPtr.Zero) break;

            await Task.Delay(500, ct);
        }

        if (targetHwnd == IntPtr.Zero)
        {
            _logger?.Log(LogCategory.Host, $"Emulator window not found for process '{processName}'.", "WARN");
            return false;
        }

        lock (_lock)
        {
            try
            {
                _hostHwnd = hostContainerHwnd;
                _embeddedHwnd = targetHwnd;
                _originalParentHwnd = GetParent(targetHwnd);
                _originalStyle = GetWindowLongCompat(targetHwnd, GWL_STYLE);
                _originalExStyle = GetWindowLongCompat(targetHwnd, GWL_EXSTYLE);

                var newStyle = ComputeEmbeddedStyle(_originalStyle);
                var newExStyle = ComputeEmbeddedExStyle(_originalExStyle);

                SetWindowLongCompat(targetHwnd, GWL_STYLE, newStyle);
                SetWindowLongCompat(targetHwnd, GWL_EXSTYLE, newExStyle);

                SetParent(targetHwnd, hostContainerHwnd);

                // 스타일 갱신 및 표시
                SetWindowPos(
                    targetHwnd,
                    IntPtr.Zero,
                    0, 0, 100, 100,
                    SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED | SWP_SHOWWINDOW);

                _isEmbedded = true;
                _logger?.Log(LogCategory.Host, $"Successfully embedded HWND 0x{targetHwnd:X} into Host 0x{hostContainerHwnd:X}");
                return true;
            }
            catch (Exception ex)
            {
                _logger?.LogError(LogCategory.Host, "Exception occurred during window embedding", ex);
                DetachWindow();
                return false;
            }
        }
    }

    public bool DetachWindow()
    {
        lock (_lock)
        {
            if (!_isEmbedded || _embeddedHwnd == IntPtr.Zero) return false;

            try
            {
                SetParent(_embeddedHwnd, _originalParentHwnd);
                SetWindowLongCompat(_embeddedHwnd, GWL_STYLE, _originalStyle);
                SetWindowLongCompat(_embeddedHwnd, GWL_EXSTYLE, _originalExStyle);

                SetWindowPos(
                    _embeddedHwnd,
                    IntPtr.Zero,
                    0, 0, 0, 0,
                    SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED | SWP_SHOWWINDOW);

                _logger?.Log(LogCategory.Host, $"Detached HWND 0x{_embeddedHwnd:X} back to original parent 0x{_originalParentHwnd:X}");

                _embeddedHwnd = IntPtr.Zero;
                _hostHwnd = IntPtr.Zero;
                _isEmbedded = false;
                return true;
            }
            catch (Exception ex)
            {
                _logger?.LogError(LogCategory.Host, "Failed to detach window", ex);
                return false;
            }
        }
    }

    public bool UpdateViewport(int x, int y, int width, int height)
    {
        lock (_lock)
        {
            if (!_isEmbedded || _embeddedHwnd == IntPtr.Zero) return false;

            return MoveWindow(_embeddedHwnd, x, y, width, height, true);
        }
    }

    public static IntPtr FindEmulatorWindow(string processName)
    {
        var targetProcesses = Process.GetProcessesByName(processName);
        if (targetProcesses.Length == 0 && processName.Contains("qemu"))
        {
            targetProcesses = Process.GetProcessesByName("emulator");
        }

        if (targetProcesses.Length == 0) return IntPtr.Zero;

        var targetPids = new HashSet<uint>(targetProcesses.Select(p => (uint)p.Id));
        IntPtr foundHwnd = IntPtr.Zero;

        EnumWindows((hWnd, lParam) =>
        {
            if (!IsWindowVisible(hWnd)) return true;

            GetWindowThreadProcessId(hWnd, out uint pid);
            if (!targetPids.Contains(pid)) return true;

            var titleBuf = new StringBuilder(256);
            GetWindowText(hWnd, titleBuf, 256);
            string title = titleBuf.ToString();

            var classBuf = new StringBuilder(256);
            GetClassName(hWnd, classBuf, 256);
            string className = classBuf.ToString();

            GetWindowRect(hWnd, out RECT rect);
            int width = rect.Right - rect.Left;
            int height = rect.Bottom - rect.Top;

            // 렌더링 윈도우 식별 (최소 크기 200x200 이상, 툴바/콘솔 윈도우 제외)
            if (width > 200 && height > 200)
            {
                foundHwnd = hWnd;
                return false; // 탐색 종료
            }

            return true;
        }, IntPtr.Zero);

        return foundHwnd;
    }

    public static long ComputeEmbeddedStyle(long currentStyle)
    {
        long stripped = currentStyle & ~(
            WS_POPUP |
            WS_CAPTION |
            WS_THICKFRAME |
            WS_MINIMIZEBOX |
            WS_MAXIMIZEBOX |
            WS_SYSMENU |
            WS_DLGFRAME |
            WS_BORDER);

        return stripped | WS_CHILD | WS_VISIBLE;
    }

    public static long ComputeEmbeddedExStyle(long currentExStyle)
    {
        long stripped = currentExStyle & ~(
            WS_EX_DLGMODALFRAME |
            WS_EX_WINDOWEDGE |
            WS_EX_CLIENTEDGE |
            WS_EX_STATICEDGE |
            WS_EX_APPWINDOW);

        return stripped | WS_EX_NOPARENTNOTIFY;
    }

    public void Dispose()
    {
        DetachWindow();
        GC.SuppressFinalize(this);
    }
}
