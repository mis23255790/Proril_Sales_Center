using Proril.SalesIssue.Api.Data;
using SC = Proril.SalesIssue.Api.Data.SalesCenter;

namespace Proril.SalesIssue.Api.Models;

/// <summary>
/// 1.0 的統一回傳信封，前端 app/types/api.ts 就是對著這個寫的，不要改形狀。
///
/// 注意 <see cref="IsSuccess"/> = false **不一定是錯誤**：查無資料時後端也回 false
/// 加一段說明訊息，前端要當成空清單處理。
/// </summary>
public class CustomApiViewModel
{
    public bool IsSuccess { get; set; } = false;
    public string? Message { get; set; }
    public object? Body { get; set; }
    public object? Body2 { get; set; }
}

/// <summary>登入回傳。</summary>
public class LoginModel
{
    public int Code { get; set; }
    public bool Status { get; set; }
    public string? Username { get; set; }
    public string? Message { get; set; }
    public string? Token { get; set; }
    public string? Permission { get; set; }
}

public record LoginViewModel(string Account, string Password);

/// <summary>SSO 登入用，帳號已由 PRORIL 通行證驗證過身分，不再帶密碼。</summary>
public record SsoLoginViewModel(string Account);

/// <summary>
/// 議題列表／表頭的回傳形狀（1.0 的 DWorkProcessesEx）。
///
/// 除了 D_WorkProcess 本身，還帶了一堆 join 出來的顯示欄位。
/// PhraseTypeList / PhraseCodeList / PhraseNameList 是三串分號字串，
/// **靠索引對齊**，不是 key-value —— 任何一串被過濾或排序，對應關係就整個錯開。
/// </summary>
public class DWorkProcessesEx : SC.DWorkProcess
{
    public DWorkProcessesEx() { }

    public DWorkProcessesEx(SC.DWorkProcess source)
    {
        Id = source.Id;
        Wpno = source.Wpno;
        SopTitle = source.SopTitle;
        Descript = source.Descript;
        PhraseList = source.PhraseList;
        VerNo = source.VerNo;
        PubDate = source.PubDate;
        PubFlag = source.PubFlag;
        FinFlag = source.FinFlag;
        ProgressStatus = source.ProgressStatus;
        AStatus = source.AStatus;
        Creator = source.Creator;
        Leader = source.Leader;
        Authorize = source.Authorize;
        Modifier = source.Modifier;
        CreateTime = source.CreateTime;
        ModiTime = source.ModiTime;
    }

    public string ProcessCaption { get; set; } = string.Empty;
    public string ProcessCaption2 { get; set; } = string.Empty;
    public string ProcessContent { get; set; } = string.Empty;

    public string PhraseCodeList { get; set; } = string.Empty;
    public string PhraseTypeList { get; set; } = string.Empty;
    public string PhraseNameList { get; set; } = string.Empty;

    public string Account { get; set; } = string.Empty;
    /// <summary>建立者姓名。</summary>
    public string UserName { get; set; } = string.Empty;
    public string LastModifierName { get; set; } = string.Empty;
    public DateTime? LastModiTime { get; set; }
    public byte EnableType { get; set; }
    public string PotentialCustom { get; set; } = string.Empty;
    public string CustomerNo { get; set; } = string.Empty;
    public string CustomerName { get; set; } = string.Empty;
    public bool ViewStatus { get; set; }
}

/// <summary>
/// GetSOPList_Edit 分頁後的統計，放在 <see cref="CustomApiViewModel.Body2"/>。
/// 三個 tab 的筆數是「分頁前、篩選後」的統計，不會因為切頁改變；
/// TotalCount 則是目前 tab 篩選後的筆數，給前端分頁列算頁數用。
/// </summary>
public class SalesIssueListSummary
{
    public int TotalCount { get; set; }
    public int OngoingCount { get; set; }
    public int FinishedCount { get; set; }
    public int AllCount { get; set; }
}

/// <summary>
/// GetPOCheckView 分頁後的統計，放在 <see cref="CustomApiViewModel.Body2"/>。
/// 分頁的單位是「訂單」（V_POList 一列），不是攤平後的品號明細列——
/// NotCheckedCount / CheckedCount 是「篩選後、切頁籤前」以訂單數計算，不會因為
/// 目前選哪個頁籤而變動；TotalCount 才是目前頁籤篩選後的訂單數，給前端分頁列算頁數用。
/// </summary>
public class OrderInfoVerifySummary
{
    public int TotalCount { get; set; }
    public int NotCheckedCount { get; set; }
    public int CheckedCount { get; set; }
}

/// <summary>進度明細 + 建立者／修改者姓名。</summary>
public class DWorkProcessDetailViewModel : SC.DWorkProcessDetail
{
    /// <summary>
    /// SC 的實體是 dotnet ef scaffold 產生的純 POCO，沒有複製建構子（重新 scaffold 會整個
    /// 檔案被蓋掉，寫在那邊會消失），所以複製建構子放在這裡手動逐欄位複製。
    /// </summary>
    public DWorkProcessDetailViewModel(SC.DWorkProcessDetail src)
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

    public string? CreatorName { get; set; }
    public string? ModifierName { get; set; }
}

/// <summary>議題掛的關鍵字 + 關鍵字名稱。</summary>
public class DWorkProcessSearchEx : SC.DWorkProcessSearch
{
    public DWorkProcessSearchEx(SC.DWorkProcessSearch src)
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

    public string? PhraseName { get; set; }
}

/// <summary>議題掛的客戶 + 客戶顯示資料。</summary>
public class DWorkProcessCustomerEx : SC.DWorkProcessCustomer
{
    public DWorkProcessCustomerEx(SC.DWorkProcessCustomer src)
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

    public string ShortName { get; set; } = string.Empty;
    public string LongName { get; set; } = string.Empty;
    public string ContactName { get; set; } = string.Empty;
    public string ContactTEL1 { get; set; } = string.Empty;
}

/// <summary>客戶主檔 + ERP 端名稱。</summary>
public class CrmCustomerViewModel : SC.CrmCustomer
{
    public CrmCustomerViewModel(SC.CrmCustomer src)
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

    public string ERPCustomShortName { get; set; } = string.Empty;
    public string ERPCustomLongName { get; set; } = string.Empty;
}

/// <summary>
/// ERP 客戶 + 左併到的內網客戶代碼（同一個 ERP 客戶可能對到一筆 CRM_Customer，也可能還沒建）。
/// </summary>
public class VErpcustomerViewModel : VErpcustomer
{
    public string CustomerNo { get; set; } = string.Empty;
}

/// <summary>客戶情報 + 作者姓名（join M_User.Account）。1.0 對應 <c>CrmCustomerMemoViewModel</c>。</summary>
public class CrmCustomerMemoViewModel : SC.CrmCustomerMemo
{
    public CrmCustomerMemoViewModel(SC.CrmCustomerMemo src)
    {
        Id = src.Id;
        CustomerNo = src.CustomerNo;
        MemoType = src.MemoType;
        MemoDesc = src.MemoDesc;
        FileName = src.FileName;
        AStatus = src.AStatus;
        Creator = src.Creator;
        CreateTime = src.CreateTime;
        Modifier = src.Modifier;
        ModiTime = src.ModiTime;
    }

    public string CreatorName { get; set; } = string.Empty;
}

// ---------------------------------------------------------------- 客戶信用額度（銷貨檢索客戶頁籤）

/// <summary>
/// <c>prc_COPGetCredit</c> 的結果（<see cref="CopGetCredit"/>）+ 母公司簡稱/全名
/// （join <c>V_ERPCustomer.Ma001</c>）。1.0 對應 <c>COPCreditViewModel</c>，
/// 欄位攤平沿用 1.0 的中文命名，跟 <see cref="CopGetCredit"/> 一樣不做語意改名。
/// </summary>
public sealed record CustomerCreditRow(
    decimal 應收金額, decimal 未結帳銷貨, decimal 訂貨出貨通知金額, decimal 預收金額,
    decimal 已出貨抵預收金額, decimal 應收合計金額, decimal 未出貨訂單總金額,
    decimal 未出貨訂單金額比率, decimal 信用可超出額, decimal 信用餘額,
    string? ParentCorpShortName, string? ParentCorpLongName)
{
    public CustomerCreditRow(CopGetCredit c, string? parentCorpShortName, string? parentCorpLongName)
        : this(c.應收金額, c.未結帳銷貨, c.訂貨出貨通知金額, c.預收金額, c.已出貨抵預收金額,
            c.應收合計金額, c.未出貨訂單總金額, c.未出貨訂單金額比率, c.信用可超出額, c.信用餘額,
            parentCorpShortName, parentCorpLongName)
    {
    }
}

/// <summary>
/// <c>prc_COPGetCredit_CRM</c> 的結果（<see cref="CopGetCreditCrm"/>）+ 母公司簡稱/全名。
/// 1.0 對應 <c>COPCreditCRMViewModel</c>，比 <see cref="CustomerCreditRow"/> 多幣別欄位。
/// </summary>
public sealed record CustomerCreditCrmRow(
    decimal 應收金額, decimal 未結帳銷貨, decimal 訂貨出貨通知金額, decimal 預收金額,
    decimal 已出貨抵預收金額, decimal 應收合計金額, decimal 未出貨訂單總金額,
    decimal 未出貨訂單金額比率, decimal 信用可超出額, decimal 信用餘額, string? 幣別,
    string? ParentCorpShortName, string? ParentCorpLongName)
{
    public CustomerCreditCrmRow(CopGetCreditCrm c, string? parentCorpShortName, string? parentCorpLongName)
        : this(c.應收金額, c.未結帳銷貨, c.訂貨出貨通知金額, c.預收金額, c.已出貨抵預收金額,
            c.應收合計金額, c.未出貨訂單總金額, c.未出貨訂單金額比率, c.信用可超出額, c.信用餘額, c.幣別,
            parentCorpShortName, parentCorpLongName)
    {
    }
}

// ---------------------------------------------------------------- 權限控管

/// <summary>人員管理畫面用的帳號設定。1.0 的 GetUserInfo 直接回整個 M_User（含密碼），這裡只回畫面要的欄位。</summary>
public class UserSettingViewModel
{
    public string Account { get; set; } = string.Empty;
    public string UserName { get; set; } = string.Empty;
    public bool IsEnable { get; set; }
    /// <summary>有沒有掛 superAdmin 角色（不再讀 M_User.IsAdmin）。</summary>
    public bool IsAdmin { get; set; }
    public bool IsLocked { get; set; }
    public bool IsFirstLogin { get; set; }
    /// <summary>所屬角色（RBAC_RoleUser），不含自動擁有的 everyone。</summary>
    public List<int> RoleIds { get; set; } = [];
    public DateTime? LastChangePwd { get; set; }
}

/// <summary>角色清單（角色管理左側、人員管理的角色下拉）。</summary>
public class RoleListItemViewModel
{
    public int Id { get; set; }
    public string RoleCode { get; set; } = string.Empty;
    public string RoleName { get; set; } = string.Empty;
    public string? Description { get; set; }
    public bool IsSystem { get; set; }
    public bool IsSuperAdmin { get; set; }
    public bool IsDefault { get; set; }
    public int Sort { get; set; }
    public int PermissionCount { get; set; }
    public int MemberCount { get; set; }
}

/// <summary>單一角色：基本資料 + 權限 + 成員帳號。</summary>
public class RoleDetailViewModel : RoleListItemViewModel
{
    public List<string> PermissionKeys { get; set; } = [];
    public List<string> Members { get; set; } = [];
}

/// <summary>目前登入者的有效權限，前端一次載入後快取（usePermission）。</summary>
public class MyPermissionsViewModel
{
    public bool IsSuperAdmin { get; set; }
    public List<string> Keys { get; set; } = [];
}
