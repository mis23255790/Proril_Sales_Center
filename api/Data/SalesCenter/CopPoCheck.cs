using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class CopPoCheck
{
    public int Id { get; set; }

    public string? OrderChkNo { get; set; }

    public DateTime? ChkTime { get; set; }

    public string? CopSource { get; set; }

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
