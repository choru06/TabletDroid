using TabletDroid.Bridge.Window;
using Xunit;

namespace TabletDroid.Tests;

public class WindowEmbedderTests
{
    [Fact]
    public void ComputeEmbeddedStyle_StripsPopupAndCaption_AndAddsChildAndVisible()
    {
        // Arrange: Typical standalone window with POPUP, CAPTION, THICKFRAME
        long initialStyle = Win32WindowEmbedderService.WS_POPUP
                          | Win32WindowEmbedderService.WS_CAPTION
                          | Win32WindowEmbedderService.WS_THICKFRAME
                          | Win32WindowEmbedderService.WS_MINIMIZEBOX
                          | Win32WindowEmbedderService.WS_MAXIMIZEBOX
                          | Win32WindowEmbedderService.WS_SYSMENU;

        // Act
        long embeddedStyle = Win32WindowEmbedderService.ComputeEmbeddedStyle(initialStyle);

        // Assert
        Assert.Equal(0L, embeddedStyle & Win32WindowEmbedderService.WS_POPUP);
        Assert.Equal(0L, embeddedStyle & Win32WindowEmbedderService.WS_CAPTION);
        Assert.Equal(0L, embeddedStyle & Win32WindowEmbedderService.WS_THICKFRAME);
        Assert.Equal(0L, embeddedStyle & Win32WindowEmbedderService.WS_MINIMIZEBOX);
        Assert.Equal(0L, embeddedStyle & Win32WindowEmbedderService.WS_MAXIMIZEBOX);
        Assert.Equal(0L, embeddedStyle & Win32WindowEmbedderService.WS_SYSMENU);

        Assert.NotEqual(0L, embeddedStyle & Win32WindowEmbedderService.WS_CHILD);
        Assert.NotEqual(0L, embeddedStyle & Win32WindowEmbedderService.WS_VISIBLE);
    }

    [Fact]
    public void ComputeEmbeddedExStyle_StripsAppWindowAndBorders_AndAddsNoParentNotify()
    {
        // Arrange
        long initialExStyle = Win32WindowEmbedderService.WS_EX_APPWINDOW
                            | Win32WindowEmbedderService.WS_EX_WINDOWEDGE
                            | Win32WindowEmbedderService.WS_EX_CLIENTEDGE;

        // Act
        long embeddedExStyle = Win32WindowEmbedderService.ComputeEmbeddedExStyle(initialExStyle);

        // Assert
        Assert.Equal(0L, embeddedExStyle & Win32WindowEmbedderService.WS_EX_APPWINDOW);
        Assert.Equal(0L, embeddedExStyle & Win32WindowEmbedderService.WS_EX_WINDOWEDGE);
        Assert.Equal(0L, embeddedExStyle & Win32WindowEmbedderService.WS_EX_CLIENTEDGE);
        Assert.NotEqual(0L, embeddedExStyle & Win32WindowEmbedderService.WS_EX_NOPARENTNOTIFY);
    }
}
