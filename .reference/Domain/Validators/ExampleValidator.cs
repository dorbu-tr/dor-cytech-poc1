using eToro.Trading.Opstool.Domain.Dto.Example;
using FluentValidation;

namespace eToro.Trading.Opstool.Domain.Validators;

public sealed class ExampleValidator : AbstractValidator<ExampleDto>
{
    public ExampleValidator()
    {
        RuleFor(x => x.ExampleId)
            .GreaterThan(0)
            .WithMessage("ExampleId must be greater than 0");

        RuleFor(x => x.Name)
            .NotEmpty()
            .MaximumLength(100)
            .WithMessage("Name must not be empty and max 100 characters");
    }
}
