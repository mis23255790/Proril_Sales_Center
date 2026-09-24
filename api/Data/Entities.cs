namespace Proril.SalesIssue.Api.Data;

/*
 * PRORIL_WEB 用到的共用表。
 *
 * 業務議題本體（D_WorkProcess* / M_WorkProcessPhrase / M_WorkProcessType）、
 * CRM_Customer、H_FileLink 已切到 Proril_Sales_Center，對映搬到
 * api/Data/SalesCenter/（dotnet ef dbcontext scaffold 產生，不要手改，
 * 要改欄位對映去跑 database/scripts/scaffold-sales-center.ps1）。
 *
 * M_User / M_Permission / M_PermissionGroup / M_System 也在 2026 的權限控管搬遷裡切到
 * Proril_Sales_Center（人員管理與權限管理的 Controller 已一併搬過來，
 * 見 api/Controllers/Shared/MainApiController.User.cs / .SystemSetting.cs）。
 * M_Function 2026-09-24 起已不對映（權限樹改由 RBAC_Permission 驅動，沒有人讀它）。
 *
 * 這裡只留還在打 PRORIL_WEB 的表：
 *   - M_Department：1.0 Controllers/System/OrgApiController（組織維護）在寫，
 *     維持唯讀，等組織管理也搬過來再切。
 *   - V_ERPCustomer（ERP 唯讀 view，不在搬遷白名單）。
 *
 * 屬性名稱刻意沿用 1.0 scaffold 的結果（Wpno / Sno / AStatus），
 * 對照舊碼與 SQL 時不必再翻譯一層。實際 DB 欄位名在 DbContext 裡對映。
 */

/// <summary>
/// M_Department：部門／群組主檔，權限管理的「套用群組」下拉用它。
/// 1.0 的 OrgApiController（組織維護）在寫，2.0 唯讀。
/// </summary>
public class MDepartment
{
    public int Id { get; set; }
    public string DepCode { get; set; } = null!;
    public string DepName { get; set; } = null!;
    public string? DepLeader { get; set; }
    public string? Directions { get; set; }
    public int? DepLevel { get; set; }
    public string? ParentsDep { get; set; }
    public bool? OrgChartFlag { get; set; }
    public int? Horqueue { get; set; }
    public bool IsEnable { get; set; }
    public int DepGroup { get; set; }
}

/// <summary>
/// V_ERPCustomer：唯讀 View，客戶清單靠它補上 ERP 端的名稱。
/// 這是 View 不是資料表，所以不在 database/TABLES.txt 的 DACPAC 白名單裡。
/// </summary>
public class VErpcustomer
{
    public string Erpsource { get; set; } = null!;
    public string? Ma001 { get; set; }
    public string? Ma002 { get; set; }
    public string? Ma003 { get; set; }
    public string? Ma005 { get; set; }
    public string? Ma006 { get; set; }
    public string? Ma007 { get; set; }
    public string? Ma008 { get; set; }
    public string? Ma009 { get; set; }
    public string? Ma019 { get; set; }
    public string? Ma023 { get; set; }
    public string? Ma024 { get; set; }
    public string? ErpheadCustomer { get; set; }
}
