using Proril.SalesIssue.Api.Helpers;

namespace Proril.SalesIssue.Api.Middleware;

/// <summary>
/// 每個 request 進出都自動記 log，不用在任何 Controller/Action 加呼叫碼。
/// 掛在 UseRouting() 之前，所有打進來的 request（含每支 API）都會經過這裡。
/// 同時寫 ILogger（console/host log）跟 LogHelper（1.0 那種 Logs/proril_log/yyyyMMdd.txt 文字檔）。
/// </summary>
public class RequestLoggingMiddleware(RequestDelegate next, ILogger<RequestLoggingMiddleware> logger, LogHelper logHelper)
{
    public async Task InvokeAsync(HttpContext context)
    {
        logger.LogInformation("--> {Method} {Path}{Query}",
            context.Request.Method, context.Request.Path, context.Request.QueryString);
        logHelper.WriteLog($"--> {context.Request.Method} {context.Request.Path}{context.Request.QueryString}");

        await next(context);

        logger.LogInformation("<-- {Method} {Path} {StatusCode}",
            context.Request.Method, context.Request.Path, context.Response.StatusCode);
        logHelper.WriteLog($"<-- {context.Request.Method} {context.Request.Path} {context.Response.StatusCode}");
    }
}
