using Google.Protobuf;
using TabletDroid.Protocol;
using Xunit;

namespace TabletDroid.Tests;

public class ProtocolSerializationTests
{
    [Fact]
    public void ClipboardSyncMessage_WithReplyTo_SerializesAndDeserializesCorrectly()
    {
        // Arrange
        var original = new TabletDroidMessage
        {
            MessageId = "msg-12345",
            ReplyTo = "req-9999",
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
        Assert.Equal(original.ReplyTo, deserialized.ReplyTo);
        Assert.Equal(original.Timestamp, deserialized.Timestamp);
        Assert.Equal(TabletDroidMessage.PayloadOneofCase.ClipboardSync, deserialized.PayloadCase);
        Assert.Equal(42, deserialized.ClipboardSync.RevisionId);
        Assert.Equal("TabletDroid Clipboard Test", deserialized.ClipboardSync.TextContent);
    }

    [Fact]
    public void HandshakeMessage_SerializesCorrectly()
    {
        // Arrange
        var req = new TabletDroidMessage
        {
            MessageId = "req-1",
            Timestamp = 1718000000000,
            HandshakeRequest = new HandshakeRequest
            {
                HostVersion = "0.1.0",
                OsVersion = "Windows 11"
            }
        };

        var resp = new TabletDroidMessage
        {
            MessageId = "resp-1",
            ReplyTo = "req-1",
            Timestamp = 1718000000005,
            HandshakeResponse = new HandshakeResponse
            {
                GuestVersion = "0.1.0-dev",
                AndroidApiLevel = 34,
                IsPrivileged = false
            }
        };

        // Act
        var respBytes = resp.ToByteArray();
        var parsedResp = TabletDroidMessage.Parser.ParseFrom(respBytes);

        // Assert
        Assert.Equal("req-1", parsedResp.ReplyTo);
        Assert.Equal("0.1.0-dev", parsedResp.HandshakeResponse.GuestVersion);
        Assert.Equal(34, parsedResp.HandshakeResponse.AndroidApiLevel);
        Assert.False(parsedResp.HandshakeResponse.IsPrivileged);
    }

    [Fact]
    public void LaunchAppResponse_Correlation_Matches()
    {
        var resp = new TabletDroidMessage
        {
            MessageId = "resp-launch-1",
            ReplyTo = "req-launch-1",
            LaunchAppResponse = new LaunchAppResponse
            {
                Success = true,
                ErrorMessage = ""
            }
        };

        var parsed = TabletDroidMessage.Parser.ParseFrom(resp.ToByteArray());
        Assert.Equal("req-launch-1", parsed.ReplyTo);
        Assert.True(parsed.LaunchAppResponse.Success);
    }
}
