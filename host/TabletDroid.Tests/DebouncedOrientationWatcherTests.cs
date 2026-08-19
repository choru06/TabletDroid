using TabletDroid.Bridge.Rotation;
using TabletDroid.Protocol;
using Xunit;

namespace TabletDroid.Tests;

public class DebouncedOrientationWatcherTests
{
    [Fact]
    public async Task OrientationWatcher_DebouncesRapidEvents()
    {
        // Arrange
        using var watcher = new DebouncedOrientationWatcher(debounceMilliseconds: 100);
        int eventCount = 0;
        DeviceOrientation lastOrientation = DeviceOrientation.OrientationNatural;

        watcher.OrientationChanged += (s, o) =>
        {
            eventCount++;
            lastOrientation = o;
        };

        watcher.Start();

        // Act: 빠르게 여러 번 변경 시뮬레이션
        watcher.SimulateOrientationChange(DeviceOrientation.OrientationRight90);
        await Task.Delay(20);
        watcher.SimulateOrientationChange(DeviceOrientation.OrientationInverted180);
        await Task.Delay(20);
        watcher.SimulateOrientationChange(DeviceOrientation.OrientationLeft270);

        // 디바운스 대기
        await Task.Delay(200);

        // Assert: 최종 방향인 OrientationLeft270 1회만 발생해야 함
        Assert.Equal(1, eventCount);
        Assert.Equal(DeviceOrientation.OrientationLeft270, lastOrientation);
    }

    [Fact]
    public async Task OrientationWatcher_IgnoresDuplicateOrientation()
    {
        // Arrange
        using var watcher = new DebouncedOrientationWatcher(debounceMilliseconds: 50);
        int eventCount = 0;

        watcher.OrientationChanged += (s, o) => eventCount++;
        watcher.Start();

        // Act: 첫 번째 변경
        watcher.SimulateOrientationChange(DeviceOrientation.OrientationRight90);
        await Task.Delay(100);

        // 동일한 방향 재입력
        watcher.SimulateOrientationChange(DeviceOrientation.OrientationRight90);
        await Task.Delay(100);

        // Assert: 1회만 호출
        Assert.Equal(1, eventCount);
    }
}
