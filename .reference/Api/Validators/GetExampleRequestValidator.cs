using FluentValidation;

namespace eToro.Trading.{ServiceName}.WebApi.Validators;

public sealed class Get{Feature}RequestValidator : AbstractValidator<Get{Feature}Request>
{
    public Get{Feature}RequestValidator()
    {
        RuleFor(x => x.Page)
            .GreaterThanOrEqualTo(1)
            .When(x => x.Page.HasValue)
            .WithErrorCode("INVALID_PAGE")
            .WithMessage("Page must be >= 1");

        RuleFor(x => x.PageSize)
            .InclusiveBetween(1, 100)
            .When(x => x.PageSize.HasValue)
            .WithErrorCode("INVALID_PAGE_SIZE")
            .WithMessage("PageSize must be between 1 and 100");

        RuleFor(x => x.Status)
            .MaximumLength(50)
            .When(x => !string.IsNullOrEmpty(x.Status))
            .WithErrorCode("INVALID_STATUS")
            .WithMessage("Status must be at most 50 characters");
    }
}
