namespace Proril.SalesIssue.Api.Data;

/*
 * 客戶相關資訊（1.0 Mix/CustomerRelated）的「銷售」與「訂單」兩個頁籤讀的兩個唯讀 View。
 *
 * 兩個都在 Proril_Sales_Center，對映註冊在 SalesCenterDbContext.OnModelCreating 的
 * 手寫區塊（跟 UnfinOrder 同一區）——scaffold-sales-center.ps1 只掃 TABLES.txt 的資料表，
 * 不會產生 View 的對映，所以這兩個型別放在這裡、不要放進 api/Data/SalesCenter/，
 * 免得看起來像 scaffold 產物而被下一次 --force 覆蓋時誤刪。
 *
 * 「情報」頁籤的 CRM_CustomerMemo 是一般資料表，走 scaffold，在 api/Data/SalesCenter/。
 */

/// <summary>
/// V_SalesTotal：客戶的年／月銷售統計，唯讀（HasNoKey）。
///
/// 只 GROUP BY 本地的 COP_SalesOrder，不碰 ERP linked server。
/// <see cref="Ym"/> 長度 4 = 年度總計、長度 6 = 該年某月，**同一支查詢兩種列混在一起**，
/// 由呼叫端依長度分流（1.0 customer-related.js 就是這樣判的）。
///
/// <see cref="CustomerNo"/> 這個欄名會騙人：存的是 **ERP 客戶代號**（COP_SalesOrder.CustomerNo
/// 來自 ERP），不是內網客戶代號，所以要拿 erpCustomerNo 去比對。
/// </summary>
public class VSalesTotal
{
    /// <summary>ERP 客戶代號（不是內網客戶代號，見型別說明）。</summary>
    public string? CustomerNo { get; set; }

    /// <summary>西元年（4 碼，年度總計）或西元年月（6 碼，單月）。</summary>
    public string? Ym { get; set; }

    public decimal? TotalQty { get; set; }

    public decimal? TotalAmt { get; set; }
}

/// <summary>
/// V_UnfinOrder：未完成訂單明細 View，唯讀（HasNoKey）。
///
/// 跟 <see cref="UnfinOrder"/>（prc_QueryUnfinOrder(_1) 的結果形狀）欄位幾乎相同，
/// 但**刻意不共用型別**：那個型別多一個 SP 才有的 <c>ID</c> 欄位，而且已經註冊成
/// keyless 的 SP 結果集，同一個型別在 EF Core 裡不能同時對映到 View 與 FromSql 結果。
///
/// 未完成訂單檢索那一頁走的是 SP（會分群、算小計），這裡走的是原始 View
/// （逐筆明細，分群由前端做），兩條路徑本來就不同，見 docs/modules/Customer/logic.md。
/// </summary>
public class VUnfinOrder
{
    /// <summary>ERP 來源。</summary>
    public string? CopSource { get; set; }
    /// <summary>單別名稱。</summary>
    public string? Mq002 { get; set; }
    /// <summary>訂單單別。</summary>
    public string? Tc001 { get; set; }
    /// <summary>訂單單號。</summary>
    public string? Tc002 { get; set; }
    /// <summary>訂單序號。</summary>
    public string? Td003 { get; set; }
    /// <summary>訂單日期。</summary>
    public string? Tc003 { get; set; }
    /// <summary>客戶代號（ERP）。</summary>
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
    /// <summary>品號。開頭 5 = 成品、x = 零件，前端就是靠這個分成兩組金額。</summary>
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
    /// <summary>台幣金額（View 算好的 TC009 * TD012）。</summary>
    public decimal? Ntd { get; set; }
    /// <summary>預交日。</summary>
    public string? Td013 { get; set; }
    /// <summary>贈品量。</summary>
    public decimal? Td024 { get; set; }
    /// <summary>計畫批號。</summary>
    public string? PlanNumber { get; set; }
    /// <summary>銘版序號，JSON 字串。</summary>
    public string? SerialNosJson { get; set; }
    /// <summary>View 固定給 'N'（逐筆明細），沒有小計列。</summary>
    public string? FooterFlag { get; set; }
}
