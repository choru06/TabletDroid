namespace TabletDroid.Core.Models;

/// <summary>
/// TabletDroid에서 관리하는 Android 앱 정보
/// </summary>
public class AndroidApp
{
    public required string PackageName { get; set; }
    public string? LaunchActivity { get; set; }
    public required string DisplayName { get; set; }
    public string? IconPath { get; set; }
    public bool IsPinned { get; set; } = false;
    public DisplayProfile Profile { get; set; } = DisplayProfile.DefaultTablet;

    public static List<AndroidApp> GetDefaultPresetApps()
    {
        return
        [
            new AndroidApp
            {
                PackageName = "com.instagram.android",
                DisplayName = "Instagram",
                IsPinned = true,
                Profile = DisplayProfile.PortraitApp
            },
            new AndroidApp
            {
                PackageName = "com.google.android.youtube",
                DisplayName = "YouTube",
                IsPinned = true,
                Profile = DisplayProfile.DefaultTablet
            },
            new AndroidApp
            {
                PackageName = "com.discord",
                DisplayName = "Discord",
                IsPinned = true,
                Profile = DisplayProfile.DefaultTablet
            }
        ];
    }
}
