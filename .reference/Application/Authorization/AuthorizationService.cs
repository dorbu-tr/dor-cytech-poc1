using eToro.Trading.Opstool.Application.Configuration;
using System;
using System.Collections.Generic;

namespace eToro.Trading.Opstool.Application.Authorization;

public class AuthorizationService : IAuthorizationService
{
    private readonly Dictionary<string, AuthorizationLevel> _authorizationLevels;

    public AuthorizationService(AuthorizationConfiguration configuration)
    {
        if (configuration == null)
            throw new ArgumentNullException(nameof(configuration));

        if (string.IsNullOrEmpty(configuration.ReadOnlyAppSecret) ||
            string.IsNullOrEmpty(configuration.ReadWriteAppSecret))
            throw new ArgumentException("Configuration properties cannot be null or empty");

        _authorizationLevels = new Dictionary<string, AuthorizationLevel>
        {
            { configuration.ReadOnlyAppSecret.ToLower(), AuthorizationLevel.ReadOnly },
            { configuration.ReadWriteAppSecret.ToLower(), AuthorizationLevel.ReadWrite }
        };
    }

    public Dictionary<string, AuthorizationLevel> GetAuthorizationLevels()
        => _authorizationLevels;
}
