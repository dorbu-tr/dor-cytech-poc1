namespace dor-cytech-poc1.Api.Enumerations
{
    /// <summary>
    /// Error codes for API validation errors.
    /// Naming convention: {FieldName}{Condition} — e.g., ResourceIdRequired, NameExceededMaximumLength.
    /// Every validation path MUST have its own specific error code.
    /// TODO: Add error codes specific to your API.
    /// </summary>
    public enum ErrorCode
    {
        RequestBodyRequired,
        AtLeastOneFieldRequired,
        ResourceIdRequired,
        ResourceIdInvalidGuid,
        NameRequired,
        NameExceededMaximumLength,
        DescriptionExceededMaxLength,
        UrlRequired,
        UrlExceededMaxLength,
        UrlInvalidUri,
        ItemsRequired,
        ItemIdMustBePositive,
        ItemIdsDuplicateItems,
        InvalidResourceId,
        InvalidResourceStatus
    }
}
