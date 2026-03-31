# Saga Patterns

## Saga Architecture

A saga orchestrates a long-running operation as a sequence of steps, each advancing the state machine.

```
ISaga (interface)
  -> BaseMirrorSaga (base class with step management)
    -> MirrorCloseSaga (concrete implementation)
      -> IStep[] (ordered steps)
        -> StartedStep, CloseOrdersStep, HandlePositionsStep, AllPositionsClosedStep
```

## Saga Class Pattern

```csharp
public class MirrorCloseSaga : BaseMirrorSaga
{
    public MirrorCloseSaga(
        ISagaCtor parameters,
        int currentStepIndex,
        MirrorCloseActionType mirrorCloseActionType,
        ILogger logger,
        IMirrorRepository repository,
        IQueueClientProvider queueClientProvider,
        ISagaTimeoutValidator sagaTimeoutValidator,
        ISplitManager splitManager)
        : base(parameters, mirrorCloseActionType, currentStepIndex,
            CreateSteps(parameters, mirrorCloseActionType, logger, repository, ...))
    { }

    private static IEnumerable<IStep> CreateSteps(...)
    {
        yield return new StartedStep(parameters, logger, queueClientProvider, repository, actionType);
        yield return new CloseOrdersStep(parameters, logger, repository, cancelProvider, cancelHandler);
        yield return new HandlePositionsStep(parameters, ...,
            CreateAllOrdersClosedStep(...),
            CreateDetachPositionsStep(...),
            actionType, sagaTimeoutValidator);
        yield return new AllPositionsClosedStep(parameters, logger, queueClientProvider, repository, actionType);
    }
}
```

## Step Pattern

Each step implements `IStep` and handles events for its phase:

```csharp
public class StartedStep : IStep
{
    public async Task<StepResult> HandleAsync(IEvent @event)
    {
        // 1. Execute step logic (e.g., deactivate mirror)
        await _repository.DeactivateMirrorAsync(_sagaKey);

        // 2. Publish downstream commands
        await _queueClient.PublishAsync(command);

        // 3. Return next step transition
        return StepResult.MoveToNextStep();
        // OR: return StepResult.Stay(); (wait for more events)
        // OR: return StepResult.Complete(); (saga done)
    }
}
```

## SagaFactory

Creates saga instances from persisted state or new requests:

```csharp
public class SagaFactory : ISagaFactory
{
    public ISaga CreateSaga(MirrorSagaKey key, MirrorCloseSagaData data, int currentStepIndex)
    {
        return new MirrorCloseSaga(
            new SagaCtor(key, data),
            currentStepIndex,
            data.MirrorCloseActionType,
            _logger, _repository, _queueClientProvider,
            _sagaTimeoutValidator, _splitManager);
    }
}
```

## Saga Cache (In-Memory + DB)

`MirrorSagaCache` wraps a `ConcurrentDictionary` backed by SQL persistence:

```csharp
public class MirrorSagaCache : IMirrorSagaRepository
{
    private readonly ConcurrentDictionary<int, ISaga> _cache = new();
    private readonly MirrorSagaRepository _dbRepository;

    public ISaga GetOrCreate(MirrorSagaKey key, MirrorCloseSagaData data)
    {
        if (_cache.TryGetValue(key.MirrorID, out ISaga existing))
            return existing;

        var saga = _sagaFactory.CreateSaga(key, data, currentStepIndex: 0);
        _cache.TryAdd(key.MirrorID, saga);
        _dbRepository.SaveAsync(key, data);
        return saga;
    }

    public void Archive(int mirrorId)
    {
        _cache.TryRemove(mirrorId, out _);
        _dbRepository.ArchiveAsync(mirrorId);
    }
}
```

## Recovery Pattern

Sagas must handle process restarts. Recovery loads incomplete sagas from DB:

```csharp
public class RecoveryService : IHostedService
{
    private readonly ILeaderElectionManager _leaderElection;
    private readonly ISagaDbRepository _dbRepository;

    public async Task RecoverAsync()
    {
        if (!_leaderElection.IsLeader) return;

        var incompleteSagas = await _dbRepository.GetAllSagasByModAndResult(mod, result);
        foreach (var sagaData in incompleteSagas)
        {
            var saga = _sagaFactory.CreateSaga(sagaData.Key, sagaData.Data, sagaData.CurrentStepIndex);
            _sagaCache.TryAdd(sagaData.Key.MirrorID, saga);
            // Inject recovery event to resume processing
            await saga.HandleAsync(new RecoveryEvent());
        }
    }
}
```

## Bootstrap Registration

```csharp
public static IServiceCollection RegisterSagaServices(this IServiceCollection services)
{
    services.AddSingleton<ISagaFactory, SagaFactory>();
    services.AddSingleton<IMirrorSagaRepository, MirrorSagaCache>();
    services.AddSingleton<ISagaDbRepository, SagaDbRepository>();
    services.AddSingleton<IRecoveryService, RecoveryService>();
    services.AddSingleton(CreateLeaderElectionManager);
    return services;
}
```
