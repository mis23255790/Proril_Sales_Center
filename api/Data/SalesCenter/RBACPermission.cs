using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

/// <summary>
/// 權限主檔（RBAC_Permission，2.0 新表，PRORIL_WEB 沒有）：單一表自我參照的權限樹，
/// 側欄、模組首頁、權限管理的樹都由它長出來，角色只從這裡挑。
///
/// 節點類型見 <c>PermissionNodeType</c>：MODULE（模組）→ GROUP（分組）→ PAGE（頁面）→ ACTION（細項）。
/// 搬位置改 <see cref="ParentKey"/>、換順序改 <see cref="Sort"/>，前端不用改程式。
///
/// 原名 M_PermissionDef，建表見 database/PermissionDefObjectsMigration.sql，
/// 改名、改成單一樹（拿掉 FunctionNo / LinkType、頁面 key 拿掉 .view）見 database/RbacObjectsMigration.sql。
/// </summary>
public partial class RBACPermission
{
    public int Id { get; set; }

    /// <summary>節點代碼，例如 salesSearch / salesSearch.grpSales / salesSearch.mixSalesShipping / salesSearch.mixSalesShipping.viewAmount。</summary>
    public string PermissionKey { get; set; } = null!;

    /// <summary>MODULE / GROUP / PAGE / ACTION。</summary>
    public string NodeType { get; set; } = null!;

    /// <summary>父節點的 PermissionKey，NULL = 最上層。</summary>
    public string? ParentKey { get; set; }

    public string Label { get; set; } = null!;

    /// <summary>英文名稱，目前只有模組有（首頁卡片副標）。</summary>
    public string? LabelEn { get; set; }

    /// <summary>前端路由（不含 /sales-center），MODULE / PAGE 才有。</summary>
    public string? Path { get; set; }

    public string? Icon { get; set; }

    public string? Description { get; set; }

    public int Sort { get; set; }

    /// <summary>'Y' = 有效；'N' = 停用，**連同底下所有節點**都不算（見 PermissionService.ActiveNodes）。</summary>
    public string AStatus { get; set; } = null!;

    public string? Creator { get; set; }

    public DateTime? CreateTime { get; set; }

    public string? Modifier { get; set; }

    public DateTime? ModiTime { get; set; }
}
