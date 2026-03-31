# Concurrency Patterns

## ConcurrentDictionary for Saga Cache

Thread-safe in-memory saga state backed by SQL persistence:

```csharp
public class MirrorSagaCache : IMirrorSagaRepository
{
    private readonly ConcurrentDictionary<int, ISaga> _cache = new();

    // Thread-safe read
    public bool TryGet(int mirrorId, out ISaga saga)
        => _cache.TryGetValue(mirrorId, out saga);

    // Thread-safe write
    public void Add(int mirrorId, ISaga saga)
        => _cache.TryAdd(mirrorId, saga);

    // Thread-safe remove
    public void Archive(int mirrorId)
        => _cache.TryRemove(mirrorId, out _);

    // Direct indexer for update
    public void Update(int mirrorId, ISaga saga)
        => _cache[mirrorId] = saga;
}
```

**Key rules**:
- Use `TryGetValue` for reads (not indexer -- avoids KeyNotFoundException)
- Use `TryAdd` for inserts (returns false if key exists)
- Use `TryRemove` for deletes (returns false if key missing)
- Use indexer `_cache[key] = value` only for upsert

## SemaphoreSlim for Serialized Operations

Limit concurrent access to a resource (e.g., only one batch publisher at a time):

```csharp
public class SplitManager : ISplitManager
{
    private readonly SemaphoreSlim _semaphore = new SemaphoreSlim(1, 1);
    private readonly int _maxPublishChunkSize;
    private readonly TimeSpan _publishChunkDelay;

    public ISplitHandler<T> CreateSplitHandler<T>(Action<ICollection<T>> action)
    {
        _semaphore.Wait();  // Block until previous handler completes
        return new SplitHandler<T>(
            _maxPublishChunkSize, _publishChunkDelay, action, _semaphore);
    }
}
```

The `SplitHandler` releases the semaphore on `Dispose()`:

```csharp
internal class SplitHandler<T> : ISplitHandler<T>, IDisposable
{
    private readonly ConcurrentQueue<T> _queue = new();
    private readonly SemaphoreSlim _semaphore;

    public void Push(T value) => _queue.Enqueue(value);

    public void Dispose()
    {
        // Drain remaining items
        DrainQueue();
        _semaphore.Release();
    }
}
```

**Pattern**: Acquire semaphore -> create handler -> push items -> dispose (releases semaphore).

## ConcurrentQueue for Batched Publishing

Buffer items and publish in configurable chunks:

```csharp
// Usage in saga step
using var handler = _splitManager.CreateSplitHandler<ClosePositionCommand>(batch =>
{
    foreach (var command in batch)
        _queueClient.Publish(command);
});

foreach (var position in positions)
{
    handler.Push(new ClosePositionCommand(position));
}
// Dispose flushes remaining items and releases semaphore
```

CCM config:
| Setting | Default | Purpose |
|---------|---------|---------|
| `MaxPublishChunkSize` | 100 | Items per batch |
| `PublishChunkDelayInMilliseconds` | 50 | Delay between batches |

## ThreadPool Tuning

Orchestration services need more threads than typical APIs:

```csharp
// In Program.cs or configuration
ThreadPool.SetMinThreads(
    config.MinWorkerThreads,        // Default: 250
    config.MinCompletionPortThreads  // Default: 250
);
```

CCM settings:
| Setting | Default | Purpose |
|---------|---------|---------|
| `MinWorkerThreads` | 250 | Minimum worker threads |
| `MinCompletionPortThreads` | 250 | Minimum IOCP threads |
| `MaxDegreeOfParallelism` | 50 | Parallel processing limit |
| `IsParallelInvoke` | false | Whether to process messages in parallel |

**Rule**: Set `MinWorkerThreads` high enough to avoid thread pool starvation under load. 250 is typical for orchestration services; simple workers use 1000/core.
