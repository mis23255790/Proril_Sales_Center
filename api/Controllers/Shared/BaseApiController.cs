using Microsoft.AspNetCore.Mvc;
using Proril.SalesIssue.Api.Data;
using Proril.SalesIssue.Api.Data.SalesCenter;
using Proril.SalesIssue.Api.Helpers;
using Proril.SalesIssue.Api.Models;

namespace Proril.SalesIssue.Api.Controllers.Shared;

/// <summary>
/// 所有 API controller 的共用基底。
///
/// 相對 1.0 的 BaseApiController 拿掉了：
///   - PRORILContext (dsWorkFlowContext)：另一個資料庫，業務議題用不到
///   - LogHelper 自製檔案 log：改用 ILogger，交給 host 的 logging 設定
///
/// 兩個 DbContext 都在這裡注入，子類別直接用 <c>db</c>（PRORIL_WEB）與
/// <c>scDb</c>（Proril_Sales_Center）。帳號與權限（M_User / M_Permission）
/// 已經切到 <c>scDb</c>，所以連 GetUserNameByToken / IsAdmin 都走 scDb。
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

    protected bool IsAdmin(string account)
    {
        try
        {
            return scDb.MUsers.Where(u => u.Account == account).Select(u => u.IsAdmin).FirstOrDefault();
        }
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            return false;
        }
    }

    /// <summary>
    /// 目前登入者有沒有某個字串權限（<see cref="PermissionKeys"/>，例如
    /// <c>salesSearch.mixSalesShipping.viewAmount</c>）。admin 直接放行；
    /// 其他人看 M_Permission 裡 LinkNumber = 自己 或 000000（全體）的列。
    ///
    /// **與 1.0 的差異**：1.0 的 MainApi/System 這些管理端點只掛 [Authorize]，
    /// 是否能進畫面完全靠前端 checkPermission() 擋——等於任何登入者直接打 API
    /// 就能建管理員帳號或改別人的權限。2.0 在後端也擋一次。
    /// </summary>
    protected bool HasPermission(string permissionKey)
    {
        var account = GetAccountByToken();
        if (string.IsNullOrWhiteSpace(account)) return false;
        return HasPermission(account, permissionKey);
    }

    /// <summary>同上，帳號由呼叫端給（匯出 Excel 那幾支是自己解 token 拿帳號）。</summary>
    protected bool HasPermission(string account, string permissionKey)
    {
        var trimmed = account.Trim();
        if (IsAdmin(trimmed)) return true;
        return scDb.MPermissions.Any(p =>
            (p.LinkNumber == trimmed || p.LinkNumber == PermissionConst.AccountForAll)
            && p.PermissionKey == permissionKey);
    }

    protected void WriteStepLog(string? methodName, string message)
        => _logger.LogInformation("{User} --> {Controller}::{Method}:: {Message}",
            GetUserNameByToken(), GetType().Name, methodName, message);

    protected void WriteExceptionLog(Exception ex)
        => _logger.LogError(ex, "{Controller} 發生例外", GetType().Name);
}
