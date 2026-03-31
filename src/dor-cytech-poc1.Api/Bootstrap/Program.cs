using System;
using System.Diagnostics;
using System.Threading.Tasks;
using Microsoft.AspNetCore;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Logging;

namespace dor-cytech-poc1.Api.Bootstrap
{
    public sealed class Program
    {
        #region Methods

        public static async Task Main(string[] args)
        {
            try
            {
                await CreateWebHostBuilder(args).Build().RunAsync();
            }
            catch (Exception ex)
            {
                Trace.TraceError($"Failed to start web application. Exception={ex}");
                throw;
            }
        }

        #endregion

        #region Utilities

        private static IWebHostBuilder CreateWebHostBuilder(string[] args)
        {
            var builder = WebHost.CreateDefaultBuilder(args)
                .UseStartup<Startup>()
                .ConfigureLogging(options => options.ClearProviders());

            if(!Debugger.IsAttached)
                builder.UseUrls("http://*:80");

            return builder;
        }

        #endregion
    }
}
