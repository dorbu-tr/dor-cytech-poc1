using System;
using System.Reflection;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Application.HealthCheck.Extensions.Core;
using Microsoft.Extensions.Hosting;
using Microsoft.OpenApi.Models;
using Newtonsoft.Json;
using Newtonsoft.Json.Serialization;
using dor-cytech-poc1.Api.Middlewares;
using JsonSerializer = System.Text.Json.JsonSerializer;

namespace dor-cytech-poc1.Api.Extensions;

public static class StartupExtensions
{
    public static WebApplicationBuilder ConfigureWebService(this WebApplicationBuilder builder)
    {
        builder.Services
            .AddControllers()
            // eToro API convention: PascalCase JSON properties (matches C# property names).
            // This differs from ASP.NET Core default (camelCase). Intentional per eToro API standards.
            .AddNewtonsoftJson(options =>
            {
                options.SerializerSettings.ContractResolver = new DefaultContractResolver
                    { NamingStrategy = new DefaultNamingStrategy() };
                options.SerializerSettings.Converters.Add(
                    new Newtonsoft.Json.Converters.StringEnumConverter(new CamelCaseNamingStrategy()));
                options.SerializerSettings.NullValueHandling = NullValueHandling.Ignore;
                options.SerializerSettings.DateTimeZoneHandling = DateTimeZoneHandling.Utc;
                options.SerializerSettings.DateFormatHandling = DateFormatHandling.IsoDateFormat;
            })
            .AddXmlSerializerFormatters()
            .AddXmlDataContractSerializerFormatters();

        return builder;
    }

    /// <summary>
    /// Pipeline order matches production services (trading-orders-api, trading-copy-api):
    /// Health checks -> HTTPS -> Routing -> ExceptionHandling -> Auth -> Swagger -> MapControllers
    /// </summary>
    public static WebApplication ConfigureWebApplication(this WebApplication app)
    {
        // Health checks FIRST — before auth, so load balancer probes don't need credentials.
        // Health status -> HTTP: Healthy=200, Degraded=200, Unhealthy=503.
        var versionInfo = new
        {
            Version = Environment.GetEnvironmentVariable("APP_VERSION")
                ?? Assembly.GetExecutingAssembly().GetName().Version.ToString(),
            Commit = Environment.GetEnvironmentVariable("APP_COMMIT"),
            Branch = Environment.GetEnvironmentVariable("APP_BRANCH"),
        };
        app.UseHealthChecks("/ping", new HealthCheckOptions
        {
            ResponseWriter = async (context, report) =>
                await context.Response.WriteAsync("pong")
        });
        app.UseHealthChecks("/version", new HealthCheckOptions
        {
            ResponseWriter = async (context, report) =>
                await context.Response.WriteAsync(JsonSerializer.Serialize(versionInfo))
        });

        if (app.Environment.IsDevelopment())
            app.UseDeveloperExceptionPage();

        app.UseHttpsRedirection();
        app.UseRouting();
        app.UseMiddleware<ExceptionHandlingMiddleware>();
        app.UseMiddleware<AppSecretAuthenticationMiddleware>();

        if (!app.Environment.IsProduction())
        {
            app.UseSwagger();
            app.UseSwaggerUI(c =>
            {
                c.SwaggerEndpoint("/swagger/v1/swagger.json",
                    $"{app.Environment.ApplicationName}");
            });
        }

        app.UseAuthorization();
        app.MapControllers();

        return app;
    }

    public static WebApplicationBuilder RegisterSwagger(
        this WebApplicationBuilder builder, IConfiguration configuration)
    {
        builder.Services.AddSwaggerGen(options =>
        {
            options.SwaggerDoc("v1", new OpenApiInfo
            {
                Title = configuration["App:Title"] ?? "Trading Service API",
                Version = "v1"
            });

            options.AddSecurityDefinition("Authorization", new OpenApiSecurityScheme
            {
                In = ParameterLocation.Header,
                Name = "Authorization",
                Type = SecuritySchemeType.ApiKey,
                Description = "Enter AppSecret for your application",
            });

            options.AddSecurityRequirement(new OpenApiSecurityRequirement
            {
                {
                    new OpenApiSecurityScheme
                    {
                        Reference = new OpenApiReference
                        {
                            Type = ReferenceType.SecurityScheme,
                            Id = "Authorization"
                        }
                    },
                    Array.Empty<string>()
                }
            });

            options.CustomSchemaIds(x => x.FullName);
        });
        return builder;
    }
}
