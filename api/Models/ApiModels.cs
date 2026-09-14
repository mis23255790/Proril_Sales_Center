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

// ---------------------------------------------------------------- 權限控管

/// <summary>
/// 權限樹存檔時，前端回傳的「功能底下的細項權限」。
/// 欄位名（含 <c>PermissionLinkTypeID</c> 的大寫 ID）沿用 1.0 的 <c>Ret_LinkType</c>，
/// 因為前端送的是同一包 JSON 字串，改名就對不上。
/// <c>LinkType</c> 是字串也是 1.0 的原樣——前端從 DOM 取值時沒轉型，後端再 TryParse。
/// </summary>
public class RetLinkType
{
    public string FunctionNo { get; set; } = string.Empty;
    public string? LinkType { get; set; }
    public int PermissionLinkTypeID { get; set; }
}

/// <summary>人員管理畫面用的帳號設定。1.0 的 GetUserInfo 直接回整個 M_User（含密碼），這裡只回畫面要的欄位。</summary>
public class UserSettingViewModel
{
    public string Account { get; set; } = string.Empty;
    public string UserName { get; set; } = string.Empty;
    public bool IsEnable { get; set; }
    public bool IsAdmin { get; set; }
    public bool IsLocked { get; set; }
    public bool IsFirstLogin { get; set; }
    public DateTime? LastChangePwd { get; set; }
}

/// <summary>群組預設功能（M_PermissionGroup）+ 對照出來的功能／細項名稱。比照 1.0 的 MPermissionGroupVM。</summary>
public class PermissionGroupViewModel
{
    public int Id { get; set; }
    public string? GroupNo { get; set; }
    public string? FunctionNo { get; set; }
    public byte? LinkType { get; set; }
    public string FunctionName { get; set; } = string.Empty;
    public string LinkTypeName { get; set; } = string.Empty;
}

/// <summary>側欄用：目前登入者可以進入的功能（M_Function + 所屬 M_System）。</summary>
public class UserFunctionViewModel
{
    public int SystemNo { get; set; }
    public string SystemName { get; set; } = string.Empty;
    public int SystemType { get; set; }
    public string? TypeName { get; set; }
    public int SystemSort { get; set; }
    public string FunctionNo { get; set; } = string.Empty;
    public string FunctionName { get; set; } = string.Empty;
    public int? GroupNo { get; set; }
    public string? GroupName { get; set; }
}
