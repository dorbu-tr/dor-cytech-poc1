using eToro.Trading.{ServiceName}.Application.Services;
using eToro.Trading.{ServiceName}.Application.Authorization;
using eToro.Trading.{ServiceName}.Application.Mapper;
using eToro.Trading.{ServiceName}.Domain.Validators;
using eToro.Trading.{ServiceName}.Infrastructure.Repositories;
using eToro.Trading.{ServiceName}.Domain.Repositories;
using FluentValidation;
using Microsoft.Extensions.DependencyInjection;
using Scrutor;

namespace eToro.Trading.{ServiceName}.Bootstrap.Bootstrappers;

/// <summary>
/// Static bootstrapper pattern (used by single-API services like trading-opstool-api, trading-settings-api).
/// For dual-API services, use IBootstrap/BaseBootstrap instead.
/// </summary>
public static class BasicBootstrap
{
    public static IServiceCollection RegisterTypes(this IServiceCollection serviceCollection)
    {
        serviceCollection.AddRepositories();
        serviceCollection.AddServices();
        serviceCollection.AddMappers();
        serviceCollection.RegisterValidators();
        serviceCollection.AddRetryPolicy();
        serviceCollection.RegisterLoggers();
        return serviceCollection;
    }

    private static IServiceCollection AddRepositories(this IServiceCollection services)
    {
        services.AddSingleton<I{Feature}Repository, Db{Feature}Repository>();
        services.Decorate<I{Feature}Repository, {Feature}CachedRepository>();
        return services;
    }

    private static IServiceCollection AddServices(this IServiceCollection services)
    {
        services.AddSingleton<I{Feature}Service, {Feature}Service>();
        return services;
    }

    private static IServiceCollection AddMappers(this IServiceCollection services)
    {
        services.AddAutoMapper(typeof({Feature}MappingProfile).Assembly);
        return services;
    }

    private static IServiceCollection RegisterValidators(this IServiceCollection services)
    {
        services.AddValidatorsFromAssemblyContaining<{Feature}Validator>();
        return services;
    }
}
