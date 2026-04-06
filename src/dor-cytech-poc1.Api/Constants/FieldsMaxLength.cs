namespace dor-cytech-poc1.Api.Constants
{
    /// <summary>
    /// Maximum length constraints for request fields.
    /// Used in request <c>Validate()</c> methods with <c>ErrorMessageConsts.FieldMaxLengthFormat</c>.
    /// TODO: Add max length constants specific to your API fields.
    /// </summary>
    public static class FieldsMaxLength
    {
        public const int Name = 200;
        public const int Description = 500;
        public const int ResourceId = 100;
        public const int Url = 500;
    }
}
