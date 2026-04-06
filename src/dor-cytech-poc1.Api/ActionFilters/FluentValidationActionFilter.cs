using System.Net;
using FluentValidation;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace dor-cytech-poc1.Api.ActionFilters;

/// <summary>
/// Auto-validates request parameters using FluentValidation.
/// Eliminates per-action validation boilerplate in controllers.
/// Register in Program.cs: builder.Services.AddControllers(o => o.Filters.Add&lt;FluentValidationActionFilter&gt;());
/// </summary>
public sealed class FluentValidationActionFilter : IAsyncActionFilter
{
    private readonly IServiceProvider _serviceProvider;

    public FluentValidationActionFilter(IServiceProvider serviceProvider)
    {
        _serviceProvider = serviceProvider;
    }

    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        foreach (var argument in context.ActionArguments.Values)
        {
            if (argument == null) continue;

            var validatorType = typeof(IValidator<>).MakeGenericType(argument.GetType());
            if (_serviceProvider.GetService(validatorType) is not IValidator validator) continue;

            var validationContext = new ValidationContext<object>(argument);
            var result = await validator.ValidateAsync(validationContext);

            if (!result.IsValid)
            {
                context.Result = new BadRequestObjectResult(new
                {
                    title = "Validation error",
                    status = (int)HttpStatusCode.BadRequest,
                    errors = result.Errors.Select(e => new
                    {
                        e.PropertyName,
                        e.ErrorMessage,
                        e.ErrorCode
                    })
                });
                return;
            }
        }

        await next();
    }
}
