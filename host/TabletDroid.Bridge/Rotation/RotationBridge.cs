using TabletDroid.Bridge.Adb;
using TabletDroid.Bridge.Emulator;
using TabletDroid.Bridge.Guest;
using TabletDroid.Core.Models;
using TabletDroid.Core.Services;
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
    private readonly IDiagnosticLogService? _logger;
    private DeviceOrientation _currentOrientation = DeviceOrientation.OrientationNatural;

    public DeviceOrientation CurrentOrientation => _currentOrientation;

    public RotationBridge(
        IAdbClient? adbClient,
        IEmulatorConsoleClient? consoleClient,
        IGuestAgentClient? guestClient,
        IDiagnosticLogService? logger = null)
    {
        _adbClient = adbClient;
        _consoleClient = consoleClient;
        _guestClient = guestClient;
        _logger = logger;
    }

    public async Task SetOrientationAsync(
        DeviceOrientation orientation,
        OrientationPolicy policy = OrientationPolicy.Auto,
        string deviceSerial = "emulator-5554")
    {
        _logger?.Log(LogCategory.Runtime, $"Setting orientation: target={orientation}, policy={policy} on {deviceSerial}");

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

        // 2. v0.1 Dev/Stock AVD: ADB shell settings를 통한 정확한 정책 제어
        if (_adbClient != null)
        {
            try
            {
                if (policy == OrientationPolicy.Auto)
                {
                    // Auto 모드: 센서 자동 회전 활성화
                    await _adbClient.ExecuteShellCommandAsync(deviceSerial, "settings put system accelerometer_rotation 1");
                }
                else
                {
                    // 고정 각도 모드: 자동 회전 비활성화 후 user_rotation 주입
                    var rotationVal = orientation switch
                    {
                        DeviceOrientation.OrientationNatural => 0,      // 0도 (가로)
                        DeviceOrientation.OrientationRight90 => 1,     // 90도 (세로)
                        DeviceOrientation.OrientationInverted180 => 2, // 180도 (역가로)
                        DeviceOrientation.OrientationLeft270 => 3,     // 270도 (역세로)
                        _ => 0
                    };

                    await _adbClient.ExecuteShellCommandAsync(deviceSerial, "settings put system accelerometer_rotation 0");
                    await _adbClient.ExecuteShellCommandAsync(deviceSerial, $"settings put system user_rotation {rotationVal}");
                }
                return;
            }
            catch (Exception ex)
            {
                _logger?.LogError(LogCategory.Runtime, "Failed to apply rotation via ADB, trying console fallback", ex);
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
