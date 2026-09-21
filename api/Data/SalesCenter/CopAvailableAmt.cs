using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class CopAvailableAmt
{
    public int Id { get; set; }

    public string? CustNo { get; set; }

    public string? OrderChkNo { get; set; }

    public decimal? NotifyAmt { get; set; }

    public decimal? OrderAmt { get; set; }

    public decimal? OrderAmtRate { get; set; }

    public decimal? ReceivableSumAmt { get; set; }

    public decimal? ReceivableAmt { get; set; }

    public decimal? GainAmt { get; set; }

    public decimal? UnbilledAmt { get; set; }

    public decimal? PreGainAmt { get; set; }

    public decimal? AvailableAmt { get; set; }

    public decimal? AvailableSetAmt { get; set; }

    public string? Memo { get; set; }

    public string? AStatus { get; set; }

    public string? Creator { get; set; }

    public DateTime? CreateTime { get; set; }

    public string? Modifier { get; set; }

    public DateTime? ModiTime { get; set; }
}
