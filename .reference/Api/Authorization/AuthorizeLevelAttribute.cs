// WARNING: This attribute depends on Opstool-specific types:
//   - eToro.Trading.Opstool.Application.Authorization.IAuthorizationService
//   - eToro.Trading.Opstool.Application.Authorization.AuthorizationLevel
//   - eToro.Trading.Opstool.WebApi.Headers.HeadersValidationException
//
// It is ONLY usable in services that reference the Opstool NuGet packages.
// For services NOT using Opstool, authentication is handled globally by
// AppSecretAuthenticationMiddleware — no per-action attribute is needed.

using eToro.Trading.Opstool.Application.Authorization;
using eToro.Trading.Opstool.Application.Configuration;
using eToro.Trading.Opstool.WebApi.Headers;
using Framework.Log;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using System.Net;

namespace eToro.Trading.Opstool.WebApi.Authorization;

[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method, AllowMultiple = false)]
public class AuthorizeLevelAttribute : TypeFilterAttribute
{
    public AuthorizeLevelAttribute(AuthorizationLevel requiredLevel)
        : base(typeof(AuthorizeLevelFilter))
    {
        Arguments = new object[] { requiredLevel };
    }

    private class AuthorizeLevelFilter : IAuthorizationFilter
    {
        private readonly string _appSecretHeaderName;
        private readonly AuthorizationLevel _requiredLevel;
        private readonly ILogger _logger;
        private readonly Dictionary<string, AuthorizationLevel> _authorizationLevels;

        public AuthorizeLevelFilter(
            AuthorizationLevel requiredLevel,
            IAuthorizationService authorizationService,
            ILogger logger)
        {
            _requiredLevel = requiredLevel;
            _logger = logger;
            _authorizationLevels = authorizationService.GetAuthorizationLevels();
            _appSecretHeaderName = AuthorizationConfiguration.AuthorizationHeaderName;
        }

        public void OnAuthorization(AuthorizationFilterContext context)
        {
            if (!ExtractRequestData(context.HttpContext, out var appSecret))
                throw new HeadersValidationException(
                    "Authorization header is required.", HttpStatusCode.BadRequest);

            if (!Authorize(appSecret))
                context.Result = new UnauthorizedResult();
        }

        private bool Authorize(string appSecret)
        {
            if (_authorizationLevels.TryGetValue(appSecret, out var matchedLevel))
                if (matchedLevel >= _requiredLevel)
                    return true;
            return false;
        }

        private bool ExtractRequestData(HttpContext context, out string appSecret)
        {
            if (context.Request.Headers.TryGetValue(_appSecretHeaderName, out var appSecrets))
            {
                appSecret = appSecrets.FirstOrDefault()?.ToLower();
                return true;
            }
            appSecret = null;
            return false;
        }
    }
}
