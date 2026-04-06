<!-- AUTO-GENERATED from .cursor/ canonical source. Do not edit directly. -->
<!-- Source: .cursor/skills/team/orchestration/SKILL.md | Regenerate: .specify/scripts/sh/sync-ai-rules.sh copilot -->
---
name: trading-dotnet-orchestration
description: Trading .NET orchestration service patterns for long-running multi-step operations using saga state machines, leader election, multi-instance queue coordination, and concurrent state management. Use when building services that orchestrate complex workflows (e.g., mirror unregister, copy close), require saga step-based processing, need leader election for single-instance tasks (recovery, monitoring), coordinate multiple pods on shared queues, or manage concurrent in-memory state with thread-safe collections. Triggers on any work involving ISaga, IStep, LeaderElectionManager, sharded queues, competing consumers, ConcurrentDictionary for state caching, or SplitManager batched publishing.
---

# Trading .NET Orchestration Service Development

## When to Use Orchestration vs Simple Worker

| Characteristic | Simple Worker (`trading-dotnet-worker`) | Orchestration (`this skill`) |
|---------------|----------------------------------------|------------------------------|
| Processing | Stateless, single-step per message | Multi-step, stateful saga |
| State | None (process and forget) | In-memory cache + DB persistence |
| Recovery | Re-consume from queue | Saga recovery with leader election |
| Scaling | Competing consumers on one queue | Sharded queues or leader-elected tasks |
| Examples | PES, ROS | trading-sse (Saga State Engine) |

**Choose orchestration when**: The operation spans multiple steps, requires state tracking across steps, needs recovery from partial failures, or coordinates multiple downstream services.

## Saga Pattern Overview

A saga is a step-based state machine that orchestrates long-running operations. Sagas are created at the application level (there is no `SagaFactory` in the Trading packages — you instantiate and manage saga instances in your service code).

```
Request arrives
  -> Application creates ISaga<TSagaData, TSagaKey> instance
    -> Step 1: StartedStep (deactivate resource)
      -> Step 2: CloseOrdersStep (cancel pending)
        -> Step 3: HandlePositionsStep (branch logic)
          -> Step 4: AllPositionsClosedStep (finalize)
            -> Archive saga
```

Each step (implements `IStep` from `Framework.Saga.Core.Async`):
- Receives events via `ProcessEventAsync` and advances the saga
- Persists state to DB after transition
- Can branch to different next-steps based on conditions
- Handles timeout and recovery

- **Full saga implementation patterns**: Read [references/saga-patterns.md](references/saga-patterns.md)

## Leader Election

Only one pod should run recovery and monitoring tasks. Use Redis-based `LeaderElectionManager`:

```csharp
// LeaderElectionRepositoryRedis requires IFrameworkRedisClient (NOT a raw Redis client)
var repo = new LeaderElectionRepositoryRedis(frameworkRedisClient);

// LeaderElectionManager 4th param is TimeSpan ttl (NOT int seconds)
var manager = new LeaderElectionManager(
    repo, "SSEServiceLock", Guid.NewGuid().ToString(),
    TimeSpan.FromSeconds(config.LeaderElectionTTLInSeconds), logger,
    tryAquireLeaderOnCreation: true);
```

Register as singleton; check `manager.IsLeader` before running leader-only tasks. Call `manager.StartPeriodicElection()` to begin periodic leader re-election (retries at half the TTL interval).

**Required package**: `eToro.Trading.Framework.LeaderElection`

## Multi-Instance Queue Strategies

Two approaches for scaling consumers:

**1. Competing consumers** (recommended for new services):
- All pods consume from the same durable queue
- `SetExclusive(false)` + `Durable()` + `SetAutoDelete(false)`
- RabbitMQ distributes messages round-robin

**2. Sharded queues** (legacy pattern):
- Each instance gets its own queue: `{QueueNameFormat}_{InstanceNumber}`
- Recovery uses `mod`/`result` partitioning per instance

- **Full multi-instance patterns**: Read [references/multi-instance.md](references/multi-instance.md)

## Concurrent State Management

Orchestration services maintain in-memory state:
- `ConcurrentDictionary<TKey, ISaga>` for saga cache
- `SemaphoreSlim` for serializing operations
- `ConcurrentQueue<T>` for batched publishing

- **Full concurrency patterns**: Read [references/concurrency-patterns.md](references/concurrency-patterns.md)

## Required NuGet Packages

```xml
<PackageReference Include="eToro.Trading.Framework.Saga.Core.Async" Version="$(FrameworkBuildVersion)" />
<PackageReference Include="eToro.Trading.Framework.LeaderElection" Version="$(FrameworkBuildVersion)" />
<PackageReference Include="eToro.Trading.Framework.RedisClient.StackExchange" Version="$(FrameworkBuildVersion)" />
<PackageReference Include="eToro.Trading.Framework.RabbitMQ" Version="$(FrameworkBuildVersion)" />
```
