using TabletDroid.Bridge.Emulator;
using TabletDroid.Bridge.Guest;
using TabletDroid.Core.Models;
using TabletDroid.Protocol;

namespace TabletDroid.Bridge.Rotation;

public interface IRotationBridge
{
    Task SetOrientationAsync(DeviceOrientation orientation, OrientationPolicy policy = OrientationPolicy.Auto);
}

public class RotationBridge : IRotationBridge
{
    private readonly IEmulatorConsoleClient? _consoleClient;
    private readonly IGuestAgentClient? _guestClient;
    private DeviceOrientation _currentOrientation = DeviceOrientation.OrientationNatural;

    public DeviceOrientation CurrentOrientation => _currentOrientation;

    public RotationBridge(IEmulatorConsoleClient? consoleClient, IGuestAgentClient? guestClient)
    {
        _consoleClient = consoleClient;
        _guestClient = guestClient;
    }

    public async Task SetOrientationAsync(DeviceOrientation orientation, OrientationPolicy policy = OrientationPolicy.Auto)
    {
        // 정책 확인 (예: 세로 모드 고정 앱인 경우 회전 제한 등)
        if (policy == OrientationPolicy.PortraitPreferred &&
            (orientation == DeviceOrientation.OrientationNatural || orientation == DeviceOrientation.OrientationInverted180))
        {
            // 세로 방향(90도 또는 270도) 선호
            orientation = DeviceOrientation.OrientationRight90;
        }
        else if (policy == OrientationPolicy.LandscapePreferred &&
                 (orientation == DeviceOrientation.OrientationRight90 || orientation == DeviceOrientation.OrientationLeft270))
        {
            orientation = DeviceOrientation.OrientationNatural;
        }

        _currentOrientation = orientation;

        // 1. GuestAgent가 연결되어 있으면 Protobuf 메시지 우선 전송
        if (_guestClient != null && _guestClient.IsConnected)
        {
            await _guestClient.SendOrientationAsync(orientation);
            return;
        }

        // 2. GuestAgent 미연결 시 Emulator Console Telnet 활용 (v0.0 / v0.1)
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
