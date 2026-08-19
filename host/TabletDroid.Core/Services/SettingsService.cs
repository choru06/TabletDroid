using System.Text.Json;
using TabletDroid.Core.Models;

namespace TabletDroid.Core.Services;

public class AppSettings
{
    public string DefaultAvdName { get; set; } = "TabletDroid_Z13";
    public bool AutoRotateWithWindowsSensor { get; set; } = true;
    public bool BiDirectionalClipboardSync { get; set; } = true;
    public List<AndroidApp> InstalledApps { get; set; } = AndroidApp.GetDefaultPresetApps();
}

public interface ISettingsService
{
    AppSettings Settings { get; }
    Task LoadAsync();
    Task SaveAsync();
}

public class SettingsService : ISettingsService
{
    private readonly string _settingsFilePath;
    private AppSettings _settings = new();

    public AppSettings Settings => _settings;

    public SettingsService(string? customPath = null)
    {
        if (!string.IsNullOrWhiteSpace(customPath))
        {
            _settingsFilePath = customPath;
        }
        else
        {
            var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            var dir = Path.Combine(appData, "TabletDroid");
            Directory.CreateDirectory(dir);
            _settingsFilePath = Path.Combine(dir, "settings.json");
        }
    }

    public async Task LoadAsync()
    {
        try
        {
            if (File.Exists(_settingsFilePath))
            {
                var json = await File.ReadAllTextAsync(_settingsFilePath);
                var loaded = JsonSerializer.Deserialize<AppSettings>(json);
                if (loaded != null)
                {
                    _settings = loaded;
                }
            }
            else
            {
                _settings = new AppSettings();
                await SaveAsync();
            }
        }
        catch
        {
            _settings = new AppSettings();
        }
    }

    public async Task SaveAsync()
    {
        var options = new JsonSerializerOptions { WriteIndented = true };
        var json = JsonSerializer.Serialize(_settings, options);
        await File.WriteAllTextAsync(_settingsFilePath, json);
    }
}
