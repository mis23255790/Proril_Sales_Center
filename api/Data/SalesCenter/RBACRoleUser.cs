using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

/// <summary>帳號與角色的對應（多對多）。建表見 database/RbacObjectsMigration.sql。</summary>
public partial class RBACRoleUser
{
    public int Id { get; set; }

    public string Account { get; set; } = null!;

    public int RoleId { get; set; }

    /// <summary>'Y' = 有效；手動改成 'N' 即視為失效，api/ 只認 'Y'。</summary>
    public string AStatus { get; set; } = null!;

    public string? Creator { get; set; }

    public DateTime? CreateTime { get; set; }

    public string? Modifier { get; set; }

    public DateTime? ModiTime { get; set; }
}
