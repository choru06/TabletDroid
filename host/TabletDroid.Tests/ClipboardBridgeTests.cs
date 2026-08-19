using Moq;
using TabletDroid.Bridge.Clipboard;
using TabletDroid.Bridge.Guest;
using TabletDroid.Protocol;
using Xunit;

namespace TabletDroid.Tests;

public class ClipboardBridgeTests
{
    [Fact]
    public async Task HandleWindowsClipboardChanged_SendsToGuest_WhenTextIsNew()
    {
        // Arrange
        var mockGuest = new Mock<IGuestAgentClient>();
        mockGuest.Setup(g => g.SendClipboardAsync(It.IsAny<string>(), It.IsAny<long>(), It.IsAny<CancellationToken>()))
                 .ReturnsAsync(true);

        var bridge = new ClipboardBridge(mockGuest.Object);
        bridge.Start();

        // Act
        await bridge.HandleWindowsClipboardChangedAsync("Hello TabletDroid!");

        // Assert
        mockGuest.Verify(g => g.SendClipboardAsync("Hello TabletDroid!", 1, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task HandleWindowsClipboardChanged_SuppressesEcho_WhenHashMatchesLastSent()
    {
        // Arrange
        var mockGuest = new Mock<IGuestAgentClient>();
        var bridge = new ClipboardBridge(mockGuest.Object);
        bridge.Start();

        // Act
        await bridge.HandleWindowsClipboardChangedAsync("Duplicate Text");
        await bridge.HandleWindowsClipboardChangedAsync("Duplicate Text");

        // Assert
        mockGuest.Verify(g => g.SendClipboardAsync("Duplicate Text", It.IsAny<long>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public void ComputeHash_ProducesConsistentSha256()
    {
        // Arrange & Act
        var hash1 = ClipboardBridge.ComputeHash("TestString");
        var hash2 = ClipboardBridge.ComputeHash("TestString");
        var hash3 = ClipboardBridge.ComputeHash("DifferentString");

        // Assert
        Assert.Equal(hash1, hash2);
        Assert.NotEqual(hash1, hash3);
    }
}
