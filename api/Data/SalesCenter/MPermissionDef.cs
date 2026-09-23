using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

/// <summary>
/// 字串權限主檔（2.0 新表，PRORIL_WEB 沒有）。建表見 database/PermissionDefObjectsMigration.sql。
/// </summary>
public partial class MPermissionDef
{
    public int Id { get; set; }

    public string PermissionKey { get; set; } = null!;

    public string FunctionNo { get; set; } = null!;

    public byte LinkType { get; set; }

    public int? PermissionLinkTypeId { get; set; }

    public string? ParentPermissionKey { get; set; }

    public string ActionName { get; set; } = null!;

    public int Sort { get; set; }

    public string AStatus { get; set; } = null!;

    public string? Creator { get; set; }

    public DateTime? CreateTime { get; set; }

    public string? Modifier { get; set; }

    public DateTime? ModiTime { get; set; }
}
