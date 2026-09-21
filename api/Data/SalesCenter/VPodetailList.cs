using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class VPodetailList
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

    public string? 前置單別 { get; set; }

    public string? 前置單號 { get; set; }

    public string? 前置序號 { get; set; }

    public decimal? 前置數量 { get; set; }

    public decimal? 前置單價 { get; set; }

    public string? FinFlag { get; set; }
}
