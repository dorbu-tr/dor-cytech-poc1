using AutoMapper;
using FluentValidation;
using Microsoft.AspNetCore.Mvc;
using System.Net;

namespace eToro.Trading.{ServiceName}.WebApi.Controllers;

/// <summary>
/// Controller for {Feature} management.
/// Provides endpoints to list, get by ID, and get sub-resources.
/// </summary>
[ApiController]
[Route("api/v1/{features}")]
[Produces("application/json")]
public sealed class {Feature}Controller : ControllerBase
{
    private readonly I{Feature}Service _service;
    private readonly IMapper _mapper;

    public {Feature}Controller(I{Feature}Service service, IMapper mapper)
    {
        _service = service;
        _mapper = mapper;
    }

    /// <summary>Gets all {Feature} items with optional filtering.</summary>
    /// <response code="200">Returns the {Feature} list.</response>
    /// <response code="400">Validation error.</response>
    [HttpGet]
    [ProducesResponseType(typeof(Get{Feature}Response), (int)HttpStatusCode.OK)]
    [ProducesResponseType((int)HttpStatusCode.BadRequest)]
    public async Task<IActionResult> GetAll([FromQuery] Get{Feature}Request request)
    {
        var parameters = request.Internalize();
        var result = await _service.GetAllAsync(parameters);
        return Ok(result.Externalize(_mapper));
    }

    /// <summary>Gets a single {Feature} by ID.</summary>
    /// <param name="id">The {Feature} identifier.</param>
    /// <response code="200">Returns the {Feature} detail.</response>
    /// <response code="404">{Feature} not found.</response>
    [HttpGet("{id}")]
    [ProducesResponseType(typeof(Get{Feature}ByIdResponse), (int)HttpStatusCode.OK)]
    [ProducesResponseType((int)HttpStatusCode.NotFound)]
    public async Task<IActionResult> GetById([FromRoute] int id)
    {
        var request = new Get{Feature}ByIdRequest { Id = id };
        var parameters = request.Internalize();
        var result = await _service.GetByIdAsync(parameters);
        return Ok(result.Externalize(_mapper));
    }

    /// <summary>Gets sub-items for a {Feature}.</summary>
    /// <param name="id">The parent {Feature} identifier.</param>
    /// <response code="200">Returns the sub-item list.</response>
    /// <response code="404">Parent {Feature} not found.</response>
    [HttpGet("{id}/sub-items")]
    [ProducesResponseType(typeof(Get{Feature}SubItemsResponse), (int)HttpStatusCode.OK)]
    [ProducesResponseType((int)HttpStatusCode.NotFound)]
    public async Task<IActionResult> GetSubItems([FromRoute] int id)
    {
        var request = new Get{Feature}SubItemsRequest { {Feature}Id = id };
        var parameters = request.Internalize();
        var result = await _service.GetSubItemsAsync(parameters);
        return Ok(result.Externalize(_mapper));
    }
}
