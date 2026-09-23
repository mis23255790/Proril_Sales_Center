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

/// <summary>
/// M_Permission.FunctionNo / M_Function.FunctionNo。
///
/// 格式是 <c>AAABBCC</c>（SystemNo 3 碼 + GroupNo 2 碼 + 序號 2 碼），varchar(8)，
/// 定長所以字串排序就等於「系統別 → 群組 → 序號」。
/// **只有 Proril_Sales_Center 是這個格式**；PRORIL_WEB（1.0 在用）仍是 int 流水號，
/// 兩邊永久分岔，見 database/FunctionNoFormatMigration.sql。
/// </summary>
public static class FunctionIds
{
    /// <summary>權限管理（舊 1）。</summary>
    public const string PermissionManager = "0000101";

    /// <summary>人員管理（舊 8）。</summary>
    public const string UserManager = "0000102";

    /// <summary>類別維護（舊 16）。</summary>
    public const string KindMaintain = "0070101";

    /// <summary>議題維護（舊 17，1.0 的 ProcessMaintain）。上傳 log 也用這個號。</summary>
    public const string ProcessMaintain = "0070102";

    /// <summary>銷貨檢索（舊 410，1.0 的 MixSalesShipping）。</summary>
    public const string MixSalesShipping = "0320101";

    /// <summary>未完成訂單檢索（舊 420，1.0 的 QueryUnFinish）。</summary>
    public const string QueryUnFinish = "0320102";

    /// <summary>客戶維護（舊 440，1.0 的 CustomQuery）。</summary>
    public const string CustomQuery = "0320103";

    /// <summary>
    /// 訂單資料檢核（舊 425）。
    /// 1.0 enum 註解寫「訂單資料查核」，但畫面標題與 JS top-title 顯示的是「訂單資料檢核」，
    /// 2.0 沿用畫面上實際看到的字樣。
    /// </summary>
    public const string OrderInfoVerify = "0320201";

    /// <summary>群組權限（2.0 新增，群組預設功能從權限管理獨立出來，PRORIL_WEB 沒有這個功能）。</summary>
    public const string GroupPermission = "0000103";
}

/// <summary>
/// 字串權限 `module.function.action`（M_PermissionDef.PermissionKey），
/// 取代「FunctionNo + LinkType 數字」的判斷。`.view` = 進得去這個功能，其餘是細項。
/// 前端對照在 app/utils/permissionKeys.ts，資料在 database/PermissionDefObjectsMigration.sql，
/// **三邊要一起改**。
/// </summary>
public static class PermissionKeys
{
    // 不叫 System，免得在這個類別裡蓋掉 System 命名空間
    public static class SystemSetting
    {
        public const string PermissionManagerView = "system.permissionManager.view";
        public const string UserManagerView = "system.userManager.view";
        public const string GroupPermissionView = "system.groupPermission.view";
    }

    public static class SalesIssue
    {
        public const string KindMaintainView = "salesIssue.kindMaintain.view";
        public const string ProcessMaintainView = "salesIssue.processMaintain.view";
        public const string ProcessMaintainCreateSop = "salesIssue.processMaintain.createSop";
        public const string ProcessMaintainPublishSop = "salesIssue.processMaintain.publishSop";
    }

    public static class SalesSearch
    {
        public const string MixSalesShippingView = "salesSearch.mixSalesShipping.view";
        public const string MixSalesShippingViewAmount = "salesSearch.mixSalesShipping.viewAmount";
        public const string QueryUnFinishView = "salesSearch.queryUnFinish.view";
        public const string QueryUnFinishViewAmount = "salesSearch.queryUnFinish.viewAmount";
        public const string CustomQueryView = "salesSearch.customQuery.view";
        public const string OrderInfoVerifyView = "salesSearch.orderInfoVerify.view";
        public const string OrderInfoVerifyViewAmount = "salesSearch.orderInfoVerify.viewAmount";
    }
}

/// <summary>M_PermissionGroup.GroupType。</summary>
public static class PermissionGroupType
{
    /// <summary>部門預設功能。1.0 MainApiController._default_group_type = 10。</summary>
    public const int Department = 10;
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
