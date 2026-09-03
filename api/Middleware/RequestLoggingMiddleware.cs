namespace Proril.SalesIssue.Api.Middleware;

/// <summary>
/// 每個 request 進出都自動記 log，不用在任何 Controller/Action 加呼叫碼。
/// 掛在 UseRouting() 之前，所有打進來的 request（含每支 API）都會經過這裡。
/// </summary>
public class RequestLoggingMiddleware(RequestDelegate next, ILogger<RequestLoggingMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext context)
    {
        logger.LogInformation("--> {Method} {Path}{Query}",
            context.Request.Method, context.Request.Path, context.Request.QueryString);

        await next(context);

        logger.LogInformation("<-- {Method} {Path} {StatusCode}",
            context.Request.Method, context.Request.Path, context.Response.StatusCode);
    }
}
