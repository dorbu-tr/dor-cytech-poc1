# Trading NuGet Package Reference

## Package Repositories & Version Variables

| Repository | Version Variable | Purpose |
|------------|------------------|---------|
| `trading-core` | `$(TradingCoreBuildVersion)` | Bootstrap, Config providers, SQL, Communication |
| `trading-shared` | `$(TradingSharedBuildVersion)` | Domain, Application, Infrastructure packages |
| `trading-framework` | `$(FrameworkBuildVersion)` | Framework utilities (Log, Metrics, Redis, etc.) |

**shared.props**:
```xml
<Project>
  <PropertyGroup>
    <TradingCoreBuildVersion>X.X.X</TradingCoreBuildVersion>
    <TradingSharedBuildVersion>X.X.X</TradingSharedBuildVersion>
    <FrameworkBuildVersion>X.X.X</FrameworkBuildVersion>
    <AssemblyName>eToro.Trading.$(MSBuildProjectName)</AssemblyName>
    <RootNamespace>eToro.Trading.$(MSBuildProjectName.Replace(" ", "_"))</RootNamespace>
  </PropertyGroup>
</Project>
```

## Source Code Discovery

Trading NuGet source repos are on GitHub. When investigating what types/interfaces exist, clone and search:
- [trading-framework](https://github.com/eToro/trading-framework) — `$(FrameworkBuildVersion)` packages
- [trading-shared](https://github.com/eToro/trading-shared) — `$(TradingSharedBuildVersion)` packages
- [trading-core](https://github.com/eToro/trading-core) — `$(TradingCoreBuildVersion)` packages

---

## "I need to..." Decision Guide

| I need to... | Package(s) | Version |
|--------------|-----------|---------|
| Log messages | `eToro.Trading.Framework.Log` | Framework |
| Report metrics | `eToro.Trading.Framework.Metrics` | Framework |
| Add health checks | `Bootstrap.HealthCheck` + `Application.HealthCheck.Extensions` | Core / Framework |
| Read from CCM | `Configuration.Providers.Ccm` | Core |
| Read KeyVault secrets | `Configuration.Providers.KeyVault` | Core |
| Connect to SQL | `Sql.DbAccess` + `Sql.ErrorsDetection` | Core |
| Use DB read replicas | `Configuration.Providers.DbInstanceSelector` | Core |
| Retry logic for DB | `RetryHandling` | Core |
| RabbitMQ messaging | `Framework.RabbitMQ` + `Bootstrap.RabbitMQ` | Framework / Core |
| Redis caching | `Framework.RedisClient.StackExchange` | Framework |
| Azure Event Hub | `Communication.EventHub` | Core |
| Azure Service Bus | `Communication.ServiceBus` | Core |
| HTTP resilience (retry/CB) | `Polly` + `Polly.Extensions` (NOT Framework.FaultTolerance) | NuGet.org |
| SQL retry | `Framework.FaultTolerance` (SQL only — uses Enterprise Library RetryPolicy) | Framework |
| Leader election | `Framework.LeaderElection` | Framework |
| Saga pattern | `Framework.Saga.Core.Async` | Framework |
| Standard entities | `Domain.Entities` | Shared |
| Standard messages | `Application.Messages` | Shared |
| Standard repositories | `Infrastructure.Repositories` | Shared |
| Application Insights | `Bootstrap.ApplicationInsights` | Core |

---

## Package Selection by Service Type

**Database Service:**
```xml
<!-- Bootstrap -->
<PackageReference Include="eToro.Trading.Bootstrap.Models" Version="$(TradingCoreBuildVersion)" />
<PackageReference Include="eToro.Trading.Bootstrap.HealthCheck" Version="$(TradingCoreBuildVersion)" />
<PackageReference Include="eToro.Trading.Configuration.Providers.Ccm" Version="$(TradingCoreBuildVersion)" />
<PackageReference Include="eToro.Trading.Configuration.Providers.KeyVault" Version="$(TradingCoreBuildVersion)" />
<!-- Application -->
<PackageReference Include="eToro.Trading.Application.HealthCheck.Extensions" Version="$(FrameworkBuildVersion)" />
<!-- Infrastructure -->
<PackageReference Include="eToro.Trading.Sql.DbAccess" Version="$(TradingCoreBuildVersion)" />
<PackageReference Include="eToro.Trading.Sql.ErrorsDetection" Version="$(TradingCoreBuildVersion)" />
<PackageReference Include="eToro.Trading.RetryHandling" Version="$(TradingCoreBuildVersion)" />
<PackageReference Include="eToro.Trading.Infrastructure.Repositories" Version="$(TradingSharedBuildVersion)" />
<!-- Common -->
<PackageReference Include="eToro.Trading.Framework.Log" Version="$(FrameworkBuildVersion)" />
<PackageReference Include="eToro.Trading.Framework.Metrics" Version="$(FrameworkBuildVersion)" />
```

**Aggregator Service (no DB):**
```xml
<!-- Bootstrap (same) -->
<!-- Application (same) -->
<!-- Infrastructure - NO SQL packages, use IHttpClientFactory + Polly instead -->
<PackageReference Include="Microsoft.Extensions.Http" Version="8.0.0" />
<PackageReference Include="Polly" Version="8.5.0" />
<PackageReference Include="Polly.Extensions" Version="8.5.0" />
<!-- NOTE: Infrastructure.Providers contains domain-specific providers, NOT a REST base class -->
<!-- NOTE: Framework.FaultTolerance is for SQL retry only, NOT for HTTP resilience -->
<!-- Common (same) -->
```

**Messaging Service (+ RabbitMQ):**
```xml
<PackageReference Include="eToro.Trading.Framework.RabbitMQ" Version="$(FrameworkBuildVersion)" />
<PackageReference Include="eToro.Trading.Bootstrap.RabbitMQ" Version="$(TradingCoreBuildVersion)" />
```

---

## Infrastructure NuGets Checklist

**Bootstrap layer:**
```xml
<PackageReference Include="eToro.Trading.Bootstrap.Models" Version="$(TradingCoreBuildVersion)" />
<PackageReference Include="eToro.Trading.Bootstrap.HealthCheck" Version="$(TradingCoreBuildVersion)" />
<PackageReference Include="eToro.Trading.Configuration.Providers.Ccm" Version="$(TradingCoreBuildVersion)" />
<PackageReference Include="eToro.Trading.Configuration.Providers.KeyVault" Version="$(TradingCoreBuildVersion)" />
<PackageReference Include="eToro.Trading.Configuration.Providers.Scb" Version="$(TradingCoreBuildVersion)" />
```

**Application layer:**
```xml
<PackageReference Include="eToro.Trading.Application.HealthCheck.Extensions" Version="$(FrameworkBuildVersion)" />
<PackageReference Include="AutoMapper.Extensions.Microsoft.DependencyInjection" Version="11.0.0" />
<PackageReference Include="FluentValidation" Version="11.3.0" />
<PackageReference Include="Polly" Version="8.5.0" />
<PackageReference Include="Scrutor" Version="4.2.0" />
```

**Infrastructure layer:**
```xml
<PackageReference Include="eToro.Trading.Infrastructure.Providers" Version="$(TradingSharedBuildVersion)" />
<PackageReference Include="eToro.Trading.Infrastructure.Repositories" Version="$(TradingSharedBuildVersion)" />
<PackageReference Include="eToro.Trading.Sql.DbAccess" Version="$(TradingCoreBuildVersion)" />
<PackageReference Include="eToro.Trading.Sql.Persistors" Version="$(TradingCoreBuildVersion)" />
```

**Domain layer:**
```xml
<PackageReference Include="eToro.Trading.Domain.Repositories" Version="$(TradingSharedBuildVersion)" />
<PackageReference Include="eToro.Trading.Utils" Version="$(FrameworkBuildVersion)" />
<PackageReference Include="FluentValidation" Version="11.3.0" />
```

---

## Template CLI Usage (`dotnet new`)

Install: `dotnet new -i eToro.Trading.Templates`

Create: `dotnet new etoroservice -n <SolutionName> -o <FolderPath> [options]`

Example: `dotnet new etoroservice -n TestService -o C:\Projects\MyTestService -ir true -id true -ids true`

**Available Options:**

| Flag | Name | Default | Description |
|------|------|---------|-------------|
| `-is` | install-swagger | `false` | Add Swagger/OpenAPI documentation |
| `-iws` | include-worker-service | `false` | Add background worker service |
| `-iai` | include-app-insights | `false` | Add Application Insights telemetry |
| `-iasa` | include-app-secret-auth | `false` | Add AppSecret authentication middleware |
| `-id` | include-db | `false` | Add database access layer (eToro SQL) |
| `-ids` | include-db-selector | `false` | Add database selector pattern |
| `-ir` | include-rabbit | `false` | Add RabbitMQ messaging support |
| `-inr` | include-redis | `false` | Add Redis caching support |
| `-caw` | configure-as-webapi | `true` | Configure as Web API (vs console app) |

**Workflow:**
1. Create new GitHub repository under eToro organization, clone locally
2. Generate service: `dotnet new etoroservice -n <ServiceName> -o <ClonedFolder> [options]`
3. Implement business logic following constitution principles
4. Push, configure CI/CD (Jenkins), setup branch policies

---

## Package Anti-Patterns

| Anti-Pattern | Correct Approach |
|--------------|------------------|
| SQL packages in Aggregator service | Don't include if no DB access |
| `eToro.Trading.Common` for everything | Use specific layer packages |
| Mixing StackExchange and ServiceStack Redis | Pick one consistently |
| `Framework.Log` without `Bootstrap.Extensions.Logger` | Use both together — `AddFrameworkLogger` + `RegisterGenericFrameworkLoggers` |
| Direct CCM access instead of Configuration.Providers.Ccm | Use the config provider |
| Framework packages in Domain layer | Domain references only Domain packages |
| `Framework.FaultTolerance` for HTTP calls | It's SQL-only — use Polly for HTTP resilience |
| `Infrastructure.Providers` as REST base class | It has domain providers, not a base class — use `IHttpClientFactory` + `HttpClient` |
| Referencing `MonitorWrapper` | Does not exist — use `IMetrics` (Counter/Gauge/Timer) directly |
| Referencing `AuthorizationConfiguration` from NuGets | Not in any NuGet — define per-service in `Api/Configuration/` |
