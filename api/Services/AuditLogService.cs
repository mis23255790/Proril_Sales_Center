using Microsoft.EntityFrameworkCore;
using Newtonsoft.Json;
using Proril.SalesIssue.Api.Data.SalesCenter;
using Proril.SalesIssue.Api.Helpers;

namespace Proril.SalesIssue.Api.Services;

/// <summary>SYS_AuditLog.Action 的值。</summary>
public static class AuditActions
{
    public const string Login = "LOGIN";
    public const string LoginFail = "LOGIN_FAIL";
    public const string Create = "CREATE";
    public const string Update = "UPDATE";
    public const string Delete = "DELETE";
    public const string ResetPassword = "RESET_PASSWORD";
    public const string Unlock = "UNLOCK";
}

/// <summary>SYS_AuditLog.Target 不是頁面權限 key 的特殊值。</summary>
public static class AuditTargets
{
    public const string Auth = "auth";
}

/// <summary>
/// 寫稽核紀錄（SYS_AuditLog，database/AuditLogObjectsMigration.sql）。
///
/// Controller 一般用 <c>BaseApiController.WriteAudit</c>，它會自己帶操作者帳號與 IP。
///
/// **寫入失敗只記檔案 log、不往外丟**：稽核是附帶的，不能因為記不進去讓原本已經成功的操作
/// 回失敗（同 UploadApiController.AddFileLog 的理由）。
/// 用 ExecuteSql 直接 INSERT，不經過 change tracker：呼叫端 DbContext 上就算還有沒存的追蹤中實體，
/// 也不會被順便存進去；呼叫端應該在自己的 SaveChanges／Commit 之後才呼叫。
///
/// **Detail 不得放密碼、token、金鑰。**
/// </summary>
public class AuditLogService(SalesCenterDbContext scDb, LogHelper logHelper)
{
    /// <summary>保留期間，LogTimedHostedService 每天清一次。</summary>
    public static readonly TimeSpan Retention = TimeSpan.FromDays(365);

    private static readonly JsonSerializerSettings DetailJson = new()
    {
        NullValueHandling = NullValueHandling.Ignore,
        Formatting = Formatting.None
    };

    public void Write(string? account, string action, string target, string? targetId, object? detail, string? clientIp)
    {
        try
        {
            var detailJson = detail switch
            {
                null => null,
                string s => s,
                _ => JsonConvert.SerializeObject(detail, DetailJson)
            };

            scDb.Database.ExecuteSqlInterpolated($@"
INSERT INTO dbo.SYS_AuditLog (Account, Action, Target, TargetId, Detail, ClientIp)
VALUES ({Truncate(account, 20)}, {action}, {Truncate(target, 100)}, {Truncate(targetId, 100)}, {detailJson}, {Truncate(clientIp, 45)})");
        }
        catch (Exception ex)
        {
            logHelper.WriteExceptionLog(
                $"AuditLogService.Write 失敗（account:{account}, action:{action}, target:{target}, targetId:{targetId}）", ex);
        }
    }

    /// <summary>刪除超過保留期間的紀錄，回傳刪除筆數。</summary>
    public int Purge()
    {
        var cutoff = DateTime.UtcNow - Retention;
        return scDb.SysAuditLogs.Where(a => a.LogTime < cutoff).ExecuteDelete();
    }

    private static string? Truncate(string? value, int max)
        => value is null ? null : value.Length <= max ? value : value[..max];
}
