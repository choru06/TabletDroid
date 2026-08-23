namespace TabletDroid.Core.Services;

public enum LogCategory
{
    Host,
    Runtime,
    Adb,
    Guest
}

public interface IDiagnosticLogService
{
    string LogDirectory { get; }
    void Log(LogCategory category, string message, string level = "INFO");
    void LogError(LogCategory category, string message, Exception? ex = null);
}

public class DiagnosticLogService : IDiagnosticLogService
{
    private readonly string _logDirectory;
    private readonly object _lock = new();

    public string LogDirectory => _logDirectory;

    public DiagnosticLogService(string? customLogDir = null)
    {
        if (!string.IsNullOrWhiteSpace(customLogDir))
        {
            _logDirectory = customLogDir;
        }
        else
        {
            var appData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            _logDirectory = Path.Combine(appData, "TabletDroid", "logs");
        }

        try
        {
            Directory.CreateDirectory(_logDirectory);
        }
        catch
        {
            // ignore
        }
    }

    public void Log(LogCategory category, string message, string level = "INFO")
    {
        var logFile = Path.Combine(_logDirectory, $"{category.ToString().ToLowerInvariant()}.log");
        var timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff");
        var line = $"[{timestamp}] [{level}] {message}{Environment.NewLine}";

        lock (_lock)
        {
            try
            {
                File.AppendAllText(logFile, line);
            }
            catch
            {
                // 로깅 실패로 인해 메인 프로세스가 중단되지 않도록 보호
            }
        }
    }

    public void LogError(LogCategory category, string message, Exception? ex = null)
    {
        var fullMessage = ex != null ? $"{message} | Exception: {ex.Message} -> {ex.StackTrace}" : message;
        Log(category, fullMessage, "ERROR");
    }
}
