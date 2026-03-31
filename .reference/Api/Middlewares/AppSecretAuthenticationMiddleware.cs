using System;
using System.Linq;
using System.Net;
using System.Threading.Tasks;
using eToro.Trading.Opstool.Bootstrap.Configurations;
using Framework.Log;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Primitives;

namespace eToro.Trading.Opstool.WebApi.Middlewares;

public sealed class AppSecretAuthenticationMiddleware
{
    private readonly ILogger<AppSecretAuthenticationMiddleware> _logger;
    private readonly RequestDelegate _next;
    private readonly string _appSecret;

    public AppSecretAuthenticationMiddleware(
        RequestDelegate next,
        ILogger<AppSecretAuthenticationMiddleware> logger,
        AuthorizationConfiguration authorizationConfiguration)
    {
        _next = next;
        _logger = logger;
        _appSecret = authorizationConfiguration.AppSecret;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var controller = context.Request.RouteValues["controller"]?.ToString();
        if (controller != null)
        {
            var isAuthorized = ExtractRequestData(context, out var appSecrets);
            if (isAuthorized)
                isAuthorized = Authorize(appSecrets.FirstOrDefault());

            if (!isAuthorized)
            {
                context.Response.StatusCode = (int)HttpStatusCode.Unauthorized;
                return;
            }
        }

        await _next(context);
    }

    private bool Authorize(string appSecret) => appSecret == _appSecret;

    private bool ExtractRequestData(HttpContext context, out StringValues appSecrets)
    {
        try
        {
            appSecrets = context.Request.Headers
                .First(h => h.Key.Equals(
                    AuthorizationConfiguration.AuthorizationHeaderName,
                    StringComparison.OrdinalIgnoreCase))
                .Value;
        }
        catch (Exception ex)
        {
            _logger.LogError(
                $"Request missing {AuthorizationConfiguration.AuthorizationHeaderName} header",
                null, ex);
            appSecrets = default;
            return false;
        }
        return true;
    }
}
