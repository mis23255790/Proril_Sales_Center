using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

/// <summary>角色擁有的 PermissionKey（對照 RBAC_Permission）。建表見 database/RbacObjectsMigration.sql。</summary>
public partial class RBACRolePermission
{
    public int Id { get; set; }

    public int RoleId { get; set; }

    public string PermissionKey { get; set; } = null!;

    /// <summary>'Y' = 有效；手動改成 'N' 即視為失效，api/ 只認 'Y'。</summary>
    public string AStatus { get; set; } = null!;

    public string? Creator { get; set; }

    public DateTime? CreateTime { get; set; }

    public string? Modifier { get; set; }

    public DateTime? ModiTime { get; set; }
}
