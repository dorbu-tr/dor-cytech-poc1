using System.Net.Http.Json;
using Framework.Log;
using Polly;

namespace eToro.Trading.{ServiceName}.Infrastructure.Providers.Concrete;

/// <summary>
/// REST provider using IHttpClientFactory typed client + Polly ResiliencePipeline.
/// 
/// Two registration patterns exist in production Trading services:
///
/// Pattern 1 — Typed client (modern, from trading-orders-api):
///   services.AddHttpClient&lt;I{ApiName}Provider, {ApiName}Provider&gt;(name, (sp, client) => { ... });
///
/// Pattern 2 — Factory method (from trading-settings-api, trading-data-api):
///   services.AddSingleton&lt;I{ApiName}Provider&gt;(Create{ApiName}Provider);
///   private static I{ApiName}Provider Create{ApiName}Provider(IServiceProvider sp) { ... }
/// </summary>
public sealed class {ApiName}Provider : I{ApiName}Provider
{
    private readonly HttpClient _httpClient;
    private readonly ResiliencePipeline _resiliencePipeline;
    private readonly ILogger<{ApiName}Provider> _logger;

    public {ApiName}Provider(
        HttpClient httpClient,
        ResiliencePipeline resiliencePipeline,
        ILogger<{ApiName}Provider> logger)
    {
        _httpClient = httpClient;
        _resiliencePipeline = resiliencePipeline;
        _logger = logger;
    }

    public async Task<{ApiName}Response> GetByIdAsync(int id, CancellationToken cancellationToken = default)
    {
        return await _resiliencePipeline.ExecuteAsync(async ct =>
        {
            _logger.LogInfo($"Calling {ApiName} API for id={id}");
            var response = await _httpClient.GetAsync($"/api/v1/resource/{id}", ct);
            response.EnsureSuccessStatusCode();
            return await response.Content.ReadFromJsonAsync<{ApiName}Response>(ct);
        }, cancellationToken);
    }

    public async Task<List<{ApiName}Response>> GetAllAsync(CancellationToken cancellationToken = default)
    {
        return await _resiliencePipeline.ExecuteAsync(async ct =>
        {
            _logger.LogInfo("Calling {ApiName} API for all resources");
            var response = await _httpClient.GetAsync("/api/v1/resource", ct);
            response.EnsureSuccessStatusCode();
            return await response.Content.ReadFromJsonAsync<List<{ApiName}Response>>(ct);
        }, cancellationToken);
    }
}

// ============================================================================
// DI REGISTRATION — Pattern 1: Typed Client (preferred for new services)
// ============================================================================
//
// public static class HttpClientBootstrap
// {
//     public static IServiceCollection AddHttpClients(this IServiceCollection services)
//     {
//         services.AddHttpClient<I{ApiName}Provider, {ApiName}Provider>("{ApiName}", (sp, client) =>
//         {
//             var config = sp.GetRequiredService<{ApiName}Configuration>();
//             client.BaseAddress = new Uri(config.Url);
//             client.Timeout = TimeSpan.FromSeconds(config.TimeoutSeconds);
//         });
//         return services;
//     }
// }

// ============================================================================
// DI REGISTRATION — Pattern 2: Factory Method (from trading-settings-api)
// ============================================================================
//
// public static class ProvidersBootstrap
// {
//     public static IServiceCollection RegisterProviders(this IServiceCollection services)
//     {
//         services.AddSingleton<I{ApiName}Provider>(Create{ApiName}Provider);
//         return services;
//     }
//
//     private static I{ApiName}Provider Create{ApiName}Provider(IServiceProvider sp)
//     {
//         var logger = sp.GetRequiredService<ILogger<{ApiName}Provider>>();
//         var config = sp.GetRequiredService<{ApiName}Configuration>();
//         var pipeline = sp.GetRequiredService<ResiliencePipeline>();
//         var httpClientFactory = sp.GetRequiredService<IHttpClientFactory>();
//         var httpClient = httpClientFactory.CreateClient("{ApiName}");
//         httpClient.BaseAddress = new Uri(config.Url);
//         httpClient.Timeout = TimeSpan.FromSeconds(config.TimeoutSeconds);
//         return new {ApiName}Provider(httpClient, pipeline, logger);
//     }
// }

// ============================================================================
// POLLY RESILIENCE PIPELINE (Polly v8 — from trading-opstool-api)
// ============================================================================
//
// public static class RetryPolicyBootstrap
// {
//     public static IServiceCollection AddRetryPolicy(this IServiceCollection services)
//     {
//         services.AddSingleton(sp =>
//         {
//             var config = sp.GetRequiredService<RetryPolicyConfiguration>();
//             return new ResiliencePipelineBuilder()
//                 .AddRetry(new RetryStrategyOptions
//                 {
//                     MaxRetryAttempts = config.NumOfRetries,
//                     Delay = config.TimeBetweenRetries,
//                     BackoffType = DelayBackoffType.Exponential,
//                     UseJitter = true
//                 })
//                 .AddTimeout(TimeSpan.FromSeconds(config.CommandTimeout))
//                 .Build();
//         });
//         return services;
//     }
// }
