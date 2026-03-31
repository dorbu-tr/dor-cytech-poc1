<!-- AUTO-GENERATED from .cursor/ canonical source. Do not edit directly. -->
<!-- Source: .cursor/skills/team/api-controllers/SKILL.md | Regenerate: .specify/scripts/sh/sync-ai-rules.sh claude-code -->
<!-- TEAM-SPECIFIC: This file implements the standards defined in the corresponding core/ skill using eToro Trading NuGets — sealed controllers, FluentValidation, AutoMapper, Internalize/Externalize pattern. Verified against trading-opstool-api GitHub source. -->

# Trading API Controller Patterns

## When to Use This Skill

Use when implementing: controllers, request/response DTOs, AppSecret/STS authentication, FluentValidation, AutoMapper, Swagger/OpenAPI, API standards compliance, Internalize/Externalize extensions.

## Controller Method Pattern (NON-NEGOTIABLE)

Controllers MUST be `sealed`, use `[ApiController]`, `[Produces("application/json")]`, and explicit binding attributes.

### Generic Template Pattern (works without Opstool)

```csharp
[ApiController]
[Route("api/v1/instruments")]
[Produces("application/json")]
public sealed class InstrumentsController : ControllerBase
{
    private readonly IInstrumentService _service;
    private readonly IMapper _mapper;

    public InstrumentsController(IInstrumentService service, IMapper mapper)
    {
        _service = service;
        _mapper = mapper;
    }

    /// <summary>Gets all instruments with optional filtering.</summary>
    [HttpGet]
    [ProducesResponseType(typeof(GetInstrumentsResponse), (int)HttpStatusCode.OK)]
    [ProducesResponseType((int)HttpStatusCode.BadRequest)]
    public async Task<IActionResult> GetAll([FromQuery] GetInstrumentsRequest request)
    {
        var parameters = request.Internalize();
        var result = await _service.GetAllAsync(parameters);
        return Ok(result.Externalize(_mapper));
    }

    /// <summary>Gets instrument by ID.</summary>
    [HttpGet("{instrumentId}")]
    [ProducesResponseType(typeof(GetInstrumentByIdResponse), (int)HttpStatusCode.OK)]
    [ProducesResponseType((int)HttpStatusCode.NotFound)]
    public async Task<IActionResult> GetById([FromRoute] int instrumentId)
    {
        var request = new GetInstrumentByIdRequest { InstrumentId = instrumentId };
        var parameters = request.Internalize();
        var result = await _service.GetByIdAsync(parameters);
        return Ok(result.Externalize(_mapper));
    }

    /// <summary>Gets sub-items for an instrument.</summary>
    [HttpGet("{instrumentId}/fees")]
    [ProducesResponseType(typeof(GetInstrumentFeesResponse), (int)HttpStatusCode.OK)]
    [ProducesResponseType((int)HttpStatusCode.NotFound)]
    public async Task<IActionResult> GetFees([FromRoute] int instrumentId)
    {
        var request = new GetInstrumentFeesRequest { InstrumentId = instrumentId };
        var parameters = request.Internalize();
        var result = await _service.GetFeesAsync(parameters);
        return Ok(result.Externalize(_mapper));
    }
}
```

### Validation

When using `FluentValidationActionFilter` (registered globally), validation is automatic — no per-action boilerplate needed. The filter resolves `IValidator<T>` for each action argument and returns 400 if invalid.

If NOT using the action filter, validate manually:
```csharp
var validationResult = await _validator.ValidateAsync(request);
if (!validationResult.IsValid)
    return BadRequest(new
    {
        title = "Validation error",
        status = (int)HttpStatusCode.BadRequest,
        errors = validationResult.Errors.Select(e => new { e.PropertyName, e.ErrorMessage, e.ErrorCode })
    });
```

### `[FromQuery]` for GET Endpoints

`[ApiController]` infers `[FromBody]` for complex types. For GET endpoints with query-bound DTOs, you MUST add `[FromQuery]` on the method parameter:

```csharp
// CORRECT — [FromQuery] required for GET with complex request DTO
public async Task<IActionResult> GetAll([FromQuery] GetInstrumentsRequest request)

// WRONG — [ApiController] will try to bind from body, properties will be null
public async Task<IActionResult> GetAll(GetInstrumentsRequest request)
```

## Authentication

### AppSecret (Service-to-Service) — Template Default

Auth is handled globally by `AppSecretAuthenticationMiddleware` in the pipeline. No per-action attribute needed.

### `[AuthorizeLevel]` (Opstool-specific)

> **WARNING**: `[AuthorizeLevel]` depends on types from `eToro.Trading.Opstool.Application.Authorization`. It is ONLY available in services referencing Opstool NuGets. For services not using Opstool, skip this attribute — `AppSecretAuthenticationMiddleware` provides equivalent auth.

### STS Token (Client-Facing)
- `[Authentication]` attribute on controller actions
- GCID from token for user identity

| Question | AppSecret | STS |
|----------|-----------|-----|
| Who calls? | Other services | End users (web/mobile) |
| Need user identity (GCID)? | No | Yes |
| Permission model | ReadOnly/ReadWrite | PermissionId, ElevationLevel |
| Header | `Authorization: {AppSecret}` | `Authorization: Bearer {token}` |

## API Route Path Convention (NON-NEGOTIABLE)

```
api/v1/{resource}
api/v1/{resource}/{id}
api/v1/{resource}/{id}/{sub-resource}
```

- Resource names MUST be plural: `instruments`, `fees`, `margins`
- Use kebab-case for multi-word: `instrument-groups`
- DO NOT use `[controller]` token in route attributes
- DO NOT use singular resource names
- Sub-resource routes: `[HttpGet("{id}/sub-items")]` on a controller with `[Route("api/v1/resources")]`

## Internalize / Externalize Pattern

API-layer request DTOs are converted to Application-layer parameters via extension methods:

- **Internalize**: `request.Internalize()` → converts request DTO to service parameters
- **Externalize**: `result.Externalize(mapper)` → converts service result to response DTO

See `.reference/Api/Extensions/ExampleRequestExtensions.cs` and `.reference/Api/Extensions/ExampleResponseExtensions.cs`.

## FluentValidation Pattern

```csharp
public sealed class GetInstrumentsRequestValidator : AbstractValidator<GetInstrumentsRequest>
{
    public GetInstrumentsRequestValidator()
    {
        RuleFor(x => x.Page).GreaterThanOrEqualTo(1).When(x => x.Page.HasValue)
            .WithErrorCode("INVALID_PAGE");
        RuleFor(x => x.PageSize).InclusiveBetween(1, 100).When(x => x.PageSize.HasValue)
            .WithErrorCode("INVALID_PAGE_SIZE");
    }
}
```

## AutoMapper Pattern

```csharp
public sealed class InstrumentMappingProfile : Profile
{
    public InstrumentMappingProfile()
    {
        CreateMap<InstrumentEntity, InstrumentItem>()
            .ForMember(dest => dest.Id, opt => opt.MapFrom(src => src.InstrumentId));
    }
}
```

## Swagger/OpenAPI Documentation

All APIs MUST have Swagger in non-production. All endpoints MUST have XML docs, `[ProducesResponseType]`, and all DTOs MUST have `<summary>` on properties.

- **Full Swagger configuration**: Read [references/swagger-openapi.md](references/swagger-openapi.md)

## Reference Files

- **Auth patterns** (AppSecret + STS full implementations): Read [references/auth-patterns.md](references/auth-patterns.md)
- **Swagger/OpenAPI** (configuration, documentation requirements): Read [references/swagger-openapi.md](references/swagger-openapi.md)
- **API standards** (per-tier compliance checklist): Read [references/api-standards.md](references/api-standards.md)
