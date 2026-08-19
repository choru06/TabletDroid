namespace TabletDroid.Core.Models;

/// <summary>
/// Android 런타임 인스턴스 구동 설정
/// </summary>
public class RuntimeConfiguration
{
    public string AvdName { get; set; } = "TabletDroid_Z13_Play";
    public string SdkPath { get; set; } = string.Empty;
    public string EmulatorBinaryPath { get; set; } = string.Empty;
    public string AdbBinaryPath { get; set; } = string.Empty;

    public int ConsolePort { get; set; } = 5554;
    public int AdbPort { get; set; } = 5555;
    public int GuestAgentPort { get; set; } = 28888;

    public bool UseWhpxAcceleration { get; set; } = true;
    public bool NoSkin { get; set; } = true;
    public bool NoSnapshotSave { get; set; } = true;
    public string GpuMode { get; set; } = "host";

    public int BootTimeoutSeconds { get; set; } = 90;
}
