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
using eToro.Trading.Opstool.Bootstrap.Configurations;
using eToro.Trading.Opstool.WebApi.Middlewares;
using JsonSerializer = System.Text.Json.JsonSerializer;

namespace eToro.Trading.Opstool.WebApi.Extensions;

public static class StartupExtensions
{
    public static WebApplicationBuilder ConfigureWebService(this WebApplicationBuilder builder)
    {
        builder.Services
            .AddControllers()
            .AddNewtonsoftJson(options =>
            {
                options.SerializerSettings.ContractResolver = new DefaultContractResolver
                    { NamingStrategy = new DefaultNamingStrategy() };
                options.SerializerSettings.NullValueHandling = NullValueHandling.Ignore;
                options.SerializerSettings.DateTimeZoneHandling = DateTimeZoneHandling.Utc;
                options.SerializerSettings.DateFormatHandling = DateFormatHandling.IsoDateFormat;
            })
            .AddXmlSerializerFormatters()
            .AddXmlDataContractSerializerFormatters();

        return builder;
    }

    public static WebApplication ConfigureWebApplication(this WebApplication app)
    {
        if (app.Environment.IsDevelopment())
            app.UseDeveloperExceptionPage();

        app.UseHttpsRedirection();
        app.UseRouting();
        app.UseMiddleware<ExceptionHandlingMiddleware>();
        app.UseMiddleware<AppSecretAuthenticationMiddleware>();
        app.UseAuthorization();
        app.UseEndpoints(endpoints => { endpoints.MapControllers(); });

        if (!app.Environment.IsProduction())
        {
            app.UseSwagger();
            app.UseSwaggerUI();
        }

        var versionInfo = new
        {
            Version = Environment.GetEnvironmentVariable("APP_VERSION")
                ?? Assembly.GetExecutingAssembly().GetName().Version.ToString(),
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
        // TODO: Add HealthCheckServiceMiddleware when health check infrastructure is configured
        // app.UseMiddleware<HealthCheckServiceMiddleware>();

        return app;
    }

    public static WebApplicationBuilder RegisterSwagger(
        this WebApplicationBuilder builder, IConfiguration configuration)
    {
        builder.Services.AddSwaggerGen(options =>
        {
            options.SwaggerDoc("v1", new OpenApiInfo
            {
                Title = "Opstool API",
                Version = "v1"
            });

            options.AddSecurityDefinition(
                AuthorizationConfiguration.AuthorizationHeaderName,
                new OpenApiSecurityScheme
                {
                    In = ParameterLocation.Header,
                    Name = AuthorizationConfiguration.AuthorizationHeaderName,
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
                            Id = AuthorizationConfiguration.AuthorizationHeaderName
                        }
                    },
                    Array.Empty<string>()
                }
            });
        });
        return builder;
    }
}
