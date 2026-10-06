using System.Globalization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Proril.SalesIssue.Api.Controllers.Shared;
using Proril.SalesIssue.Api.Data.SalesCenter;
using Proril.SalesIssue.Api.Filters;
using Proril.SalesIssue.Api.Helpers;
using Proril.SalesIssue.Api.Models;
using Proril.SalesIssue.Api.Services;

namespace Proril.SalesIssue.Api.Controllers.SystemSetting;

/// <summary>
/// 稽核紀錄查詢（系統管理 / 系統設定 / 稽核紀錄，PAGE system.auditLog）。2.0 新功能，1.0 沒有。
///
/// 資料是 SYS_AuditLog（database/AuditLogObjectsMigration.sql），寫入見 <see cref="AuditLogService"/>。
/// 唯讀，不提供刪改；清理只有 LogTimedHostedService 的保留一年。
///
/// 時間：DB 存 UTC，查詢條件的日期與回傳的時間一律是台灣時間（<see cref="TaiwanTime"/> 同一套 +8）。
/// </summary>
[Authorize]
[RequirePermission(PermissionKeys.SystemSetting.AuditLog)]
public class AuditLogApiController(SalesCenterDbContext scDb, JwtHelper jwtHelper, ILogger<AuditLogApiController> logger)
    : BaseApiController(scDb, jwtHelper, logger)
{
    private static readonly TimeSpan TaiwanOffset = TimeSpan.FromHours(8);

    /// <summary>
    /// 查詢稽核紀錄，新到舊，後端分頁。
    /// <paramref name="startDate"/>／<paramref name="endDate"/> 是台灣日期 yyyyMMdd（含迄日整天），不給就不限。
    /// <paramref name="keyword"/> 比對 TargetId 與 Detail（JSON 內容，例如角色名稱、權限 key）。
    /// <paramref name="pageSize"/> &lt;= 0 代表不分頁。Body2 = { totalCount }。
    /// </summary>
    [HttpGet]
    public async Task<CustomApiViewModel> GetAuditLogs(
        string? startDate, string? endDate, string? account, string? action, string? target, string? keyword,
        int pageIndex = 0, int pageSize = 50)
    {
        var query = scDb.SysAuditLogs.AsNoTracking().AsQueryable();

        if (TryParseDate(startDate, out var start))
        {
            var startUtc = start - TaiwanOffset;
            query = query.Where(a => a.LogTime >= startUtc);
        }
        if (TryParseDate(endDate, out var end))
        {
            var endUtc = end.AddDays(1) - TaiwanOffset;
            query = query.Where(a => a.LogTime < endUtc);
        }
        if (!string.IsNullOrWhiteSpace(account))
        {
            var trimmed = account.Trim();
            query = query.Where(a => a.Account == trimmed);
        }
        if (!string.IsNullOrWhiteSpace(action))
        {
            var trimmed = action.Trim();
            query = query.Where(a => a.Action == trimmed);
        }
        if (!string.IsNullOrWhiteSpace(target))
        {
            var trimmed = target.Trim();
            query = query.Where(a => a.Target == trimmed);
        }
        if (!string.IsNullOrWhiteSpace(keyword))
        {
            var kw = keyword.Trim();
            query = query.Where(a => (a.TargetId != null && a.TargetId.Contains(kw)) || (a.Detail != null && a.Detail.Contains(kw)));
        }

        var totalCount = await query.CountAsync();

        var ordered = query.OrderByDescending(a => a.Id);
        var rows = pageSize <= 0
            ? await ordered.ToListAsync()
            : await ordered.Skip(Math.Max(pageIndex, 0) * pageSize).Take(pageSize).ToListAsync();

        // 姓名、功能名稱另外查（只查本頁用到的），不跟大表 join
        var accounts = rows.Select(r => r.Account).Where(a => !string.IsNullOrEmpty(a)).Distinct().ToList();
        var userNames = (await scDb.MUsers.AsNoTracking()
                .Where(u => accounts.Contains(u.Account))
                .Select(u => new { u.Account, u.UserName })
                .ToListAsync())
            .GroupBy(u => (u.Account ?? "").Trim(), StringComparer.OrdinalIgnoreCase)
            .ToDictionary(g => g.Key, g => g.First().UserName ?? "", StringComparer.OrdinalIgnoreCase);
        var targetLabels = await TargetLabelsAsync(rows.Select(r => r.Target).Distinct().ToList());

        return new CustomApiViewModel
        {
            IsSuccess = true,
            Body = rows.Select(r => new
            {
                r.Id,
                LogTime = (r.LogTime + TaiwanOffset).ToString("yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture),
                r.Account,
                UserName = userNames.TryGetValue((r.Account ?? "").Trim(), out var name) ? name : null,
                r.Action,
                r.Target,
                TargetLabel = targetLabels.TryGetValue(r.Target, out var label) ? label : r.Target,
                r.TargetId,
                r.Detail,
                r.ClientIp
            }).ToList(),
            Body2 = new { TotalCount = totalCount }
        };
    }

    /// <summary>「功能」下拉：稽核表裡出現過的 Target 與名稱（登入固定叫「登入」）。</summary>
    [HttpGet]
    public async Task<CustomApiViewModel> GetAuditLogTargets()
    {
        var targets = await scDb.SysAuditLogs.AsNoTracking().Select(a => a.Target).Distinct().ToListAsync();
        var labels = await TargetLabelsAsync(targets);
        return new CustomApiViewModel
        {
            IsSuccess = true,
            Body = targets
                .Select(t => new { Value = t, Label = labels.TryGetValue(t, out var label) ? label : t })
                .OrderBy(t => t.Value == AuditTargets.Auth ? 0 : 1).ThenBy(t => t.Label)
                .ToList()
        };
    }

    /// <summary>Target（頁面權限 key）→ RBAC_Permission 的名稱；auth 是「登入」。</summary>
    private async Task<Dictionary<string, string>> TargetLabelsAsync(List<string> targets)
    {
        var labels = await scDb.RBACPermissions.AsNoTracking()
            .Where(p => targets.Contains(p.PermissionKey))
            .Select(p => new { p.PermissionKey, p.Label })
            .ToDictionaryAsync(p => p.PermissionKey, p => p.Label);
        labels[AuditTargets.Auth] = "登入";
        return labels;
    }

    private static bool TryParseDate(string? value, out DateTime date)
        => DateTime.TryParseExact((value ?? "").Trim(), "yyyyMMdd", CultureInfo.InvariantCulture, DateTimeStyles.None, out date);
}
