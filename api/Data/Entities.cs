namespace Proril.SalesIssue.Api.Data;

/*
 * 業務議題用到的資料表。
 *
 * 只搬 1.0 ProrilWebContext（13,782 行 / 347 個 DbSet）裡實際會碰到的部分。
 * 邊界對齊 database/TABLES.txt 的 DACPAC 白名單，多出來的兩個是：
 *   H_FileLink    上傳稽核 log（UploadApi 寫入）
 *   V_ERPCustomer 唯讀 View，客戶清單要 join 出 ERP 名稱
 *
 * 屬性名稱刻意沿用 1.0 scaffold 的結果（Wpno / Sno / AStatus），
 * 對照舊碼與 SQL 時不必再翻譯一層。實際 DB 欄位名在 DbContext 裡對映。
 */

/// <summary>D_WorkProcess：議題表頭。</summary>
public class DWorkProcess
{
    public int Id { get; set; }
    /// <summary>議題編號，6 碼左補零。</summary>
    public string Wpno { get; set; } = null!;
    public string? SopTitle { get; set; }
    /// <summary>最新進度（自由文字，不是狀態碼）。</summary>
    public string? Descript { get; set; }
    public string PhraseList { get; set; } = null!;
    public string? VerNo { get; set; }
    public DateTime? PubDate { get; set; }
    /// <summary>公開。</summary>
    public bool? PubFlag { get; set; }
    /// <summary>結案。與 AStatus 無關。</summary>
    public bool? FinFlag { get; set; }
    public int? ProgressStatus { get; set; }
    /// <summary>'Y' 有效 / 'N' 已失效（軟刪除），不是「已完成」。</summary>
    public string? AStatus { get; set; }
    public string? Creator { get; set; }
    public string? Leader { get; set; }
    public string? Authorize { get; set; }
    public string? Modifier { get; set; }
    public DateTime? CreateTime { get; set; }
    public DateTime? ModiTime { get; set; }
}

/// <summary>D_WorkProcessDetail：議題底下的一則進度。</summary>
public class DWorkProcessDetail
{
    public int Id { get; set; }
    public string Wpno { get; set; } = null!;
    /// <summary>4 碼左補零。</summary>
    public string Sno { get; set; } = null!;
    /// <summary>標題，慣例上放日期。後端列表就是靠這欄排序當時序。</summary>
    public string? ProcessCaption { get; set; }
    public string? ProcessCaption2 { get; set; }
    /// <summary>內文 HTML。</summary>
    public string? ProcessContent { get; set; }
    public string? Worker { get; set; }
    public string? AStatus { get; set; }
    /// <summary>原始檔名，分號分隔。與 RenameFile 靠索引對齊。</summary>
    public string? UploadFile { get; set; }
    /// <summary>改名後檔名，分號分隔。</summary>
    public string? RenameFile { get; set; }
    public string? ZipFile { get; set; }
    public string? Creator { get; set; }
    public string? Modifier { get; set; }
    public DateTime? CreateTime { get; set; }
    public DateTime? ModiTime { get; set; }

    public DWorkProcessDetail() { }

    public DWorkProcessDetail(DWorkProcessDetail src)
    {
        Id = src.Id;
        Wpno = src.Wpno;
        Sno = src.Sno;
        ProcessCaption = src.ProcessCaption;
        ProcessCaption2 = src.ProcessCaption2;
        ProcessContent = src.ProcessContent;
        Worker = src.Worker;
        AStatus = src.AStatus;
        UploadFile = src.UploadFile;
        RenameFile = src.RenameFile;
        ZipFile = src.ZipFile;
        Creator = src.Creator;
        Modifier = src.Modifier;
        CreateTime = src.CreateTime;
        ModiTime = src.ModiTime;
    }
}

/// <summary>D_WorkProcessSearch：議題 ←→ 關鍵字。</summary>
public class DWorkProcessSearch
{
    public int Id { get; set; }
    public string Wpno { get; set; } = null!;
    public string? PhraseType { get; set; }
    public string? PhraseCode { get; set; }
    public string? AStatus { get; set; }
    public string? Creator { get; set; }
    public string? Modifier { get; set; }
    public DateTime? CreateTime { get; set; }
    public DateTime? ModiTime { get; set; }

    public DWorkProcessSearch() { }

    public DWorkProcessSearch(DWorkProcessSearch src)
    {
        Id = src.Id;
        Wpno = src.Wpno;
        PhraseType = src.PhraseType;
        PhraseCode = src.PhraseCode;
        AStatus = src.AStatus;
        Creator = src.Creator;
        Modifier = src.Modifier;
        CreateTime = src.CreateTime;
        ModiTime = src.ModiTime;
    }
}

/// <summary>D_WorkProcessCustomer：議題 ←→ 客戶。</summary>
public class DWorkProcessCustomer
{
    public int Id { get; set; }
    public string Wpno { get; set; } = null!;
    public string? CustomerNo { get; set; }
    public string? CustomerType { get; set; }
    public string? AStatus { get; set; }
    public string? Creator { get; set; }
    public string? Modifier { get; set; }
    public DateTime? CreateTime { get; set; }
    public DateTime? ModiTime { get; set; }

    public DWorkProcessCustomer() { }

    public DWorkProcessCustomer(DWorkProcessCustomer src)
    {
        Id = src.Id;
        Wpno = src.Wpno;
        CustomerNo = src.CustomerNo;
        CustomerType = src.CustomerType;
        AStatus = src.AStatus;
        Creator = src.Creator;
        Modifier = src.Modifier;
        CreateTime = src.CreateTime;
        ModiTime = src.ModiTime;
    }
}

/// <summary>
/// D_WorkProcessPermission：誰能編輯／檢視某張議題。
/// 注意這張表沒有 aStatus 欄位，移除權限是真的刪列。
/// </summary>
public class DWorkProcessPermission
{
    public int Id { get; set; }
    public string Wpno { get; set; } = null!;
    /// <summary>1 檢視 / 10 編輯 / 20 公開，見 EWorkProcessPermission。</summary>
    public byte EnableType { get; set; }
    /// <summary>帳號，'000000' 代表全體使用者。</summary>
    public string Account { get; set; } = null!;
    public string? Creator { get; set; }
    public string? Modifier { get; set; }
    public DateTime? CreateTime { get; set; }
    public DateTime? ModiTime { get; set; }
}

/// <summary>M_WorkProcessPhrase：關鍵字主檔。(PhraseType, PhraseCode) 是業務上的唯一鍵。</summary>
public class MWorkProcessPhrase
{
    public int Id { get; set; }
    public string PhraseType { get; set; } = null!;
    public string PhraseCode { get; set; } = null!;
    public string PhraseName { get; set; } = null!;
    public string? Directions { get; set; }
    public bool? PubFlag { get; set; }
    public string? Principal { get; set; }
    public string? PotentialCustom { get; set; }
    public string? AStatus { get; set; }
    public string? Creator { get; set; }
    public DateTime? CreateTime { get; set; }
}

/// <summary>M_WorkProcessType：關鍵字分類主檔（01 搜尋片語 / 02 流程類別 / 03 職能主題）。</summary>
public class MWorkProcessType
{
    public int Id { get; set; }
    public string TypeCode { get; set; } = null!;
    public string TypeName { get; set; } = null!;
    public string? Descript { get; set; }
    public string? AStatus { get; set; }
    public string? Creator { get; set; }
    public DateTime? CreateTime { get; set; }
}

/// <summary>CRM_Customer：客戶主檔。</summary>
public class CrmCustomer
{
    public int Id { get; set; }
    public string? CustomerNo { get; set; }
    public string? CustomerSource { get; set; }
    public string? ErpcustomerNo { get; set; }
    public string? LongName { get; set; }
    public string? ShortName { get; set; }
    public string? ContactName { get; set; }
    public string? ContactTel1 { get; set; }
    public string? ContactTel2 { get; set; }
    public string? ContactFax { get; set; }
    public string? ContactEmail { get; set; }
    public string? Addr1 { get; set; }
    public string? Addr2 { get; set; }
    public string? AreaCode { get; set; }
    public string? CountryCode { get; set; }
    public string? SalesNo { get; set; }
    public string? SalesName { get; set; }
    public string? PotentialCustom { get; set; }
    public string? ErpheadCustomer { get; set; }
    public string? Erpsource { get; set; }
    public string? Memo { get; set; }
    public string? AStatus { get; set; }
    public string? Creator { get; set; }
    public DateTime? CreateTime { get; set; }
    public string? Modifier { get; set; }
    public DateTime? ModiTime { get; set; }

    public CrmCustomer() { }

    public CrmCustomer(CrmCustomer src)
    {
        Id = src.Id;
        CustomerNo = src.CustomerNo;
        CustomerSource = src.CustomerSource;
        ErpcustomerNo = src.ErpcustomerNo;
        LongName = src.LongName;
        ShortName = src.ShortName;
        ContactName = src.ContactName;
        ContactTel1 = src.ContactTel1;
        ContactTel2 = src.ContactTel2;
        ContactFax = src.ContactFax;
        ContactEmail = src.ContactEmail;
        Addr1 = src.Addr1;
        Addr2 = src.Addr2;
        AreaCode = src.AreaCode;
        CountryCode = src.CountryCode;
        SalesNo = src.SalesNo;
        SalesName = src.SalesName;
        PotentialCustom = src.PotentialCustom;
        ErpheadCustomer = src.ErpheadCustomer;
        Erpsource = src.Erpsource;
        Memo = src.Memo;
        AStatus = src.AStatus;
        Creator = src.Creator;
        CreateTime = src.CreateTime;
        Modifier = src.Modifier;
        ModiTime = src.ModiTime;
    }
}

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

/// <summary>H_FileLink：上傳稽核 log。</summary>
public class HFileLink
{
    public int Id { get; set; }
    public string? FilePath { get; set; }
    public string? FileType { get; set; }
    public int LinkFunctionNo { get; set; }
    public string LinkNo { get; set; } = null!;
    public DateTime UpdateTime { get; set; }
    public string UpdateUser { get; set; } = null!;
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
}
