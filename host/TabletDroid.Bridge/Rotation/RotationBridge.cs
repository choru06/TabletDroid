using TabletDroid.Bridge.Adb;
using TabletDroid.Bridge.Emulator;
using TabletDroid.Bridge.Guest;
using TabletDroid.Core.Models;
using TabletDroid.Protocol;

namespace TabletDroid.Bridge.Rotation;

public interface IRotationBridge
{
    DeviceOrientation CurrentOrientation { get; }
    Task SetOrientationAsync(DeviceOrientation orientation, OrientationPolicy policy = OrientationPolicy.Auto, string deviceSerial = "emulator-5554");
}

public class RotationBridge : IRotationBridge
{
    private readonly IAdbClient? _adbClient;
    private readonly IEmulatorConsoleClient? _consoleClient;
    private readonly IGuestAgentClient? _guestClient;
    private DeviceOrientation _currentOrientation = DeviceOrientation.OrientationNatural;

    public DeviceOrientation CurrentOrientation => _currentOrientation;

    public RotationBridge(
        IAdbClient? adbClient,
        IEmulatorConsoleClient? consoleClient,
        IGuestAgentClient? guestClient)
    {
        _adbClient = adbClient;
        _consoleClient = consoleClient;
        _guestClient = guestClient;
    }

    public async Task SetOrientationAsync(
        DeviceOrientation orientation,
        OrientationPolicy policy = OrientationPolicy.Auto,
        string deviceSerial = "emulator-5554")
    {
        // 정책 확인 (세로 모드 선호 앱 또는 가로 모드 선호 앱)
        if (policy == OrientationPolicy.PortraitPreferred &&
            (orientation == DeviceOrientation.OrientationNatural || orientation == DeviceOrientation.OrientationInverted180))
        {
            orientation = DeviceOrientation.OrientationRight90;
        }
        else if (policy == OrientationPolicy.LandscapePreferred &&
                 (orientation == DeviceOrientation.OrientationRight90 || orientation == DeviceOrientation.OrientationLeft270))
        {
            orientation = DeviceOrientation.OrientationNatural;
        }

        _currentOrientation = orientation;

        // 1. Privileged GuestAgent가 연결되어 있으면 Protobuf 메시지 우선 전송
        if (_guestClient != null && _guestClient.IsReady && (_guestClient.GuestInfo?.IsPrivileged ?? false))
        {
            await _guestClient.SendOrientationAsync(orientation);
            return;
        }

        // 2. v0.1 Dev/Stock AVD: ADB shell settings를 통해 정확한 절대 각도 설정 (0, 1, 2, 3)
        if (_adbClient != null)
        {
            var rotationVal = orientation switch
            {
                DeviceOrientation.OrientationNatural => 0,
                DeviceOrientation.OrientationRight90 => 1,
                DeviceOrientation.OrientationInverted180 => 2,
                DeviceOrientation.OrientationLeft270 => 3,
                _ => 0
            };

            try
            {
                // 가속도 센서 자동회전 비활성화 후 사용자 고정 회전값 주입
                await _adbClient.ExecuteShellCommandAsync(deviceSerial, "settings put system accelerometer_rotation 0");
                await _adbClient.ExecuteShellCommandAsync(deviceSerial, $"settings put system user_rotation {rotationVal}");
                return;
            }
            catch
            {
                // ADB 실패 시 콘솔 폴백
            }
        }

        // 3. Fallback: Emulator Console
        if (_consoleClient != null && _consoleClient.IsConnected)
        {
            var angle = orientation switch
            {
                DeviceOrientation.OrientationNatural => 0,
                DeviceOrientation.OrientationRight90 => 90,
                DeviceOrientation.OrientationInverted180 => 180,
                DeviceOrientation.OrientationLeft270 => 270,
                _ => 0
            };
            await _consoleClient.RotateAsync(angle);
        }
    }
}
