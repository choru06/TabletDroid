using Moq;
using TabletDroid.Bridge.Adb;
using TabletDroid.Bridge.Emulator;
using TabletDroid.Bridge.Guest;
using TabletDroid.Bridge.Rotation;
using TabletDroid.Core.Models;
using TabletDroid.Core.Services;
using TabletDroid.Protocol;
using Xunit;

namespace TabletDroid.Tests;

public class DiagnosticsAndRotationTests
{
    [Fact]
    public void DiagnosticLogService_WritesLogFilesSuccessfully()
    {
        // Arrange
        var tempDir = Path.Combine(Path.GetTempPath(), "TabletDroid_TestLogs_" + Guid.NewGuid());
        try
        {
            var logger = new DiagnosticLogService(tempDir);

            // Act
            logger.Log(LogCategory.Host, "Host started successfully");
            logger.Log(LogCategory.Runtime, "Runtime starting...");
            logger.LogError(LogCategory.Adb, "ADB command failed");

            // Assert
            var hostLog = Path.Combine(tempDir, "host.log");
            var runtimeLog = Path.Combine(tempDir, "runtime.log");
            var adbLog = Path.Combine(tempDir, "adb.log");

            Assert.True(File.Exists(hostLog));
            Assert.True(File.Exists(runtimeLog));
            Assert.True(File.Exists(adbLog));

            Assert.Contains("Host started successfully", File.ReadAllText(hostLog));
            Assert.Contains("ADB command failed", File.ReadAllText(adbLog));
        }
        finally
        {
            if (Directory.Exists(tempDir))
            {
                Directory.Delete(tempDir, true);
            }
        }
    }

    [Fact]
    public async Task RotationBridge_AppliesUserRotation_WhenSynchronizingPhysicalOrientation()
    {
        // Arrange
        var mockAdb = new Mock<IAdbClient>();
        var mockConsole = new Mock<IEmulatorConsoleClient>();
        var mockGuest = new Mock<IGuestAgentClient>();
        mockGuest.Setup(g => g.IsReady).Returns(false);

        var bridge = new RotationBridge(mockAdb.Object, mockConsole.Object, mockGuest.Object);

        // Act (Landscape)
        await bridge.SetOrientationAsync(DeviceOrientation.OrientationNatural, OrientationPolicy.Auto, "emulator-5554");

        // Assert
        mockAdb.Verify(a => a.ExecuteShellCommandAsync("emulator-5554", "settings put system accelerometer_rotation 0", It.IsAny<CancellationToken>()), Times.Once);
        mockAdb.Verify(a => a.ExecuteShellCommandAsync("emulator-5554", "settings put system user_rotation 0", It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task RotationBridge_AppliesUserRotation_WhenPolicyIsPortraitPreferred()
    {
        // Arrange
        var mockAdb = new Mock<IAdbClient>();
        var mockConsole = new Mock<IEmulatorConsoleClient>();
        var mockGuest = new Mock<IGuestAgentClient>();
        mockGuest.Setup(g => g.IsReady).Returns(false);

        var bridge = new RotationBridge(mockAdb.Object, mockConsole.Object, mockGuest.Object);

        // Act
        await bridge.SetOrientationAsync(DeviceOrientation.OrientationNatural, OrientationPolicy.PortraitPreferred, "emulator-5554");

        // Assert
        mockAdb.Verify(a => a.ExecuteShellCommandAsync("emulator-5554", "settings put system accelerometer_rotation 0", It.IsAny<CancellationToken>()), Times.Once);
        mockAdb.Verify(a => a.ExecuteShellCommandAsync("emulator-5554", "settings put system user_rotation 1", It.IsAny<CancellationToken>()), Times.Once);
    }
}
