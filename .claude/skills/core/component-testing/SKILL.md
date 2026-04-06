<!-- AUTO-GENERATED from .cursor/ canonical source. Do not edit directly. -->
<!-- Source: .cursor/skills/core/component-testing/SKILL.md | Regenerate: .specify/scripts/sh/sync-ai-rules.sh claude-code -->
---
name: component-testing
description: Component test architecture patterns using mocked external providers and an in-process test server. Use when implementing component tests, test bootstrapper, mock providers, or test API providers. Component tests must mock all external dependencies and run locally with dotnet test --filter Category=ComponentTests.
---

# Component Testing Patterns

## Component Test Architecture

Component tests run the API in-memory with mocked external dependencies (providers, databases, message brokers). They verify the full request pipeline: routing, validation, serialization, service logic, and response formatting.

### 1. Startup.cs
The test startup creates an instance of the test bootstrapper and wires it into the test host:
```csharp
public class Startup : IStartup
{
    private readonly ComponentTestBootstrapper _bootstrapper = new();

    public void ConfigureServices(IServiceCollection services)
        => _bootstrapper.ConfigureServicesAsync(services).GetAwaiter().GetResult();

    public void Configure(IApplicationBuilder app)
        => _bootstrapper.ConfigureAsync(app, null).GetAwaiter().GetResult();
}
```

### 2. ComponentTestBootstrapper
Extends the main API Bootstrapper with mocked dependencies:
- Override config management initialization to use mocks
- Override auth to use test auth mocking
- Override external providers with mock registrations
- Empty overrides for Swagger, telemetry, and other non-essential middleware

### 3. TestsBase (NOT TestBase)
```csharp
[TestFixture]
[Category("ComponentTests")]
public class TestsBase : ComponentTestBase<Startup>
{
    protected IServiceApiProvider ServiceApiProvider;
    protected Mock<IExternalApiProvider> ExternalApiProviderMock;

    [OneTimeSetUp]
    public void Init()
    {
        ServiceApiProvider = new ServiceApiProvider(
            MonitorBuilder.CreateMock(), TestClient.Client);
        ExternalApiProviderMock = GetServiceMock<IExternalApiProvider>();
    }

    [SetUp]
    public new void SetUp()
    {
        ExternalApiProviderMock.Reset();
    }
}
```

### Critical TestsBase Rules
| Correct | FORBIDDEN |
|---------|-----------|
| `TestsBase : ComponentTestBase<Startup>` | No inheritance or custom TestServer |
| `TestClient.Client` | `TestServer.CreateClient()` |
| `GetServiceMock<T>()` | `GetService<T>()` + `Mock.Get()` |
| `.Reset()` | `.Invocations.Clear()` |
| `[OneTimeSetUp] public void Init()` | `public void OneTimeSetUp()` |
| `[SetUp] public new void SetUp()` | `public virtual void SetUp()` |

## Test API Provider Pattern

Test API provider MUST inherit from a REST provider base class:
- Two constructors: `(IMonitor, string baseUrl)` and `(IMonitor, HttpClient)`
- Returns `Task<RestResponse<T>>`
- Uses `RestRequest.QueryString` for query params
- Auth header WITHOUT "Bearer" prefix

## Test Class Pattern

```csharp
[TestFixture]
[Category("ComponentTests")]
public class {Feature}Tests : TestsBase
{
    [Test]
    public async Task FullScenario()
    {
        // Arrange
        ExternalApiProviderMock.Setup(x => x.GetDataAsync(It.IsAny<int>()))
            .ReturnsAsync(Consts.DefaultResponse);

        // Act
        var response = await ServiceApiProvider.GetFeatureAsync(request);

        // Assert
        response.StatusCode.ShouldBe(HttpStatusCode.OK);
        response.Content.ShouldNotBeNull();
    }

    [Test]
    public async Task InvalidId_ReturnsBadRequest()
    {
        var request = new GetFeatureRequest(0);
        var ex = await Should.ThrowAsync<RestProviderRequestException>(
            ServiceApiProvider.GetFeatureAsync(request));
        ex.StatusCode.ShouldBe(HttpStatusCode.BadRequest);
    }
}
```

## Assertion Library

Use a single assertion library consistently. NUnit `Assert` class is FORBIDDEN except for `Assert.Ignore()`.

| FORBIDDEN (NUnit Assert) | REQUIRED (Shouldly-style) |
|--------------------------|--------------------------|
| `Assert.That(result, Is.Not.Null)` | `result.ShouldNotBeNull()` |
| `Assert.AreEqual(expected, actual)` | `actual.ShouldBe(expected)` |
| `Assert.IsTrue(condition)` | `condition.ShouldBeTrue()` |
| `Assert.Throws<T>()` | `Should.Throw<T>()` |

## Coverage Requirements

For each endpoint, component tests MUST cover:
1. **Success scenarios** -- happy path, correct response structure
2. **Validation scenarios** -- invalid params -> 400, missing required -> 400
3. **Edge cases** -- empty collections, pagination
4. **Mock interactions** -- verify provider called with correct params

## Test Naming
| Pattern | Example |
|---------|---------|
| `FullScenario` | Happy path end-to-end |
| `{Condition}_Returns{Result}` | `InvalidItemId_ReturnsBadRequest` |
| `{Service}Fails_Returns{Result}` | `ExternalServiceFails_ReturnsPartialData` |

## Mocking Strategy

### External REST Providers
Mock at the interface level: `services.AddSingletonMock<IExternalApiProvider>()`

### Message Brokers (Service Bus, Event Hubs)
Override the `Add*` bootstrapper method to register mocks. Override the `Use*` method as a no-op. Re-wire mock relationships after `Reset()`.

### Databases (Document DB, RDBMS)
Document DBs: Override `Add*`/`Use*` bootstrapper methods with mocks.
RDBMS: Mock at repository interface level (no bootstrapper override needed).

### Distributed Cache (Redis, etc.)
Override `Add*`/`Use*` bootstrapper methods with mocks, or mock the cached repository interface.

## Backend-to-Backend Auth Testing
- Mock the config provider to return test API keys
- Test API provider accepts `string apiKey` parameter on admin endpoint methods
- Set API key as `X-Api-Key` header on the request
- No auth token mocking needed for these endpoints

## Test Execution
```bash
# CORRECT
dotnet test --filter "Category=ComponentTests"

# FORBIDDEN -- never run system tests locally
dotnet test --filter "Category=SystemTests"
```
