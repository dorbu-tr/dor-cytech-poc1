using System.Net;
using Framework.Log;
using Microsoft.AspNetCore.Http;
using Newtonsoft.Json;

namespace dor-cytech-poc1.Api.Middlewares;

public abstract class HttpStatusException : Exception
{
    public abstract HttpStatusCode StatusCode { get; }
    public abstract string Title { get; }
    protected HttpStatusException(string message) : base(message) { }
    protected HttpStatusException(string message, Exception inner) : base(message, inner) { }
}

public abstract class NotFoundException : HttpStatusException
{
    public override HttpStatusCode StatusCode => HttpStatusCode.NotFound;
    public override string Title => "Resource not found";
    protected NotFoundException(string message) : base(message) { }
}

public abstract class BadRequestException : HttpStatusException
{
    public override HttpStatusCode StatusCode => HttpStatusCode.BadRequest;
    public override string Title => "Bad request";
    protected BadRequestException(string message) : base(message) { }
}

public abstract class ServiceUnavailableException : HttpStatusException
{
    public override HttpStatusCode StatusCode => HttpStatusCode.ServiceUnavailable;
    public override string Title => "Service temporarily unavailable";
    protected ServiceUnavailableException(string message) : base(message) { }
}

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
            HttpStatusException httpEx => ((int)httpEx.StatusCode, httpEx.Title),
            _ => ((int)HttpStatusCode.InternalServerError, "Unhandled exception")
        };

        httpContext.Response.StatusCode = statusCode;

        var response = JsonConvert.SerializeObject(new
        {
            title,
            status = statusCode,
            detail = exception.Message
        });

        _logger.LogError(response, null, exception);
        await httpContext.Response.WriteAsync(response);
    }
}
