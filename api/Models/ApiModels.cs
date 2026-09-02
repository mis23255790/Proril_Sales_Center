using Proril.SalesIssue.Api.Data;

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

/// <summary>
/// 議題列表／表頭的回傳形狀（1.0 的 DWorkProcessesEx）。
///
/// 除了 D_WorkProcess 本身，還帶了一堆 join 出來的顯示欄位。
/// PhraseTypeList / PhraseCodeList / PhraseNameList 是三串分號字串，
/// **靠索引對齊**，不是 key-value —— 任何一串被過濾或排序，對應關係就整個錯開。
/// </summary>
public class DWorkProcessesEx : DWorkProcess
{
    public DWorkProcessesEx() { }

    public DWorkProcessesEx(DWorkProcess source)
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
public class DWorkProcessDetailViewModel : DWorkProcessDetail
{
    public DWorkProcessDetailViewModel(DWorkProcessDetail src) : base(src) { }

    public string? CreatorName { get; set; }
    public string? ModifierName { get; set; }
}

/// <summary>議題掛的關鍵字 + 關鍵字名稱。</summary>
public class DWorkProcessSearchEx : DWorkProcessSearch
{
    public DWorkProcessSearchEx(DWorkProcessSearch src) : base(src) { }

    public string? PhraseName { get; set; }
}

/// <summary>議題掛的客戶 + 客戶顯示資料。</summary>
public class DWorkProcessCustomerEx : DWorkProcessCustomer
{
    public DWorkProcessCustomerEx(DWorkProcessCustomer src) : base(src) { }

    public string ShortName { get; set; } = string.Empty;
    public string LongName { get; set; } = string.Empty;
    public string ContactName { get; set; } = string.Empty;
    public string ContactTEL1 { get; set; } = string.Empty;
}

/// <summary>客戶主檔 + ERP 端名稱。</summary>
public class CrmCustomerViewModel : CrmCustomer
{
    public CrmCustomerViewModel(CrmCustomer src) : base(src) { }

    public string ERPCustomShortName { get; set; } = string.Empty;
    public string ERPCustomLongName { get; set; } = string.Empty;
}
