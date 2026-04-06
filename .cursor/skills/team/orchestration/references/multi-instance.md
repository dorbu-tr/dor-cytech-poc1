# Multi-Instance Queue Patterns

## Competing Consumers (Recommended)

Multiple pods consume from the same durable queue. RabbitMQ distributes messages round-robin.

```csharp
// Bootstrap: register queue with competing consumer settings
private static IQueueClient RegisterNotificationProcessor(
    IServiceProvider serviceProvider,
    IQueueClientSubscriberFluentBuilder queueClientBuilder,
    RecoveryConsumerQueue consumerQueue)
{
    return queueClientBuilder
        .SetQueueName(consumerQueue.QueueName)
        .Durable()                    // Queue survives broker restart
        .SetAutoDelete(false)         // Queue persists when consumers disconnect
        .SetExclusive(false)          // Multiple consumers allowed
        .Build();
}
```

**When to use**: New services, stateless processing, horizontal scaling via HPA.

## Sharded Queues (Legacy Pattern)

Each instance gets its own queue using instance number formatting:

```csharp
public void InitQueueNames()
{
    int instanceNumber = _config.InstanceNumber;
    _config.NotificationQueueName = string.Format(
        _config.NotificationQueueNameFormat, (instanceNumber - 1).ToString());
    _config.MirrorUnregisterQueueName = string.Format(
        _config.MirrorUnregisterQueueNameFormat.Value, (instanceNumber - 1).ToString());
}
```

Result: `SSE_0_Notification`, `SSE_1_Notification`, `SSE_2_Notification` etc.

**When to use**: Legacy services, when messages must be processed by a specific instance (affinity), when saga state is instance-local.

## Multiple Queue Providers per Service

Orchestration services often consume from multiple queues:

```csharp
public static IServiceCollection RegisterNotificationProviders(
    this IServiceCollection serviceCollection)
    => serviceCollection
        // Queue 1: Primary request queue
        .RegisterNotificationProcessors<MirrorUnregisterRequest>()
        .ConfigureRabbitClient<MirrorUnregisterQueue>(RegisterNotificationProcessor)

        // Queue 2: Notification/event queue
        .RegisterNotificationProcessors<MessageBase>()
        .ConfigureRabbitClient<NotificationQueue>(RegisterNotificationProcessor)

        // Queue 3: Recovery queue
        .RegisterNotificationProcessors<RecoveryRequest<MirrorSagaKey>>()
        .ConfigureRabbitClient<RecoveryConsumerQueue>(RegisterNotificationProcessor)

        .Build();
```

Each queue has its own:
- Message type (`MirrorUnregisterRequest`, `MessageBase`, `RecoveryRequest<T>`)
- Configuration class (`MirrorUnregisterQueue`, `NotificationQueue`, `RecoveryConsumerQueue`)
- Data processor (`IDataProcessor<T>`)

## Leader Election for Single-Instance Tasks

Some tasks should only run on one pod (recovery, monitoring, scheduled jobs):

```csharp
private static ILeaderElectionManager CreateLeaderElectionManager(IServiceProvider provider)
{
    var logger = provider.GetRequiredService<ILogger>();
    var config = provider.GetRequiredService<RecoveryConfiguration>();
    var redisClient = provider.GetRequiredService<IFrameworkRedisClient>();
    var repo = new LeaderElectionRepositoryRedis(redisClient);

    var instanceKey = Guid.NewGuid().ToString();
    return new LeaderElectionManager(
        repo,
        lockName: "SSEServiceLock",
        instanceKey: instanceKey,
        ttlInSeconds: config.LeaderElectionTTLInSeconds,
        logger: logger,
        tryAquireLeaderOnCreation: true);
}
```

Usage in hosted services:

```csharp
if (_leaderElection.IsLeader)
{
    await RunRecoveryAsync();
    await RunMonitoringAsync();
}
```

## Recovery with Mod/Result Partitioning

When using sharded instances, recovery is partitioned by mod:

```csharp
// Each instance recovers only its partition
public List<ISaga> GetAllSagasByModAndResult(int mod, int result)
{
    // Calls [Trade].[GetMirrorCloseSagasByModAndResult]
    // Returns sagas where (SagaId % mod == result)
}
```

This ensures each instance only recovers sagas it is responsible for.

## Scaling Configuration

```yaml
# Helm values for orchestration services
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 6
  targetCPUUtilizationPercentage: 80
  type: hpa
```

CCM settings:
| Setting | Default | Purpose |
|---------|---------|---------|
| `TotalInstances` | varies | Number of sharded instances (legacy) |
| `InstanceNumber` | varies | This instance's number (legacy) |
| `LeaderElectionTTLInSeconds` | 30 | Leader lock expiry |
| `MaxDegreeOfParallelism` | 50 | Parallel processing limit |
