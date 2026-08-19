using TabletDroid.Core.Models;

namespace TabletDroid.Runtime;

public interface IRuntimeBackend : IAsyncDisposable
{
    RuntimeState State { get; }
    RuntimeConfiguration? CurrentConfig { get; }
    event EventHandler<RuntimeState>? StateChanged;

    Task<bool> StartAsync(RuntimeConfiguration config, CancellationToken ct = default);
    Task<bool> StopAsync(CancellationToken ct = default);
    Task<bool> SuspendAsync(CancellationToken ct = default);
    Task<bool> ResumeAsync(CancellationToken ct = default);
}
