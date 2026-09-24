using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

/// <summary>
/// 角色（2.0 新表，PRORIL_WEB 沒有）。建表見 database/RbacObjectsMigration.sql。
/// 系統角色（IsSystem）只有 superAdmin / everyone 兩個，見 <c>RoleCodes</c>。
/// </summary>
public partial class RBACRole
{
    public int Id { get; set; }

    public string RoleCode { get; set; } = null!;

    public string RoleName { get; set; } = null!;

    public string? Description { get; set; }

    /// <summary>系統角色：不可刪、不可改代碼。</summary>
    public bool IsSystem { get; set; }

    /// <summary>全放行（取代 M_User.IsAdmin）。</summary>
    public bool IsSuperAdmin { get; set; }

    /// <summary>所有啟用帳號自動擁有，不需指派成員（取代 LinkNumber = 000000）。</summary>
    public bool IsDefault { get; set; }

    public int Sort { get; set; }

    /// <summary>'Y' = 有效；手動改成 'N' 即視為失效，api/ 只認 'Y'。</summary>
    public string AStatus { get; set; } = null!;

    public string? Creator { get; set; }

    public DateTime? CreateTime { get; set; }

    public string? Modifier { get; set; }

    public DateTime? ModiTime { get; set; }
}
