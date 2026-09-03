using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Controllers;
using Microsoft.AspNetCore.Mvc.Filters;
using Proril.SalesIssue.Api.Models;

namespace Proril.SalesIssue.Api.Filters;

/// <summary>
/// 全域例外攔截，取代每個 Action 各自的 try/catch。
///
/// 大部分 Action 回傳 <see cref="CustomApiViewModel"/>，但 MainApiController 的
/// Login/LoginSso 回傳 <see cref="Models.LoginModel"/>——兩者都是「布林旗標預設 false
/// + Message 字串」的形狀，所以用 Action 實際宣告的回傳型別動態產生物件並塞 Message，
/// 不要寫死成 CustomApiViewModel，否則登入例外時的回傳形狀會跟前端對不上。
/// </summary>
public class ApiExceptionFilter(ILogger<ApiExceptionFilter> logger) : IExceptionFilter
{
    public void OnException(ExceptionContext context)
    {
        var controllerName = context.ActionDescriptor.RouteValues.TryGetValue("controller", out var c)
            ? c : context.HttpContext.Request.Path.ToString();
        logger.LogError(context.Exception, "{Controller} 發生未處理例外", controllerName);

        var message = context.Exception.InnerException?.Message ?? context.Exception.Message;
        var returnType = (context.ActionDescriptor as ControllerActionDescriptor)?.MethodInfo.ReturnType;

        object body;
        if (returnType is not null && returnType.GetConstructor(Type.EmptyTypes) is not null)
        {
            body = Activator.CreateInstance(returnType)!;
            returnType.GetProperty("Message")?.SetValue(body, message);
        }
        else
        {
            body = new CustomApiViewModel { IsSuccess = false, Message = message };
        }

        context.Result = new ObjectResult(body) { StatusCode = 200 };
        context.ExceptionHandled = true;
    }
}
