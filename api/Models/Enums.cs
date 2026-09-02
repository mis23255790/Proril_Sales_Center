namespace Proril.SalesIssue.Api.Models;

/// <summary>
/// M_WorkProcessType.TypeCode。畫面上的「類別」是 02。
/// 值是字串，因為 DB 存的是 '01' / '02' / '03' 這種補零字串。
/// </summary>
public static class PhraseTypeCode
{
    /// <summary>01 搜尋片語。</summary>
    public const string Phrase = "01";
    /// <summary>02 流程類別 → 畫面上的「類別」。</summary>
    public const string Category = "02";
    /// <summary>03 職能主題 → 舊版的「客戶別」，改成客戶導向後由 CRM_Customer 取代。</summary>
    public const string Job = "03";
}

/// <summary>D_WorkProcessPermission.EnableType。</summary>
public enum EWorkProcessPermission
{
    NotDefined = 0,
    View = 1,
    Edit = 10,
    Public = 20
}

/// <summary>M_Permission.FunctionNo。這裡只需要業務議題那一個。</summary>
public static class FunctionIds
{
    /// <summary>流程維護（1.0 的 FunctionId.ProcessMaintain）。上傳 log 也用這個號。</summary>
    public const int ProcessMaintain = 17;
}

public static class PermissionConst
{
    /// <summary>保留帳號：代表「全體使用者」。少了它，新建的議題只有建立者看得到。</summary>
    public const string AccountForAll = "000000";
}

public static class CustomerTypeConst
{
    /// <summary>D_WorkProcessCustomer.CustomerType，1.0 寫入的是這個字串。</summary>
    public const string Primary = "Primary";
}

public static class ActiveStatus
{
    public const string Active = "Y";
    /// <summary>已失效／已不在集合裡。**不是**「已完成」。</summary>
    public const string Inactive = "N";
}
