# Worker Service Examples

Real-world patterns from trading-position-edit-service (PES) and trading-ros (ROS).

## PES: Position Edit Service

### Architecture

PES processes position edit requests (stop loss, take profit, TSL, detach, redeem):

```
RabbitMQ -> BasicRabbitNotificationProvider<MessageBase>
  -> HostedPositionEditServiceWorker (IHostedService)
    -> PositionEditServiceMultiWorkerCluster (parallelism from CCM)
      -> PositionEditServiceWorker.ProcessWorkItem
        -> EventRouter (7 event types)
          -> Processors -> Success/Error handlers -> RabbitMQ publish
```

### Event Router Dispatch Table

| Event Type | Processor |
|------------|-----------|
| `PositionDetachRequest` | `PositionDetachRequestProcessor` |
| `PositionRedeemStatusToPendingRequest` | `PositionRedeemStatusPendingProcessor` |
| `PositionRedeemCancelRequest` | `PositionRedeemCancelProcessor` |
| `PositionEditRequest` | `PositionEditRequestAggregatedProcessor` |
| `DemoHierarchicalEditStopLossRequest` | `DemoHierarchicalEditStopLossProcessor` |
| `DemoHierarchicalEditTakeProfitRequest` | `DemoHierarchicalEditTakeProfitProcessor` |
| `DemoHierarchicalEditIsTslEnabledRequest` | `DemoHierarchicalEditIsTslEnabledProcessor` |

### Aggregated Processor Pattern

`PositionEditRequestAggregatedProcessor` is a multi-operation processor that:
1. Validates the request
2. Loads position, settings, instruments
3. Generates sub-operations: `EditStopLossUpdate`, `EditTakeProfitUpdate`, `EditTslEnabledUpdate`
4. Delegates to sub-processors: `PositionEditStopLossRequestProcessor`, `PositionEditTakeProfitRequestProcessor`, `PositionEditIsTslEnabledRequestProcessor`

### Bootstrap Registration (PES)

```csharp
public static class AggregatedBootstrap
{
    public static void RegisterDependencies(this IServiceCollection serviceCollection)
    {
        serviceCollection.RegisterBaseTypes();
        serviceCollection.AddHealthCheck();
        serviceCollection.AddCommonTypes();
        serviceCollection.AddRetryPolicy();
        serviceCollection.AddRepositories();
        serviceCollection.AddPublishers();
        serviceCollection.AddProviders();
        serviceCollection.AddValidators();
        serviceCollection.AddGenerators();
        serviceCollection.AddAdapters();
        serviceCollection.AddProcessors();
        serviceCollection.AddProcessorWorkers();
        serviceCollection.AddSuccessAndErrorHandling();
        serviceCollection.AddNotificationHandling();
    }
}
```

### Database Access Pattern (PES)

ADO.NET with stored procedures, retry decorators:

```csharp
public class BaseRepository
{
    private readonly string _connectionString;
    private readonly int _dbCommandTimeoutSeconds;

    protected async Task<int> ExecuteNonQueryAsync(
        string storedProcedureName, SqlParameter[] sqlParameters)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var sqlCommand = CreateSqlCommand(storedProcedureName, sqlParameters, connection);
        sqlCommand.CommandType = CommandType.StoredProcedure;
        await connection.OpenAsync();
        return await sqlCommand.ExecuteNonQueryAsync();
    }
}
```

Repositories wrapped with retry:
```csharp
public class EditStopLossRepositoryRetryDecorator : IEditStopLossRepository
{
    private readonly IEditStopLossRepository _inner;
    private readonly IAsyncPolicy _retryPolicy;

    public async Task<int> EditAsync(EditStopLossParams p)
        => await _retryPolicy.ExecuteAsync(() => _inner.EditAsync(p));
}
```

---

## ROS: Rate Order Service

### Architecture

ROS processes rate order open/close requests:

```
RabbitMQ (RateOrderServiceExecution queue)
  -> BasicRabbitNotificationProvider<MessageBase>
    -> RateOrderHostedServiceWorker
      -> RateOrderServiceMultiWorkerCluster
        -> RateOrderServiceWorker.ProcessWorkItem
          -> RateOrderEventRouter
            -> OpenRateOrderRequestProcessor / CloseRateOrderRequestProcessor
```

### Event Router (ROS)

```csharp
// Simplified routing
{ typeof(OrderOpenRequest), openProcessor.ProcessAsync },
{ typeof(OrderCloseRequest), closeProcessor.ProcessAsync }
```

### Database Calls (ROS)

Stored procedures only:

| Operation | Stored Procedure |
|-----------|-----------------|
| Open order | `[Trade].[OrdersAdd]` |
| Close order | `[Trade].[OrdersClientRemove]` |
| Get order details | `[Trade].[GetOrderDetails]` |

### Hybrid Service (ROS)

ROS is a hybrid: Web API host + background worker. The web host provides health endpoints while the worker processes RabbitMQ messages:

```csharp
Host.CreateDefaultBuilder(args)
    .ConfigureServices((context, serviceCollection) =>
    {
        serviceCollection.RegisterDependencies();
        serviceCollection.AddHostedService<RateOrderHostedServiceWorker>();
    })
    .ConfigureWebHostDefaults(webBuilder => webBuilder.UseStartup<Startup>());
```

Startup.cs provides `/ping`, `/version`, `/healthcheck` endpoints only.

### Testing Pattern (ROS)

```csharp
public class TestableRateOrderServiceWorker : RateOrderServiceWorker
{
    public new Task ProcessWorkItem(QueuedObject<IEvent> workItem)
        => base.ProcessWorkItem(workItem);
}

[Test]
public async Task ProcessWorkItem_SuccessfulProcessing_CallsRouteAsyncAndLogsLatency()
{
    // Arrange
    var mockRouter = new Mock<IEventRouter>();
    var worker = new TestableRateOrderServiceWorker(mockRouter.Object, ...);

    // Act
    await worker.ProcessWorkItem(queuedObject);

    // Assert
    mockRouter.Verify(r => r.RouteAsync(It.IsAny<IEvent>()), Times.Once);
}
```
