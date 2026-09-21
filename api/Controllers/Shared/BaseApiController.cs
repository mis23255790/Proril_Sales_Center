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
        // ProrilWebDbContext db, SalesCenterDbContext scDb, JwtHelper jwtHelper, ILogger logger)
        SalesCenterDbContext scDb, JwtHelper jwtHelper, ILogger logger)
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
    /// 目前登入者有沒有某個功能的權限（M_Permission，admin 直接放行）。
    ///
    /// **與 1.0 的差異**：1.0 的 MainApi/System 這些管理端點只掛 [Authorize]，
    /// 是否能進畫面完全靠前端 checkPermission() 擋——等於任何登入者直接打 API
    /// 就能建管理員帳號或改別人的權限。2.0 在後端也擋一次。
    /// </summary>
    protected bool HasFunctionPermission(string functionNo)
    {
        var account = GetAccountByToken();
        if (string.IsNullOrWhiteSpace(account)) return false;
        if (IsAdmin(account)) return true;
        return scDb.MPermissions.Any(p =>
            (p.LinkNumber == account || p.LinkNumber == PermissionConst.AccountForAll)
            && p.FunctionNo == functionNo);
    }

    protected void WriteStepLog(string? methodName, string message)
        => _logger.LogInformation("{User} --> {Controller}::{Method}:: {Message}",
            GetUserNameByToken(), GetType().Name, methodName, message);

    protected void WriteExceptionLog(Exception ex)
        => _logger.LogError(ex, "{Controller} 發生例外", GetType().Name);
}
