using Microsoft.AspNetCore.Mvc;
using Proril.SalesIssue.Api.Data;
using Proril.SalesIssue.Api.Helpers;

namespace Proril.SalesIssue.Api.Controllers.Shared;

/// <summary>
/// 所有 API controller 的共用基底。
///
/// 相對 1.0 的 BaseApiController 拿掉了：
///   - PRORILContext (dsWorkFlowContext)：另一個資料庫，業務議題用不到
///   - LogHelper 自製檔案 log：改用 ILogger，交給 host 的 logging 設定
/// </summary>
[ApiController]
[Route("[controller]/[action]")]
public abstract class BaseApiController : ControllerBase
{
    protected readonly SalesIssueDbContext db;
    protected readonly JwtHelper jwtHelper;
    private readonly ILogger _logger;

    protected BaseApiController(SalesIssueDbContext db, JwtHelper jwtHelper, ILogger logger)
    {
        this.db = db;
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
            return db.MUsers.Where(u => u.Account == account).Select(u => u.UserName).FirstOrDefault() ?? "";
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
            return db.MUsers.Where(u => u.Account == account).Select(u => u.IsAdmin).FirstOrDefault();
        }
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            return false;
        }
    }

    protected void WriteStepLog(string? methodName, string message)
        => _logger.LogInformation("{User} --> {Controller}::{Method}:: {Message}",
            GetUserNameByToken(), GetType().Name, methodName, message);

    protected void WriteExceptionLog(Exception ex)
        => _logger.LogError(ex, "{Controller} 發生例外", GetType().Name);
}
