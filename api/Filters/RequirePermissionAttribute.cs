using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Proril.SalesIssue.Api.Helpers;
using Proril.SalesIssue.Api.Models;
using Proril.SalesIssue.Api.Services;

namespace Proril.SalesIssue.Api.Filters;

/// <summary>
/// 功能層級把關：目前登入者要有其中**任一個** PermissionKey 才進得了這個 Controller / Action，
/// 否則回 HTTP 403 + <see cref="CustomApiViewModel"/>（isSuccess = false）。
///
/// 掛在 class 上代表整支 Controller 都要這個功能的 <c>.view</c>；
/// 同一支 Controller 被好幾個功能共用時，把那幾個 <c>.view</c> 一起列上去。
/// 用 403 而不是 200 + isSuccess = false，是因為前端把 isSuccess = false 當「查無資料」處理，
/// 權限不足會被默默吞成空清單。
///
/// 1.0 只掛 [Authorize]，進不進得去畫面完全靠前端擋；2.0 補在後端。
/// </summary>
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method, AllowMultiple = false)]
public sealed class RequirePermissionAttribute(params string[] permissionKeys) : TypeFilterAttribute(typeof(RequirePermissionFilter))
{
    public string[] PermissionKeys { get; } = permissionKeys;

    private sealed class RequirePermissionFilter(JwtHelper jwtHelper, PermissionService permissionService)
        : IAuthorizationFilter
    {
        public void OnAuthorization(AuthorizationFilterContext context)
        {
            // [AllowAnonymous] 的端點不擋
            if (context.ActionDescriptor.EndpointMetadata.OfType<Microsoft.AspNetCore.Authorization.IAllowAnonymous>().Any())
                return;

            // Action 上的比 Controller 上的優先（最後一個是最靠近 Action 的那個）
            var attribute = context.ActionDescriptor.EndpointMetadata.OfType<RequirePermissionAttribute>().LastOrDefault();
            if (attribute is null || attribute.PermissionKeys.Length == 0) return;

            var header = context.HttpContext.Request.Headers.Authorization.ToString();
            var parts = header.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            var account = parts.Length < 2 ? "" : jwtHelper.GetAccountByToken(parts[1]);

            var permissions = permissionService.Resolve(account);
            if (attribute.PermissionKeys.Any(permissions.Has)) return;

            context.Result = new ObjectResult(new CustomApiViewModel
            {
                IsSuccess = false,
                Message = "沒有此功能的權限"
            })
            { StatusCode = StatusCodes.Status403Forbidden };
        }
    }
}
