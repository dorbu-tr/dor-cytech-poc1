---
name: "team-worker-service"
description: "Trading .NET Backend Worker/Executor service development patterns. Use when building or modifying background workers, message processors, event handlers, RabbitMQ consumers/publishers, worker clusters, event routing, or processor patterns. Triggers on any work involving IHostedService workers, WorkerBase, MultiWorkerCluster, IRequestProcessor, event routers, RabbitMQ queue consumption, message publishing, or worker-based service architecture (non-API services like trading-position-edit-service, trading-ros)."
metadata:
  short-description: "Trading .NET Backend Worker/Executor service development patterns. Use when building or modifying background workers, message processors, event handlers, RabbitMQ consumers/publishers, worker clusters, event routing, or processor patterns. Triggers on any work involving IHostedService workers, WorkerBase, MultiWorkerCluster, IRequestProcessor, event routers, RabbitMQ queue consumption, message publishing, or worker-based service architecture (non-API services like trading-position-edit-service, trading-ros)."
---

<!-- AUTO-GENERATED from .cursor/ canonical source. Do not edit directly. -->
<!-- Source: .cursor/skills/team/worker-service/SKILL.md | Regenerate: .specify/scripts/sh/sync-ai-rules.sh codex -->
# Trading .NET Worker/Executor Development

## Worker Architecture Overview

Trading worker services follow a layered processing pipeline:

```
RabbitMQ Queue
  -> BasicRabbitNotificationProvider<MessageBase> (consumer — Framework package)
    -> WorkerService (IHostedService — Framework package)
      -> MultiWorkerCluster (parallel processing — Framework package)
        -> WorkerBase.ProcessWorkItem (per-item — Framework package)
          -> EventRouter.RouteAsync (dispatch by type — application-level)
            -> IRequestProcessor (business logic — application-level)
              -> Success/Error Handler (notifications — application-level)
```

## Hosted Worker Pattern

The entry point is an `IHostedService` that wraps a `WorkerService`:

```csharp
// Program.cs
serviceCollection.RegisterDependencies();
serviceCollection.AddHostedService<{ServiceName}HostedServiceWorker>();
```

```csharp
public sealed class {ServiceName}HostedServiceWorker : WorkerService
{
    public {ServiceName}HostedServiceWorker(
        List<INotificationProvider> notificationProviders,
        IPriorityWorker<QueuedObject<IEvent>> priorityWorker,
        IPriorityProvider priorityProvider,
        ILogger logger,
        ITicksTrailFactory ticksTrailFactory)
        : base(notificationProviders, priorityWorker, priorityProvider, logger, ticksTrailFactory) { }
}
```

Note: `WorkerService` takes a `List<INotificationProvider>` (not a single provider) and requires `ITicksTrailFactory`. A second constructor overload without `ITicksTrailFactory` creates a default `TicksTrailFactory()` internally.

## Multi-Worker Cluster

Parallel processing with configurable concurrency. `MultiWorkerCluster<TObj, TRObj>` (from `Framework.Processing.Workers`) requires `IHashProvider<TRObj>` for routing and `IRoutingContextExtractor<TObj, TRObj>` for extracting routing keys. Generic constraints: `TRObj : struct`.

```csharp
public sealed class {ServiceName}MultiWorkerCluster
    : MultiWorkerCluster<QueuedObject<IEvent>, long>
{
    public {ServiceName}MultiWorkerCluster(
        IHashProvider<long> hashProvider,
        IRoutingContextExtractor<QueuedObject<IEvent>, long> contextExtractor,
        {ServiceName}Configuration configuration,
        ILogger logger)
        : base(hashProvider, contextExtractor, logger,
            levelOfParallelism: configuration.WorkerClusterLevelOfParallelism,
            disposeGracePeriodSec: configuration.DisposeGracePeriodInSeconds) { }
}
```

Configuration from CCM: `LevelOfParallelism` (default 50), `DisposeGracePeriodInSeconds` (default 20).

## Worker Base

Each worker processes one item at a time. `WorkerBase<T>.ProcessWorkItem` takes two parameters: the work item and a `TimeSpan latency` (time spent in queue).

```csharp
public class {ServiceName}Worker : WorkerBase<QueuedObject<IEvent>>
{
    private readonly IEventRouter _eventRouter;
    private readonly ILogger _logger;

    protected override async Task ProcessWorkItem(QueuedObject<IEvent> workItem, TimeSpan latency)
    {
        try
        {
            await _eventRouter.RouteAsync(workItem.Event);
        }
        catch (Exception ex)
        {
            _logger.LogError($"Error processing: {ex.Message}");
        }
        finally
        {
            workItem.Ack();
        }
    }
}
```

## Event Router

Dispatches events to the correct processor by type:

```csharp
public sealed class EventRouter : IEventRouter
{
    private readonly Dictionary<Type, Func<IEvent, Task>> _routes;

    public EventRouter(
        IRequestProcessor<OrderOpenRequest> openProcessor,
        IRequestProcessor<OrderCloseRequest> closeProcessor)
    {
        _routes = new Dictionary<Type, Func<IEvent, Task>>
        {
            { typeof(OrderOpenRequest), e => openProcessor.ProcessAsync((OrderOpenRequest)e) },
            { typeof(OrderCloseRequest), e => closeProcessor.ProcessAsync((OrderCloseRequest)e) }
        };
    }

    public async Task RouteAsync(IEvent @event)
    {
        if (_routes.TryGetValue(@event.GetType(), out var handler))
            await handler(@event);
        else
            throw new InvalidOperationException($"No route for {@event.GetType().Name}");
    }
}
```

## Processor Pattern (Application-Level)

The processor pattern below is an **application-level convention** — these interfaces and classes are NOT provided by Trading packages. You define them in your service's `Application/` layer.

```csharp
// Define in your Application layer — not from a Trading NuGet package
public interface IRequestProcessor<in T> where T : IEvent
{
    Task ProcessAsync(T request);
}

public abstract class BaseProcessor<T> : IRequestProcessor<T> where T : IEvent
{
    private readonly ISuccessHandler _successHandler;
    private readonly IErrorHandler _errorHandler;
    private readonly ILogger _logger;

    public async Task ProcessAsync(T request)
    {
        try
        {
            await InnerProcess(request);
            await _successHandler.HandleAsync(request);
        }
        catch (Exception ex)
        {
            _logger.LogError($"Processing failed: {ex.Message}");
            await _errorHandler.HandleAsync(request, ex);
        }
    }

    protected abstract Task InnerProcess(T request);
}
```

## RabbitMQ Messaging

- **Consumer setup and exchange patterns**: Read [references/rabbitmq-patterns.md](references/rabbitmq-patterns.md)
- **Real-world worker examples from PES and ROS**: Read [references/worker-examples.md](references/worker-examples.md)

## Worker Configuration

Key CCM settings for worker services:

| Setting | Default | Purpose |
|---------|---------|---------|
| `WorkerClusterLevelOfParallelism` | 50 | Max concurrent workers |
| `DisposeGracePeriodInSeconds` | 20 | Graceful shutdown timeout |
| `MinimumWorkerThreadsPerCore` | 1000 | ThreadPool min threads |
| `MinimumIocpThreadsPerCore` | 1000 | ThreadPool min IOCP threads |
| `ConsumingQueue_Name` | varies | RabbitMQ queue to consume |

## Startup Pattern (Program.cs)

```csharp
var host = Host.CreateDefaultBuilder(args)
    .ConfigureServices((context, serviceCollection) =>
    {
        serviceCollection.RegisterDependencies();
        serviceCollection.AddHostedService<{ServiceName}HostedServiceWorker>();
    })
    .ConfigureLogging((_, configLogging) => configLogging.AddLog4Net())
    .ConfigureWebHostDefaults(webBuilder => webBuilder.UseStartup<Startup>())
    .Build();

await host.RunAsync();
```

## Testing Workers

Use testable subclass to expose `ProcessWorkItem`:

```csharp
public class Testable{ServiceName}Worker : {ServiceName}Worker
{
    public new Task ProcessWorkItem(QueuedObject<IEvent> workItem, TimeSpan latency)
        => base.ProcessWorkItem(workItem, latency);
}
```
