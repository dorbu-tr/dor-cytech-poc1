namespace dor-cytech-poc1.Api.Constants
{
    /// <summary>
    /// Error message constants for validation.
    /// Use format strings with <c>string.Format</c> and <c>nameof()</c> for field names.
    /// TODO: Add additional error messages as needed.
    /// </summary>
    public static class ErrorMessageConsts
    {
        public const string RequestBodyIsRequired = "Request body is required";
        public const string FieldIsRequiredFormat = "{0} is required";
        public const string FieldMustNotBeEmptyFormat = "{0} must not be empty when provided";
        public const string FieldMaxLengthFormat = "{0} exceeded max length";
        public const string InvalidUriFormat = "{0} must be a valid URI";
        public const string EmptyCollection = "{0} must contain at least one item";
        public const string FieldMustBePositiveFormat = "{0} must be positive";
        public const string DuplicateCollectionItemsFormat = "{0} must be unique";
        public const string InvalidGuid = "{0} must be a valid GUID";
        public const string AtLeastOneFieldRequired = "At least one field must be provided for update";
        public const string FieldMustBeValidFormat = "{0} must be valid";
        public const string IntegerLessThanMinimumFormat = "{0} is less than minimum";
    }
}
