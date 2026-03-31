<!-- AUTO-GENERATED from .cursor/ canonical source. Do not edit directly. -->
<!-- Source: .cursor/skills/team/component-testing/SKILL.md | Regenerate: .specify/scripts/sh/sync-ai-rules.sh copilot -->
<!-- TEAM-SPECIFIC: This file implements testing patterns for the Trading team — xUnit, FluentAssertions, Moq. Teams using NUnit/Shouldly: replace this file with your library-specific implementations. -->

# Trading Component Testing Patterns

## When to Use This Skill

Use when implementing: unit tests, component tests, xUnit test classes, FluentAssertions, Moq mocking, validator tests, mapper tests, service tests, WebApplicationFactory integration tests.

## Testing Stack (NON-NEGOTIABLE)

**Stack**: xUnit 2.x, Moq 4.x, FluentAssertions 6.x.

**Test projects**: `{ServiceName}.Application.Tests` (required), `{ServiceName}.Infrastructure.Tests` (optional).

## Test Class Pattern

```csharp
public class CalculatedFeesServiceTests
{
    private readonly Mock<ICalculatedFeesRepository> _repositoryMock;
    private readonly Mock<IMapper<CalculatedFeesDto, CalculatedFees>> _mapperMock;
    private readonly CalculatedFeesService _sut;

    public CalculatedFeesServiceTests()
    {
        _repositoryMock = new Mock<ICalculatedFeesRepository>();
        _mapperMock = new Mock<IMapper<CalculatedFeesDto, CalculatedFees>>();
        _sut = new CalculatedFeesService(_repositoryMock.Object, _mapperMock.Object);
    }

    [Fact]
    public async Task GetAllAsync_ReturnsData_WhenRepositoryHasItems()
    {
        // Arrange
        var expected = new List<CalculatedFeesDto> { new() { Id = 1 } };
        _repositoryMock.Setup(r => r.GetAllAsync()).ReturnsAsync(expected);

        // Act
        var result = await _sut.GetAllAsync();

        // Assert
        result.Should().NotBeEmpty();
        result.Should().HaveCount(1);
        result.First().Id.Should().Be(1);
    }
}
```

## WebApplicationFactory Component Tests

For HTTP-level component tests, use `WebApplicationFactory<Program>` with the template's `TestsBase` class.

### Framework.Log Mock Logger Pattern (CRITICAL)

`Framework.Log.ILogger<T>` must be registered in the test DI container. Without it, `WebApplicationFactory` fails with DI validation errors. The template's `TestsBase` handles this automatically by registering a no-op `MockLogger<T>` implementation.

```csharp
public class MyEndpointTests : TestsBase
{
    public MyEndpointTests(WebApplicationFactory<Program> factory) : base(factory) { }

    protected override void ConfigureTestServices(IServiceCollection services)
    {
        // Register mock dependencies specific to your tests
        services.AddSingleton(Mock.Of<IMyService>());
    }

    [Fact]
    public async Task GetAll_ReturnsOk()
    {
        var response = await Client.GetAsync("/api/v1/my-resources");
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }
}
```

If NOT using `TestsBase`, register mock loggers manually:
```csharp
// Option 1: Use RegisterGenericFrameworkLoggers (real loggers, needs log4net.config)
services.RegisterGenericFrameworkLoggers();

// Option 2: Register individual mocks (no log4net dependency)
services.AddSingleton(Mock.Of<Framework.Log.ILogger<MyService>>());
services.AddSingleton(Mock.Of<Framework.Log.ILogger<MyProvider>>());

// Option 3: Open generic no-op (recommended in TestsBase)
services.AddTransient(typeof(Framework.Log.ILogger<>), typeof(MockLogger<>));
```

## Validator Test Pattern

```csharp
public class InstrumentSlippageValidatorTests
{
    private readonly CommandInstrumentSlippageValidator _validator;

    public InstrumentSlippageValidatorTests()
    {
        _validator = new CommandInstrumentSlippageValidator();
    }

    [Fact]
    public void Validate_ValidDto_ShouldNotHaveErrors()
    {
        var dto = new InstrumentSlippageDto { InstrumentId = 1, Slippage = 0.5m };
        var result = _validator.TestValidate(dto);
        result.ShouldNotHaveAnyValidationErrors();
    }

    [Fact]
    public void Validate_InvalidInstrumentId_ShouldHaveError()
    {
        var dto = new InstrumentSlippageDto { InstrumentId = 0 };
        var result = _validator.TestValidate(dto);
        result.ShouldHaveValidationErrorFor(x => x.InstrumentId);
    }
}
```

## Mapper Test Pattern

```csharp
public class InstrumentMappingTests
{
    private readonly InstrumentMapper _mapper;

    public InstrumentMappingTests()
    {
        _mapper = new InstrumentMapper();
    }

    [Fact]
    public void Map_ValidEntity_MapsAllFields()
    {
        var entity = new Instrument { Id = 1, Name = "Apple" };
        var result = _mapper.Map(entity);
        result.InstrumentId.Should().Be(1);
        result.Name.Should().Be("Apple");
    }
}
```

## Naming Conventions

- Test class: `{ServiceClass}Tests` (e.g., `CalculatedFeesServiceTests`)
- Test method: `{MethodName}_{Scenario}_{Expected}` (e.g., `GetAll_EmptyRepo_ReturnsEmpty`)

## Forbidden

- Using NUnit or Shouldly (use xUnit + FluentAssertions)
- Naming tests after controllers (`CalculatedFeesControllerTests`)
- Missing Arrange/Act/Assert structure

## Required NuGet Packages

```xml
<PackageReference Include="xunit" Version="2.9.2" />
<PackageReference Include="xunit.runner.visualstudio" Version="2.8.2" />
<PackageReference Include="FluentAssertions" Version="6.8.0" />
<PackageReference Include="Moq" Version="4.20.72" />
<PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.8.0" />
<PackageReference Include="Microsoft.AspNetCore.Mvc.Testing" Version="8.0.0" />
<PackageReference Include="coverlet.collector" Version="6.0.0" />
<PackageReference Include="FluentValidation.TestHelper" Version="11.3.0" />
```
