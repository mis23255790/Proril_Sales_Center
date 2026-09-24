using Microsoft.AspNetCore.Mvc;
using Proril.SalesIssue.Api.Data;
using Proril.SalesIssue.Api.Data.SalesCenter;
using Proril.SalesIssue.Api.Helpers;
using Proril.SalesIssue.Api.Models;
using Proril.SalesIssue.Api.Services;

namespace Proril.SalesIssue.Api.Controllers.Shared;

/// <summary>
/// 所有 API controller 的共用基底。
///
/// 相對 1.0 的 BaseApiController 拿掉了：
///   - PRORILContext (dsWorkFlowContext)：另一個資料庫，業務議題用不到
///   - LogHelper 自製檔案 log：改用 ILogger，交給 host 的 logging 設定
///
/// 兩個 DbContext 都在這裡注入，子類別直接用 <c>db</c>（PRORIL_WEB）與
/// <c>scDb</c>（Proril_Sales_Center）。帳號與權限（M_User / RBAC_Role / RBAC_RoleUser /
/// RBAC_RolePermission）都在 <c>scDb</c>，權限解析集中在 <see cref="PermissionService"/>。
/// </summary>
[ApiController]
[Route("[controller]/[action]")]
public abstract class BaseApiController : ControllerBase
{
    // protected readonly ProrilWebDbContext db;
    protected readonly SalesCenterDbContext scDb;
    protected readonly JwtHelper jwtHelper;
    private readonly ILogger _logger;

    protected BaseApiController(
        ProrilWebDbContext db, SalesCenterDbContext scDb, JwtHelper jwtHelper, ILogger logger)
        // SalesCenterDbContext scDb, JwtHelper jwtHelper, ILogger logger)
    {
        // this.db = db;
        this.scDb = scDb;
        this.jwtHelper = jwtHelper;
        _logger = logger;
    }

    /// <summary>從 Authorization: Bearer 取登入帳號。取不到回空字串。</summary>
    protected string GetAccountByToken()
    {
        try
        {
            var header = Request?.Headers["Authorization"].ToString() ?? "";
            var parts = header.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length < 2) return "";
            return jwtHelper.GetAccountByToken(parts[1]);
        }
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            return "";
        }
    }

    protected string GetUserNameByToken()
    {
        try
        {
            var account = GetAccountByToken();
            if (string.IsNullOrWhiteSpace(account)) return "";
            return scDb.MUsers.Where(u => u.Account == account).Select(u => u.UserName).FirstOrDefault() ?? "";
        }
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            return "";
        }
    }

    /// <summary>
    /// 是不是系統管理員（掛了 IsSuperAdmin 的角色，見 <see cref="PermissionService"/>）。
    /// 取代 1.0 的 M_User.IsAdmin——那個欄位角色制之後不再被讀。
    /// </summary>
    protected bool IsAdmin(string account)
    {
        try
        {
            return GetPermissions(account).IsSuperAdmin;
        }
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            return false;
        }
    }

    /// <summary>某帳號的有效權限（角色 ∪ everyone），同一 request 內只查一次。</summary>
    protected EffectivePermissions GetPermissions(string account)
        => HttpContext.RequestServices.GetRequiredService<PermissionService>().Resolve(account);

    /// <summary>
    /// 目前登入者有沒有某個字串權限（<see cref="PermissionKeys"/>，例如
    /// <c>salesSearch.mixSalesShipping.viewAmount</c>）。superAdmin 直接放行；
    /// 其他人看所屬角色（RBAC_RoleUser）與 everyone 角色的 RBAC_RolePermission。
    ///
    /// 整支 Controller 的功能把關用 <see cref="Filters.RequirePermissionAttribute"/>，
    /// 這個給 Action 內的細項判斷（例如金額欄位）。
    /// </summary>
    protected bool HasPermission(string permissionKey)
    {
        var account = GetAccountByToken();
        if (string.IsNullOrWhiteSpace(account)) return false;
        return HasPermission(account, permissionKey);
    }

    /// <summary>同上，帳號由呼叫端給（匯出 Excel 那幾支是自己解 token 拿帳號）。</summary>
    protected bool HasPermission(string account, string permissionKey)
        => GetPermissions(account).Has(permissionKey);

    protected void WriteStepLog(string? methodName, string message)
        => _logger.LogInformation("{User} --> {Controller}::{Method}:: {Message}",
            GetUserNameByToken(), GetType().Name, methodName, message);

    protected void WriteExceptionLog(Exception ex)
        => _logger.LogError(ex, "{Controller} 發生例外", GetType().Name);
}
