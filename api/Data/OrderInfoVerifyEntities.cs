namespace Proril.SalesIssue.Api.Data;

/*
 * 訂單資料檢核（1.0 Mix/OrderInfoVerify）用到的資料表。
 *
 * 這批表跟 Entities.cs 的業務議題表無關，開獨立檔案。命名沿用英文駝峰
 * （不照抄 1.0 scaffold 的 VPolist / CopDepDatum 這種怪名字），實際 DB 對映
 * 在 SalesIssueDbContext.OnModelCreating 裡用 Fluent API 明確指定，
 * 欄位名稱大小寫務必跟 DB 一致（collation 是 case-sensitive）。
 */

/// <summary>V_POList：訂單主檔 View。</summary>
public class VPoList
{
    public string CopSource { get; set; } = null!;
    public string? 單別名稱 { get; set; }
    public string 單別 { get; set; } = null!;
    public string 單號 { get; set; } = null!;
    public string? 訂單日期 { get; set; }
    public string? 價格條件 { get; set; }
    /// <summary>1.0 這個欄位其實不是日期，是旗標字元。</summary>
    public string 預交日 { get; set; } = null!;
    public string? 客戶代號 { get; set; }
    public string 客戶名稱 { get; set; } = null!;
    public string 部門代號 { get; set; } = null!;
    public string? 業務人員 { get; set; }
    public string 業務名稱 { get; set; } = null!;
    public string? 送貨地址一 { get; set; }
    public string? 送貨地址二 { get; set; }
    public string? 付款條件 { get; set; }
    public string? 課稅別 { get; set; }
    public string? 運輸方式 { get; set; }
    public string? 幣別 { get; set; }
    public decimal? 匯率 { get; set; }
    public decimal? 訂單金額 { get; set; }
    public decimal? 總數量 { get; set; }
    public string? Packinglist備註 { get; set; }
    public string? 客戶單號 { get; set; }
    public string? 交易條件 { get; set; }
    public string 交易條件名稱 { get; set; } = null!;
    public string? 起始港口 { get; set; }
    public string? 目的港口 { get; set; }
    public string? 連絡人 { get; set; }
    public string? TelNo { get; set; }
    public string? FaxNo { get; set; }
    /// <summary>1.0 這個欄位其實是旗標字元，實際附件檔名要靠 V_UpFileData join。</summary>
    public string 附件檔案 { get; set; } = null!;
    public string 付款檢核 { get; set; } = null!;
    public string? 流程代號 { get; set; }
    public string? FinFlag { get; set; }
    public string ConfirmFlag { get; set; } = null!;
}

/// <summary>V_PODetailList：訂單明細 View。</summary>
public class VPoDetailList
{
    public string CopSource { get; set; } = null!;
    public string 單別 { get; set; } = null!;
    public string 單號 { get; set; } = null!;
    public string 序號 { get; set; } = null!;
    public string? 品號 { get; set; }
    public string? 品名 { get; set; }
    public string? 規格 { get; set; }
    public string? 英文品名 { get; set; }
    public string? 英文規格 { get; set; }
    public string? 幣別 { get; set; }
    public decimal? 匯率 { get; set; }
    public decimal? 訂單數量 { get; set; }
    public string? 單位 { get; set; }
    public decimal? 外幣單價 { get; set; }
    public decimal? 外幣金額 { get; set; }
    public decimal? 台幣金額 { get; set; }
    public string? 預交日 { get; set; }
    public string? FinFlag { get; set; }
}

/// <summary>COP_PoCheck：訂單檢核表頭，prc_COPOrderChk 執行後寫回這張表。</summary>
public class CopPoCheck
{
    public int Id { get; set; }
    public string? OrderChkNo { get; set; }
    public DateTime? ChkTime { get; set; }
    public string? CopSource { get; set; }
    /// <summary>"{單別}-{單號}"。</summary>
    public string? PoNo { get; set; }
    public decimal? SumAmt { get; set; }
    public decimal? SumQty { get; set; }
    public decimal? CustAmt { get; set; }
    public decimal? AvailableAmt { get; set; }
    public string? DepChk { get; set; }
    public string? DepBlankChk { get; set; }
    public string? PackListBlankChk { get; set; }
    public string? PriceBlankChk { get; set; }
    public string? PreDateChk { get; set; }
    public string? CustSumAmtChk { get; set; }
    public string? CustAmtZeroChk { get; set; }
    public string? CustPochk { get; set; }
    public string? TransChk { get; set; }
    public string? TradeChk { get; set; }
    public string? OutPortChk { get; set; }
    public string? InPortChk { get; set; }
    public string? UpFileChk { get; set; }
    public string? DetailChk { get; set; }
    public string? RateChk { get; set; }
    public string? PaidChk { get; set; }
    public string? AvailableChk { get; set; }
    public string? Credit30Wchk { get; set; }
    public string? ProcessCodeChk { get; set; }
    public string? FinChk { get; set; }
    public string? Memo { get; set; }
    public string? AStatus { get; set; }
    public string? Creator { get; set; }
    public DateTime? CreateTime { get; set; }
    public string? Modifier { get; set; }
    public DateTime? ModiTime { get; set; }
}

/// <summary>COP_PoDetailCheck：訂單檢核明細（逐品號一列）。</summary>
public class CopPoDetailCheck
{
    public int Id { get; set; }
    public string? OrderChkNo { get; set; }
    public DateTime? ChkTime { get; set; }
    public string? CopSource { get; set; }
    public string? PoNo { get; set; }
    public string? Sno { get; set; }
    public string? ProductNo { get; set; }
    public string? ProductNoChk { get; set; }
    public string? QtyChk { get; set; }
    public string? AmtChk { get; set; }
    public string? PriceChk { get; set; }
    public string? PackListChk { get; set; }
    public string? LinkTypeChk { get; set; }
    public string? LinkNoChk { get; set; }
    public string? LinkSnoChk { get; set; }
    public string? LinkQtyChk { get; set; }
    public string? LinkPriceChk { get; set; }
    public string? LinkChk { get; set; }
    public string? MoqamtChk { get; set; }
    public string? LinkMoqamtChk { get; set; }
    public string? FinChk { get; set; }
    public string? Memo { get; set; }
    public string? AStatus { get; set; }
    public string? Creator { get; set; }
    public DateTime? CreateTime { get; set; }
    public string? Modifier { get; set; }
    public DateTime? ModiTime { get; set; }
}

/// <summary>COP_CheckRule：檢核規則說明表，「檢核條件」畫面就是列這張表。</summary>
public class CopCheckRule
{
    public int Id { get; set; }
    public string? RecType { get; set; }
    public string? ChkField { get; set; }
    public string? Erpfield { get; set; }
    public string? ChkRule { get; set; }
    public string? ChkLevel { get; set; }
    public string? PassFlag { get; set; }
    public string? Memo { get; set; }
    public string? AStatus { get; set; }
    public string? Creator { get; set; }
    public DateTime? CreateTime { get; set; }
    public string? Modifier { get; set; }
    public DateTime? ModiTime { get; set; }
}

/// <summary>
/// COP_PassCheck：特規 Pass 紀錄。1.0 沒有 Executor 欄位，執行人記錄沿用 Creator。
/// </summary>
public class CopPassCheck
{
    public int Id { get; set; }
    public string? OrderChkNo { get; set; }
    public string? Sno { get; set; }
    public DateTime? PassTime { get; set; }
    /// <summary>要 Pass 的檢核項目名稱，例如 "CustSumAmtChk"。</summary>
    public string? PassItems { get; set; }
    public string? PassMemo { get; set; }
    public string? Memo { get; set; }
    public string? AStatus { get; set; }
    public string? Creator { get; set; }
    public DateTime? CreateTime { get; set; }
    public string? Modifier { get; set; }
    public DateTime? ModiTime { get; set; }
}

/// <summary>V_Product_English_All：英文品名 View。</summary>
public class VProductEnglishAll
{
    public string? ProductNo { get; set; }
    public string? ProductName { get; set; }
    public string? Specification { get; set; }
    public string? ProductNameE { get; set; }
    public string? SpecificationE { get; set; }
}

/// <summary>COP_DepData：部門資料，訂單表頭的部門代號要靠這張表換部門名稱。</summary>
public class CopDepData
{
    public int Id { get; set; }
    public string? OrderType { get; set; }
    public string? OrderName { get; set; }
    public string? OrderNameAll { get; set; }
    public string? DepNo { get; set; }
    public string? DepName { get; set; }
    public string? AStatus { get; set; }
    public string? Creator { get; set; }
    public DateTime? CreateTime { get; set; }
    public string? Modifier { get; set; }
    public DateTime? ModiTime { get; set; }
}

/// <summary>V_UpFileData：附件檔案 View，用 "{單別}-{單號}" 對到 KeyValues 找檔名。</summary>
public class VUpFileData
{
    public string Parent { get; set; } = null!;
    public string? KeyValues { get; set; }
    public string CompanyId { get; set; } = null!;
    public string UserId { get; set; } = null!;
    public string? Type { get; set; }
    public string SeqNo { get; set; } = null!;
    public string? FileName { get; set; }
    public string? DocId { get; set; }
    public string? Revision { get; set; }
    public string? AddDate { get; set; }
    public string? AddTime { get; set; }
    public string? KeyFields { get; set; }
}

/// <summary>
/// prc_COPGetCredit 的查詢結果形狀（keyless，只給 FromSqlInterpolated 用）。
///
/// 與 1.0 的差異：1.0 的 model 這裡宣告 <c>float</c>，但 SP 實際回傳的欄位是
/// SQL <c>decimal/numeric</c>，EF Core 8 對不上型別會直接丟
/// <c>InvalidCastException</c>（1.0 用的是舊版 EF Core，型別轉換比較寬鬆）。
/// 這裡改宣告 <c>decimal</c> 對齊實際回傳型別。
/// </summary>
public class CopGetCredit
{
    public decimal 應收金額 { get; set; }
    public decimal 未結帳銷貨 { get; set; }
    public decimal 訂貨出貨通知金額 { get; set; }
    public decimal 預收金額 { get; set; }
    public decimal 已出貨抵預收金額 { get; set; }
    public decimal 應收合計金額 { get; set; }
    public decimal 未出貨訂單總金額 { get; set; }
    public decimal 未出貨訂單金額比率 { get; set; }
    public decimal 信用可超出額 { get; set; }
    public decimal 信用餘額 { get; set; }
}

/// <summary>prc_COPGetCredit_CRM 的查詢結果形狀，比 <see cref="CopGetCredit"/> 多幣別欄位。</summary>
public class CopGetCreditCrm
{
    public decimal 應收金額 { get; set; }
    public decimal 未結帳銷貨 { get; set; }
    public decimal 訂貨出貨通知金額 { get; set; }
    public decimal 預收金額 { get; set; }
    public decimal 已出貨抵預收金額 { get; set; }
    public decimal 應收合計金額 { get; set; }
    public decimal 未出貨訂單總金額 { get; set; }
    public decimal 未出貨訂單金額比率 { get; set; }
    public decimal 信用可超出額 { get; set; }
    public decimal 信用餘額 { get; set; }
    public string? 幣別 { get; set; }
}
