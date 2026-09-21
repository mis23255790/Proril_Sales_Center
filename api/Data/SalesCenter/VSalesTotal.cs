using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class VSalesTotal
{
    public string? CustomerNo { get; set; }

    public string? Ym { get; set; }

    public decimal? TotalQty { get; set; }

    public decimal? TotalAmt { get; set; }
}
