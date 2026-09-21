using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class VPolist
{
    public string CopSource { get; set; } = null!;

    public string? 單別名稱 { get; set; }

    public string 單別 { get; set; } = null!;

    public string 單號 { get; set; } = null!;

    public string? 訂單日期 { get; set; }

    public string? 價格條件 { get; set; }

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

    public string 附件檔案 { get; set; } = null!;

    public string 付款檢核 { get; set; } = null!;

    public string? 流程代號 { get; set; }

    public string? FinFlag { get; set; }

    public string ConfirmFlag { get; set; } = null!;
}
