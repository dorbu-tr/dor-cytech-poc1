---
name: "core-data-repositories"
description: "Data repository and caching architecture patterns including folder structure, Parameters/Result DTOs, and cached repository decorator pattern. Use when implementing data repositories, cached repositories, data access layer, or repository DTOs. Team-specific storage implementations live in the team data-repositories skill."
metadata:
  short-description: "Data repository and caching architecture patterns including folder structure, Parameters/Result DTOs, and cached repository decorator pattern. Use when implementing data repositories, cached repositories, data access layer, or repository DTOs. Team-specific storage implementations live in the team data-repositories skill."
---

<!-- AUTO-GENERATED from .cursor/ canonical source. Do not edit directly. -->
<!-- Source: .cursor/skills/core/data-repositories/SKILL.md | Regenerate: .specify/scripts/sh/sync-ai-rules.sh codex -->
# Data Repository & Caching Patterns

## Repository Folder Structure

```
dor-cytech-poc1.Infrastructure/
  Repositories/
    Interfaces/
      I{Feature}Repository.cs
    Concrete/
      {Feature}Repository.cs
    Dto/
      Parameters/
        {Action}{Feature}Parameters.cs
      Results/
        {Action}{Feature}Result.cs
    Exceptions/
```

## Repository Method Signatures (NON-NEGOTIABLE)

Repository methods MUST accept a single Parameters class and return a Result class -- NOT multiple primitive parameters. This keeps method signatures clean and extensible.

**Correct:**
```csharp
Task<CreateAlertResult> CreateAlertAsync(CreateAlertParameters parameters);
Task<GetAlertsByUserResult> GetAlertsByUserAsync(GetAlertsByUserParameters parameters);
Task<AlertData> GetByIdAsync(GetAlertByIdParameters parameters);
```

**FORBIDDEN -- multiple primitive parameters:**
```csharp
Task<AlertData> CreateAlertAsync(long userId, int instrumentId, decimal targetPrice, int direction);
Task<List<AlertData>> GetAlertsByUserAsync(long userId, int page, int pageSize);
```

### Parameters & Result Classes

Parameters and Result classes go in `Repositories/Dto/Parameters/` and `Repositories/Dto/Results/`:

```csharp
public class CreateAlertParameters
{
    public long UserId { get; set; }
    public int InstrumentId { get; set; }
    public decimal TargetPrice { get; set; }
    public int Direction { get; set; }
}

public class CreateAlertResult
{
    public long AlertId { get; set; }
    public DateTime CreatedAt { get; set; }
}
```

**Naming conventions:**
- Input: `{Action}{Feature}Parameters` (e.g., `CreateAlertParameters`, `GetAlertsByUserParameters`)
- Output: `{Action}{Feature}Result` (e.g., `CreateAlertResult`) or a domain data class
- Simple ID lookups may return the document/data class directly
- NO technology names in class names (e.g., `GetAlertResult`, NOT `GetAlertCosmosResult`)

## Bootstrapper Registration (NON-NEGOTIABLE)

Repositories go in `RegisterRepositories()` -- NOT in `RegisterProviders()` or `RegisterServices()`:

```csharp
private static void RegisterRepositories(IServiceCollection services)
{
    services.AddSingleton<I{Feature}Repository, {Feature}Repository>();
}
```

## Cached Repository Pattern

For repositories that need caching, the specific approach (two-tier L1+L2, Scrutor decorators, etc.) is team-specific — see team skill `data-repositories`.

## Anti-Patterns

| Anti-Pattern | Correct Pattern |
|-------------|----------------|
| Multiple primitive parameters on methods | Single Parameters class |
| Technology names in DTO names | Feature/domain names only |
| Repositories in `RegisterProviders()` | Use `RegisterRepositories()` |
