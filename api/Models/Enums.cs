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

    // 0000103 群組權限已隨角色制停用（M_Function.aStatus = 'N'），號碼保留不再使用。
}

/// <summary>
/// 權限樹節點的 PermissionKey（RBAC_Permission，單一樹自我參照）。
/// 頁面節點 = `module.function`（勾了就進得去那個頁面），細項 = `module.function.action`。
/// 前端對照在 app/utils/permissionKeys.ts，資料在 database/RbacObjectsMigration.sql，
/// **三邊要一起改**。整支 Controller 用 <c>[RequirePermission(頁面 key)]</c> 把關。
/// </summary>
public static class PermissionKeys
{
    // 不叫 System，免得在這個類別裡蓋掉 System 命名空間
    public static class SystemSetting
    {
        public const string PermissionManager = "system.permissionManager";
        public const string UserManager = "system.userManager";
        // system.groupPermission 已隨角色制停用（RBAC_Permission.aStatus = 'N'），key 保留不再使用。
    }

    public static class SalesIssue
    {
        public const string KindMaintain = "salesIssue.kindMaintain";
        public const string ProcessMaintain = "salesIssue.processMaintain";
        public const string ProcessMaintainCreateSop = "salesIssue.processMaintain.createSop";
        public const string ProcessMaintainPublishSop = "salesIssue.processMaintain.publishSop";
    }

    public static class SalesSearch
    {
        public const string MixSalesShipping = "salesSearch.mixSalesShipping";
        public const string MixSalesShippingViewAmount = "salesSearch.mixSalesShipping.viewAmount";
        public const string QueryUnFinish = "salesSearch.queryUnFinish";
        public const string QueryUnFinishViewAmount = "salesSearch.queryUnFinish.viewAmount";
        public const string CustomQuery = "salesSearch.customQuery";
        public const string OrderInfoVerify = "salesSearch.orderInfoVerify";
        public const string OrderInfoVerifyViewAmount = "salesSearch.orderInfoVerify.viewAmount";
    }
}

/// <summary>RBAC_Permission.NodeType（資料庫有 CHECK 約束，只能這四種）。</summary>
public static class PermissionNodeType
{
    /// <summary>模組：側欄第一層，有 Path（模組首頁）。</summary>
    public const string Module = "MODULE";
    /// <summary>模組內的分組：側欄第二層的標題，不是頁面、沒有 Path。</summary>
    public const string Group = "GROUP";
    /// <summary>頁面：有 Path，勾了就進得去。</summary>
    public const string Page = "PAGE";
    /// <summary>頁面內的細項，例如顯示金額欄位。</summary>
    public const string Action = "ACTION";
}

/// <summary>
/// 系統角色的 RBAC_Role.RoleCode（database/RbacObjectsMigration.sql 建的兩個，IsSystem = 1）。
/// 判斷一律看 IsSuperAdmin / IsDefault 旗標，這裡的常數只給「指派時要特別擋」的地方用。
/// </summary>
public static class RoleCodes
{
    /// <summary>系統管理員：全放行。只有 superAdmin 自己能指派／移除這個角色。</summary>
    public const string SuperAdmin = "superAdmin";

    /// <summary>全體使用者：所有啟用帳號自動擁有，不能設成員。</summary>
    public const string Everyone = "everyone";
}

public static class PermissionConst
{
    /// <summary>
    /// 保留帳號：代表「全體使用者」。少了它，新建的議題只有建立者看得到。
    /// 現在只剩 D_WorkProcessPermission（議題個別權限）在用；功能權限的「全體」改成 everyone 角色。
    /// </summary>
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
