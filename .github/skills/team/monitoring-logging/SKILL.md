<!-- AUTO-GENERATED from .cursor/ canonical source. Do not edit directly. -->
<!-- Source: .cursor/skills/team/monitoring-logging/SKILL.md | Regenerate: .specify/scripts/sh/sync-ai-rules.sh copilot -->
<!-- TEAM-SPECIFIC: This file implements logging/monitoring patterns using eToro Trading Framework.Log and Framework.Metrics. Verified against trading-framework GitHub source (ILogger.cs, LoggerWrapper.cs, IMetrics.cs). -->

# Trading Monitoring & Logging Patterns

## When to Use This Skill

Use when implementing: logging, structured logging, Framework.Log ILogger, LoggerWrapper, IMetrics metrics, ITicksTrail latency tracking, log4net configuration, DI registration for loggers.

## Logging Stack (NON-NEGOTIABLE)

Use `Framework.Log.ILogger<T>` with `log4net.config` — NOT `Microsoft.Extensions.Logging`.

### ILogger Method Signatures (from Framework.Log source)

**`ILogger` (non-generic):**
```csharp
void LogDebug(string message);
void LogInfo(string message);
void LogWarn(string message);
void LogError(string message);
void LogError(string message, bool printStackTraceOnError);
void LogError(string message, Exception exception);
void LogFatal(string message);
void LogFatal(string message, Exception exception);
```

**`ILogger<T>` (generic, extends `ILogger`)** — adds structured overloads with caller info:
```csharp
void LogWarn(string message, object entry, [CallerMemberName] string caller = null);
void LogInfo(string message, object entry, [CallerMemberName] string caller = null);
void LogDebug(string message, object entry, [CallerMemberName] string caller = null);
void LogError(string message, object entry, Exception exception);
void LogError(string message, object entry, [CallerMemberName] string caller = null);
```

### Usage Pattern

```csharp
using Framework.Log;

public sealed class MyService
{
    private readonly ILogger<MyService> _logger;

    public MyService(ILogger<MyService> logger)
    {
        _logger = logger;
    }

    public async Task ProcessAsync(int id)
    {
        _logger.LogInfo($"Processing item {id}");
        try
        {
            // business logic
            _logger.LogInfo($"Successfully processed item {id}");
        }
        catch (Exception ex)
        {
            _logger.LogError($"Failed to process item {id}", null, ex);
            throw;
        }
    }
}
```

## Logger Type Resolution

Ambiguity between `Framework.Log.ILogger` (eToro) and `Microsoft.Extensions.Logging.ILogger<T>` (Microsoft).

**Rule**: In service/repository/controller files, ONLY import `Framework.Log`. The Api `.csproj` should have `<Using Remove="Microsoft.Extensions.Logging" />` to prevent ambiguity when `ImplicitUsings` is enabled.

```csharp
// CORRECT - service files
using Framework.Log;
private readonly ILogger<MyService> _logger;

// CORRECT - Program.cs bootstrap (needs both namespaces)
using Framework.Log;
using eToro.Trading.Bootstrap.Logger;
builder.Host.AddFrameworkLogger(new LoggerWrapper())
    .ConfigureLogging((_, configLogging) => { configLogging.AddLog4Net(); });
```

## DI Registration (NON-NEGOTIABLE)

Both methods come from `eToro.Trading.Bootstrap.Extensions.Logger` package (`eToro.Trading.Bootstrap.Logger` namespace):

```csharp
// Program.cs — register the framework logger on the host
builder.Host.AddFrameworkLogger(new LoggerWrapper())
    .ConfigureLogging((_, configLogging) => { configLogging.AddLog4Net(); });

// After builder.Host setup — register generic ILogger<T> in DI
builder.Services.RegisterGenericFrameworkLoggers();
```

`RegisterGenericFrameworkLoggers()` maps the open generic `ILogger<>` → `LoggerWrapper<>`, so any constructor taking `ILogger<MyService>` gets a `LoggerWrapper<MyService>` injected.

Without this registration, the app will fail at runtime with:
```
Unable to resolve service for type 'Framework.Log.ILogger`1[...]'
```

## log4net.config

Ship a `log4net.config` in the Api project root:
```xml
<log4net>
  <appender name="ConsoleAppender" type="log4net.Appender.ConsoleAppender">
    <layout type="log4net.Layout.PatternLayout">
      <conversionPattern value="%date [%thread] %-5level %logger - %message%newline" />
    </layout>
  </appender>
  <root>
    <level value="INFO" />
    <appender-ref ref="ConsoleAppender" />
  </root>
</log4net>
```

## Metrics (IMetrics from Framework.Metrics)

> **There is no `MonitorWrapper` in any Trading NuGet.** Use `IMetrics` directly for StatsD-based metrics.

**IMetrics interface** (3 methods):
```csharp
public interface IMetrics
{
    void Counter(string name, string metricType, int count = 1, Dictionary<string, string> data = null);
    void Gauge(string name, string metricType, double value = 0.0, Dictionary<string, string> data = null);
    void Timer(string name, string metricType, int milliseconds, Dictionary<string, string> data = null);
}
```

**Usage pattern for service monitoring:**
```csharp
public sealed class MyService
{
    private readonly IMetrics _metrics;

    public async Task<Result> ProcessAsync(int id)
    {
        _metrics.Counter("my_service.process", "invocations");
        var sw = Stopwatch.StartNew();
        try
        {
            var result = await DoWorkAsync(id);
            sw.Stop();
            _metrics.Timer("my_service.process", "duration", (int)sw.ElapsedMilliseconds);
            return result;
        }
        catch (Exception)
        {
            _metrics.Counter("my_service.process.errors", "errors");
            throw;
        }
    }
}
```

## ITicksTrail for Latency Tracking

Controllers use `ITicksTrail` to track request latency:

```csharp
public sealed class InstrumentsController : ControllerBase
{
    private readonly ITicksTrail _ticksTrail;

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        _ticksTrail.Start();
        var result = await _service.GetAllAsync();
        _ticksTrail.Stop();
        return Ok(result);
    }
}
```

## Log Levels

| Level | Method | Usage |
|-------|--------|-------|
| FATAL | `LogFatal` | Application-ending errors |
| ERROR | `LogError` | Unhandled exceptions |
| WARN | `LogWarn` | Handled exceptions, degraded service |
| INFO | `LogInfo` | Request/response summaries |
| DEBUG | `LogDebug` | Detailed flow (dev only) |

## Required NuGet Packages

```xml
<PackageReference Include="eToro.Trading.Bootstrap.Extensions.Logger" Version="$(TradingCoreBuildVersion)" />
<PackageReference Include="etoro.Trading.Framework.Log.Extension.Json" Version="$(FrameworkBuildVersion)" />
<PackageReference Include="eToro.Trading.Framework.Metrics" Version="$(FrameworkBuildVersion)" />
<PackageReference Include="Microsoft.Extensions.Logging.Log4Net.AspNetCore" Version="6.1.0" />
```
