namespace TabletDroid.Core.Models;

/// <summary>
/// 화면 방향 정책
/// </summary>
public enum OrientationPolicy
{
    /// <summary>
    /// 센서/디바이스 회전에 따라 자동 회전
    /// </summary>
    Auto = 0,

    /// <summary>
    /// 가로(Landscape) 모드 고정
    /// </summary>
    LandscapePreferred = 1,

    /// <summary>
    /// 세로(Portrait) 모드 고정 (인스타그램 등)
    /// </summary>
    PortraitPreferred = 2
}

/// <summary>
/// 앱별 디스플레이 및 화면 렌더링 프로파일
/// </summary>
public class DisplayProfile
{
    /// <summary>
    /// 가상 해상도 가로 (기본 1920)
    /// </summary>
    public int Width { get; set; } = 1920;

    /// <summary>
    /// 가상 해상도 세로 (기본 1200)
    /// </summary>
    public int Height { get; set; } = 1200;

    /// <summary>
    /// 화면 밀도 (DPI, 기본 280)
    /// </summary>
    public int DensityDpi { get; set; } = 280;

    /// <summary>
    /// 화면 방향 정책
    /// </summary>
    public OrientationPolicy Orientation { get; set; } = OrientationPolicy.Auto;

    /// <summary>
    /// 상태바/네비게이션바를 완전히 제거한 100% 전체화면 강제 여부
    /// </summary>
    public bool ImmersiveFullscreen { get; set; } = true;

    /// <summary>
    /// 기본 태블릿 프로파일 (1920x1200, 280dpi, Auto)
    /// </summary>
    public static DisplayProfile DefaultTablet => new()
    {
        Width = 1920,
        Height = 1200,
        DensityDpi = 280,
        Orientation = OrientationPolicy.Auto,
        ImmersiveFullscreen = true
    };

    /// <summary>
    /// 인스타그램 등 세로 선호형 앱용 프로파일
    /// </summary>
    public static DisplayProfile PortraitApp => new()
    {
        Width = 1200,
        Height = 1920,
        DensityDpi = 280,
        Orientation = OrientationPolicy.PortraitPreferred,
        ImmersiveFullscreen = true
    };
}
