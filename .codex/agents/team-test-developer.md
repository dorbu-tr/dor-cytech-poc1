---
name: "test-developer"
description: "Trading test implementation: xUnit, FluentAssertions, Moq, validator tests, mapper tests, service tests."
---

<!-- AUTO-GENERATED from .cursor/ canonical source. Do not edit directly. -->
<!-- Source: .cursor/agents/team/test-developer.md | Regenerate: .specify/scripts/sh/sync-ai-rules.sh codex -->
<!-- TEAM-SPECIFIC: This agent extends core/test-developer.md with eToro Trading testing patterns. Replace with your team's library-specific agent. -->

# Test Developer — Trading NuGets

**FIRST read**: `.codex/agents/core-test-developer.md` for architecture standards.

Then read these team skills for Trading-specific code examples:
1. `.codex/skills/team-component-testing/SKILL.md` — xUnit, FluentAssertions, Moq patterns
2. `.codex/skills/team-system-testing/SKILL.md` — System/integration test patterns

## Reference Files

> **Real code first**: If the project already has implemented tests, read them and follow their conventions for consistency.

> **Discovery**: `dor-cytech-poc1` is a placeholder. Discover actual project names by scanning `*.csproj` files in the repository root.

### ALWAYS read — Test structure and patterns
- Existing tests in `tests/{ServiceName}.Application.Tests/` for conventions

## Trading-Specific Constraints
- **xUnit + FluentAssertions ONLY** (no NUnit, no Shouldly)
- Test class naming: `{ServiceClass}Tests` (e.g., `CalculatedFeesServiceTests`)
- Test method naming: `{MethodName}_{Scenario}_{Expected}`
- Constructor injection for test setup (xUnit pattern, no [SetUp] attribute)
- `FluentValidation.TestHelper` for validator tests (`TestValidate`, `ShouldNotHaveAnyValidationErrors`)
- Arrange/Act/Assert structure in every test
- Mock dependencies with Moq, assert with FluentAssertions `.Should()`

### Validator Tests
```csharp
[Fact]
public void Validate_ValidDto_ShouldNotHaveErrors()
{
    var dto = new InstrumentDto { InstrumentId = 1 };
    var result = _validator.TestValidate(dto);
    result.ShouldNotHaveAnyValidationErrors();
}
```

### Service Tests
```csharp
[Fact]
public async Task GetAllAsync_ReturnsData_WhenRepositoryHasItems()
{
    _repositoryMock.Setup(r => r.GetAllAsync()).ReturnsAsync(expectedData);
    var result = await _sut.GetAllAsync();
    result.Should().NotBeEmpty();
}
```
