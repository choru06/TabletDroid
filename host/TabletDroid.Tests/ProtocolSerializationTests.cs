using Google.Protobuf;
using TabletDroid.Protocol;
using Xunit;

namespace TabletDroid.Tests;

public class ProtocolSerializationTests
{
    [Fact]
    public void ClipboardSyncMessage_SerializesAndDeserializesCorrectly()
    {
        // Arrange
        var original = new TabletDroidMessage
        {
            MessageId = "msg-12345",
            Timestamp = 1718000000000,
            ClipboardSync = new ClipboardSyncEvent
            {
                RevisionId = 42,
                Source = ClipboardSource.SourceWindows,
                ContentHash = "ABCDEF123456",
                TextContent = "TabletDroid Clipboard Test"
            }
        };

        // Act
        var bytes = original.ToByteArray();
        var deserialized = TabletDroidMessage.Parser.ParseFrom(bytes);

        // Assert
        Assert.Equal(original.MessageId, deserialized.MessageId);
        Assert.Equal(original.Timestamp, deserialized.Timestamp);
        Assert.Equal(TabletDroidMessage.PayloadOneofCase.ClipboardSync, deserialized.PayloadCase);
        Assert.Equal(42, deserialized.ClipboardSync.RevisionId);
        Assert.Equal("TabletDroid Clipboard Test", deserialized.ClipboardSync.TextContent);
    }

    [Fact]
    public void SetOrientationMessage_SerializesAndDeserializesCorrectly()
    {
        // Arrange
        var original = new TabletDroidMessage
        {
            MessageId = "orient-1",
            Timestamp = 1718000000000,
            SetOrientation = new SetOrientationRequest
            {
                Orientation = DeviceOrientation.OrientationRight90,
                LockOrientation = true
            }
        };

        // Act
        var bytes = original.ToByteArray();
        var deserialized = TabletDroidMessage.Parser.ParseFrom(bytes);

        // Assert
        Assert.Equal(DeviceOrientation.OrientationRight90, deserialized.SetOrientation.Orientation);
        Assert.True(deserialized.SetOrientation.LockOrientation);
    }
}
