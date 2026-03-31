using System.Net;
using Framework.Log;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Primitives;

namespace dor-cytech-poc1.Api.Middlewares;

public sealed class AppSecretAuthenticationMiddleware
{
    private readonly ILogger<AppSecretAuthenticationMiddleware> _logger;
    private readonly RequestDelegate _next;
    private readonly string _appSecret;

    public AppSecretAuthenticationMiddleware(
        RequestDelegate next,
        ILogger<AppSecretAuthenticationMiddleware> logger,
        Configuration.AuthorizationConfiguration authorizationConfiguration)
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
            if (!TryExtractAppSecret(context, out var appSecret) || !Authorize(appSecret))
            {
                context.Response.StatusCode = (int)HttpStatusCode.Unauthorized;
                return;
            }
        }

        await _next(context);
    }

    private bool Authorize(string appSecret) => appSecret == _appSecret;

    private bool TryExtractAppSecret(HttpContext context, out string appSecret)
    {
        appSecret = null;
        if (!context.Request.Headers.TryGetValue("Authorization", out var values))
        {
            _logger.LogWarn("Request missing Authorization header");
            return false;
        }

        appSecret = values.FirstOrDefault();
        return appSecret != null;
    }
}
