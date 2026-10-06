using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

/// <summary>
/// 稽核紀錄（database/AuditLogObjectsMigration.sql）。寫入一律走 <c>Services/AuditLogService.cs</c>。
/// <see cref="LogTime"/> 是 UTC。
/// </summary>
public partial class SysAuditLog
{
    public long Id { get; set; }

    public DateTime LogTime { get; set; }

    public string? Account { get; set; }

    public string Action { get; set; } = null!;

    public string Target { get; set; } = null!;

    public string? TargetId { get; set; }

    public string? Detail { get; set; }

    public string? ClientIp { get; set; }
}
