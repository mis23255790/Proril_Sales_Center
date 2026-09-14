namespace Proril.SalesIssue.Api.Data;

/*
 * 銷貨檢索（1.0 Mix/SalesShipping，MixSalesShipApi）用到的資料表。
 *
 * 只有一張 COP_SalesOrder：它同時是「ERP 銷貨單快取表」與「兩支查詢預存程序的結果集形狀」。
 * prc_QuerySalesOrder / prc_QuerySalesOrder_1 回傳的是內部暫存表 #SalesOrder(_1)，
 * 欄位與 COP_SalesOrder 同名同型（多出 SumQty/SumAmt/FooterFlag 三個統計欄位，
 * 那三個在 COP_SalesOrder 裡本來就有），所以兩支 SP 的 FromSql 都對映到這個型別。
 *
 * 1.0 另外有一個 CopMdlSalesOrder1（對映 COP_MDL_SalesOrder_1）只在匯出時當 SP 結果形狀用，
 * 欄位定義與 CopSalesOrder 逐欄相同，那張表在 DB 裡是 0 筆、也沒有任何 View/SP 參照它。
 * 2.0 不搬那張表也不建那個型別，匯出跟查詢共用 CopSalesOrder。
 */

/// <summary>
/// COP_SalesOrder：ERP 銷貨單明細快取（prc_ImportSalesOrder 從鼎新 ERP 增量匯入），
/// 也是 prc_QuerySalesOrder(_1) 的回傳形狀。
///
/// 欄位名沿用 ERP 的 TH0xx / TG0xx / TA0xx 原名，不做語意改名——對照舊碼與 SP 時
/// 不用再翻譯一層，前端 app/types/salesShipping.ts 也是同一套命名。
/// </summary>
public class CopSalesOrder
{
    public int Id { get; set; }

    /// <summary>ERP 來源：浦瑞ERP / 芳晟ERP。</summary>
    public string? CopSource { get; set; }
    /// <summary>銷貨日期。</summary>
    public string? Tg003 { get; set; }
    /// <summary>銷貨單別。</summary>
    public string Th001 { get; set; } = null!;
    /// <summary>銷貨單號。</summary>
    public string Th002 { get; set; } = null!;
    /// <summary>銷貨序號。</summary>
    public string Th003 { get; set; } = null!;
    /// <summary>品號。</summary>
    public string? Th004 { get; set; }
    /// <summary>品名。</summary>
    public string? Th005 { get; set; }
    /// <summary>規格。</summary>
    public string? Th006 { get; set; }
    /// <summary>單位。</summary>
    public string? Th009 { get; set; }
    /// <summary>倉別。</summary>
    public string? Th007 { get; set; }
    /// <summary>數量（明細列）。</summary>
    public decimal? Th008 { get; set; }
    /// <summary>數量小計（統計列；明細列 SP 也會填成跟 TH008 相同的值）。</summary>
    public decimal? SumQty { get; set; }
    /// <summary>單價。</summary>
    public decimal? Th012 { get; set; }
    /// <summary>數量*單價。</summary>
    public decimal? Th013 { get; set; }
    /// <summary>幣別。</summary>
    public string? Tg011 { get; set; }
    /// <summary>匯率。</summary>
    public decimal? Tg012 { get; set; }
    /// <summary>台幣未稅金額。</summary>
    public decimal? Th037 { get; set; }
    /// <summary>台幣稅額。</summary>
    public decimal? Th038 { get; set; }
    /// <summary>台幣總額（SP 算的 TH037 + TH038 累計）。</summary>
    public decimal? SumAmt { get; set; }
    /// <summary>贈品數量。</summary>
    public decimal? Th024 { get; set; }
    /// <summary>訂單單別。</summary>
    public string? Th014 { get; set; }
    /// <summary>訂單單號。</summary>
    public string? Th015 { get; set; }
    /// <summary>訂單序號。</summary>
    public string? Th016 { get; set; }
    /// <summary>備註。</summary>
    public string? Th018 { get; set; }
    /// <summary>客戶單號。</summary>
    public string? Tc012 { get; set; }
    /// <summary>銘版序號，JSON 字串（來源是 PRORIL_WEB 的 NPS_D_Order）。</summary>
    public string? SerialNosJson { get; set; }
    /// <summary>製令單別。</summary>
    public string? Ta001 { get; set; }
    /// <summary>製令單號。</summary>
    public string? Ta002 { get; set; }
    /// <summary>計劃批號。</summary>
    public string? PlanNumber { get; set; }
    public string? Ta026 { get; set; }
    public string? Ta027 { get; set; }
    public string? Ta028 { get; set; }
    public string? SerialNosJson1 { get; set; }
    public string? Ta0011 { get; set; }
    public string? Ta0021 { get; set; }
    public string? PlanNumber1 { get; set; }

    public string? CustomerNo { get; set; }
    public string? CustomerName { get; set; }
    public string? Memo { get; set; }

    /// <summary>
    /// N = 逐筆明細；Y = 群組小計；S = 群組只有一筆時那筆明細直接升格成小計；T = 總計列。
    /// 細項頁籤取「非 Y」，統計頁籤取「非 N」，兩邊都會吃到 T，這是 1.0 的既有行為。
    /// </summary>
    public string? FooterFlag { get; set; }

    public string? AStatus { get; set; }
    public string? Creator { get; set; }
    public DateTime? CreateTime { get; set; }
    public string? Modifier { get; set; }
    public DateTime? ModiTime { get; set; }
}
