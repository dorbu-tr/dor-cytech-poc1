using System;
using System.Net;
using System.Threading.Tasks;
using eToro.Trading.Opstool.WebApi.Headers;
using Framework.Log;
using Microsoft.AspNetCore.Http;
using Microsoft.Rest.TransientFaultHandling;
using Newtonsoft.Json;

namespace eToro.Trading.Opstool.WebApi.Middlewares;

public sealed class ExceptionHandlingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ExceptionHandlingMiddleware> _logger;

    public ExceptionHandlingMiddleware(RequestDelegate next, ILogger<ExceptionHandlingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext httpContext)
    {
        try
        {
            await _next(httpContext);
        }
        catch (Exception ex)
        {
            await HandleExceptionAsync(httpContext, ex);
        }
    }

    private async Task HandleExceptionAsync(HttpContext httpContext, Exception exception)
    {
        httpContext.Response.ContentType = "application/json";

        var (statusCode, title) = exception switch
        {
            HeadersValidationException headerEx =>
                ((int)headerEx.StatusCode, "Header validation error"),
            HttpRequestWithStatusException httpEx =>
                ((int)httpEx.StatusCode, nameof(HttpRequestWithStatusException)),
            _ => ((int)HttpStatusCode.InternalServerError, "Unhandled exception")
        };

        httpContext.Response.StatusCode = statusCode;

        var response = JsonConvert.SerializeObject(new
        {
            title,
            status = statusCode,
            detail = exception.Message
        });

        _logger.LogError(response);
        await httpContext.Response.WriteAsync(response);
    }
}
