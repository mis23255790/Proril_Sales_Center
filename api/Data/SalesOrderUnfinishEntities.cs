namespace Proril.SalesIssue.Api.Data;

/*
 * 未完成訂單檢索（1.0 Mix/QueryUnFinish，SalesOrderUnFinishApi）用到的型別。
 *
 * 只有一個 UnfinOrder：對映 1.0 的 SalesOrderViewModel，是 prc_QueryUnfinOrder /
 * prc_QueryUnfinOrder_1 的查詢結果形狀（FromSql 專用，不對應任何實體表或 View，
 * 這兩支 SP 在 repo 內也找不到對應 .sql，只存在資料庫端，見
 * docs/modules/SalesOrderUnfinish/logic.md）。
 *
 * 跟銷貨檢索是不同資料表/不同 ViewModel（訂單 vs 銷貨單），刻意不共用
 * CopSalesOrder（SalesShippingEntities.cs），避免兩個模組互相牽動。
 */

/// <summary>
/// SalesOrderViewModel：prc_QueryUnfinOrder（依品號 TD004 分群）/
/// prc_QueryUnfinOrder_1（依訂單 TC001+TC002 分群）的回傳形狀。
///
/// 欄位名沿用 1.0 的 Tc0xx/Td0xx 原名（ERP 直接對應的泛用命名），不做語意改名——
/// 對照舊碼／SQL 時不用再翻譯一層，前端 app/types/salesOrderUnfinish.ts 也是同一套命名。
/// 唯一例外是 <see cref="CopSource"/>：1.0 叫 <c>COPSource</c>，這裡改成一般 PascalCase
/// 讓 camelCase 化後是 <c>copSource</c>（跟銷貨檢索 <c>CopSalesOrder.CopSource</c> 一致），
/// 不是 <c>cOPSource</c>。實際欄名（SP 回傳的欄位）是 <c>COP_Source</c>，
/// 在 <c>ProrilWebDbContext.OnModelCreating</c> 用 <c>HasColumnName</c> 對映。
/// </summary>
public class UnfinOrder
{
    public int Id { get; set; }

    /// <summary>ERP 來源。</summary>
    public string? CopSource { get; set; }
    /// <summary>單別名稱。</summary>
    public string? Mq002 { get; set; }
    /// <summary>訂單單別。</summary>
    public string? Tc001 { get; set; }
    /// <summary>訂單單號。</summary>
    public string? Tc002 { get; set; }
    /// <summary>訂單序號。</summary>
    public string Td003 { get; set; } = null!;
    /// <summary>訂單日期。</summary>
    public string Tc003 { get; set; } = null!;
    /// <summary>客戶代號。</summary>
    public string? Tc004 { get; set; }
    /// <summary>客戶名稱。</summary>
    public string? Ma002 { get; set; }
    /// <summary>業務人員代號。</summary>
    public string? Tc006 { get; set; }
    /// <summary>業務人員名稱。</summary>
    public string? Mv002 { get; set; }
    /// <summary>送貨地址。</summary>
    public string? Tc010 { get; set; }
    /// <summary>付款條件。</summary>
    public string? Tc014 { get; set; }
    /// <summary>課稅別。</summary>
    public string? Tc016 { get; set; }
    /// <summary>運輸方式。</summary>
    public string? Tc019 { get; set; }
    /// <summary>品號。</summary>
    public string? Td004 { get; set; }
    /// <summary>品名。</summary>
    public string? Td005 { get; set; }
    /// <summary>規格。</summary>
    public string? Td006 { get; set; }
    /// <summary>訂單數量。</summary>
    public decimal? Td008 { get; set; }
    /// <summary>單位。</summary>
    public string? Td010 { get; set; }
    /// <summary>原幣單價。</summary>
    public decimal? Td011 { get; set; }
    /// <summary>原幣金額。</summary>
    public decimal? Td012 { get; set; }
    /// <summary>幣別。</summary>
    public string? Tc008 { get; set; }
    /// <summary>匯率。</summary>
    public decimal? Tc009 { get; set; }
    /// <summary>台幣金額。</summary>
    public decimal? Ntd { get; set; }
    /// <summary>預交日。</summary>
    public string? Td013 { get; set; }
    /// <summary>贈品量（只有訂單細項頁籤用到）。</summary>
    public decimal? Td024 { get; set; }
    /// <summary>計畫批號。</summary>
    public string? PlanNumber { get; set; }
    /// <summary>銘版序號，JSON 字串。</summary>
    public string? SerialNosJson { get; set; }

    /// <summary>
    /// N = 逐筆明細；Y = 群組小計；S = 群組只有一筆時那筆明細直接升格成小計；T = 總計列。
    /// 細項頁籤取「非 Y」，統計頁籤取「非 N」，兩邊都會吃到 T，這是 1.0 的既有行為，
    /// 跟銷貨檢索的 CopSalesOrder.FooterFlag 語意相同。
    /// </summary>
    public string? FooterFlag { get; set; }
}
