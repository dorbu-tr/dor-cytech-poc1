# RabbitMQ Messaging Patterns

## Consumer Setup

### NotificationProvider

The primary consumer uses `BasicRabbitNotificationProvider<MessageBase>` from `eToro.Trading.Framework.Communication.Client`:

```csharp
// Bootstrap registration
serviceCollection.AddSingleton<INotificationProvider>(sp =>
{
    var config = sp.GetRequiredService<{ServiceName}Configuration>();
    var queueClient = sp.GetRequiredService<IQueueClient>();

    return new BasicRabbitNotificationProvider<MessageBase>(
        queueClient,
        config.ConsumingQueue_Name,
        sp.GetRequiredService<ILogger>());
});
```

### RabbitMQ Client Registration

```csharp
// Queue client (consumer) - Transient per-request
serviceCollection.AddTransient<IQueueClient>(sp =>
{
    var config = sp.GetRequiredService<{ServiceName}Configuration>();
    return new RabbitQueueClient(config.TradingRabbitConnection);
});

// PubSub client (publisher) - Transient per-request
serviceCollection.AddTransient<IPubSubClient>(sp =>
{
    var config = sp.GetRequiredService<{ServiceName}Configuration>();
    return new RabbitPubSubClient(config.TradingRabbitConnection);
});

// General client - Transient
serviceCollection.AddTransient<IGeneralClient>(sp =>
{
    var config = sp.GetRequiredService<{ServiceName}Configuration>();
    return new RabbitClient(config.TradingRabbitConnection);
});
```

## Publisher Setup

### NotificationPublishProvider

```csharp
public sealed class {ServiceName}NotificationPublishProvider : INotificationPublishProvider
{
    private readonly IPubSubClient _pubSubClient;
    private readonly string _exchangeName;
    private readonly ILogger _logger;

    public async Task PublishAsync<T>(T message, string routingKey) where T : class
    {
        var serialized = ProtoSerializer.Serialize(message);
        await _pubSubClient.PublishAsync(_exchangeName, routingKey, serialized);
        _logger.LogInfo($"Published to {_exchangeName} with key {routingKey}");
    }
}
```

## Message Serialization

Trading services use ProtoBuf serialization via `ProtoSerializer` from `eToro.Trading.Framework.Serialization`:

```csharp
// Serialize
byte[] data = ProtoSerializer.Serialize(message);

// Deserialize
var message = ProtoSerializer.Deserialize<MessageBase>(data);
```

## Exchange/Queue Naming

| Component | Pattern | Example |
|-----------|---------|---------|
| Consuming queue | From CCM `ConsumingQueue_Name` | `RateOrderServiceExecution` |
| Success exchange | `TradingNotificationExchangeName` | `trading-notifications` |
| Failure exchange | `TradingFailsExchangeName` | `trading-fails` |
| Routing key | Typically instrument ID | `1001` |

## Configuration

RabbitMQ connection in `{ServiceName}Configuration`:
```csharp
public ConnectionConfiguration TradingRabbitConnection { get; set; }
```

From SCB (Service Configuration Broker):
```csharp
serviceCollection.AddSingleton(sp =>
{
    var scbFacade = sp.GetRequiredService<ISCBFacade>();
    return scbFacade.GetRabbitMqConfiguration("TradingRabbit");
});
```

## Queue Durability Settings

When multiple pods consume from the same queue (competing consumers):

```csharp
queueClientBuilder
    .SetQueueName(consumerQueue.QueueName)
    .Durable()                    // Queue survives broker restart
    .SetAutoDelete(false)         // Queue persists when consumers disconnect
    .SetExclusive(false)          // Multiple consumers allowed (competing)
    .Build();
```

| Setting | Purpose |
|---------|---------|
| `Durable()` | Queue survives RabbitMQ restart |
| `SetAutoDelete(false)` | Queue persists when all consumers disconnect |
| `SetExclusive(false)` | Multiple pods can consume from the same queue |

For saga orchestration, leader election, multi-instance sharding, and batched publishing patterns, see the `trading-dotnet-orchestration` skill.

## Required NuGet Packages

```xml
<PackageReference Include="eToro.Trading.Framework.Communication.Client" Version="$(FrameworkBuildVersion)" />
<PackageReference Include="eToro.Trading.Framework.Serialization" Version="$(FrameworkBuildVersion)" />
<PackageReference Include="eToro.Trading.Bootstrap.RabbitMQ" Version="$(TradingCoreBuildVersion)" />
<PackageReference Include="eToro.Trading.Framework.RabbitMQ" Version="$(FrameworkBuildVersion)" />
```
