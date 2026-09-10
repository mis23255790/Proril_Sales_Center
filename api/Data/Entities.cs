namespace Proril.SalesIssue.Api.Data;

/*
 * PRORIL_WEB 用到的共用表。
 *
 * 業務議題本體（D_WorkProcess* / M_WorkProcessPhrase / M_WorkProcessType）、
 * CRM_Customer、H_FileLink 已切到 Proril_Sales_Center，對映搬到
 * api/Data/SalesCenter/（dotnet ef dbcontext scaffold 產生，不要手改，
 * 要改欄位對映去跑 database/scripts/scaffold-sales-center.ps1）。
 *
 * 這裡只留還在打 PRORIL_WEB 的表：M_User / M_Permission（1.0 還在寫，2.0 唯讀）、
 * V_ERPCustomer（ERP 唯讀 view，不在搬遷白名單）。
 *
 * 屬性名稱刻意沿用 1.0 scaffold 的結果（Wpno / Sno / AStatus），
 * 對照舊碼與 SQL 時不必再翻譯一層。實際 DB 欄位名在 DbContext 裡對映。
 */

/// <summary>M_User：使用者。</summary>
public class MUser
{
    public int Id { get; set; }
    public string? Account { get; set; }
    public string? Password { get; set; }
    public string? UserName { get; set; }
    public bool IsEnable { get; set; }
    public bool IsFirstLogin { get; set; }
    public DateTime? LastChangePwd { get; set; }
    public bool IsAdmin { get; set; }
    public bool IsLocked { get; set; }
    public byte PwdWrongTime { get; set; }
}

/// <summary>M_Permission：功能層級權限。議題列表用它判斷使用者是否有「公開」權限。</summary>
public class MPermission
{
    public int Id { get; set; }
    public string? LinkNumber { get; set; }
    public int FunctionNo { get; set; }
    public string? Creator { get; set; }
    public byte LinkType { get; set; }
    public DateTime? CreateTime { get; set; }
    public int? PermissionLinkTypeId { get; set; }
    public string? Modifier { get; set; }
    public DateTime? ModiTime { get; set; }
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
