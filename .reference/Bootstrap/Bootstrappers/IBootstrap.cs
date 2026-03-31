using Microsoft.Extensions.DependencyInjection;

namespace eToro.Trading.{ServiceName}.Bootstrap;

/// <summary>
/// Bootstrap abstraction used by modern dual-API services (trading-orders-api, trading-copy-api).
/// Customer and Admin APIs each have their own IBootstrap implementation sharing a BaseBootstrap.
/// For single-API services, use static extension methods on IServiceCollection instead.
/// </summary>
public interface IBootstrap
{
    void RegisterTypes(IServiceCollection serviceCollection);
    void RampUp(IServiceProvider srv);
}

public abstract class BaseBootstrap : IBootstrap
{
    protected readonly Framework.Log.ILogger _logger;

    protected BaseBootstrap(Framework.Log.ILogger logger)
    {
        _logger = logger;
    }

    public void RegisterTypes(IServiceCollection serviceCollection)
    {
        RegisterSharedTypes(serviceCollection);
        InnerRegisterTypes(serviceCollection);
    }

    protected virtual void RegisterSharedTypes(IServiceCollection serviceCollection)
    {
        serviceCollection.AddSingleton<I{Feature}Service, {Feature}Service>();
    }

    protected abstract void InnerRegisterTypes(IServiceCollection serviceCollection);

    public virtual void RampUp(IServiceProvider srv)
    {
        _logger.LogInfo($"{GetType().Name} ramp-up complete");
    }
}
