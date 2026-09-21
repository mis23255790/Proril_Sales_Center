using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class VCopmoq
{
    public string Erpsource { get; set; } = null!;

    public string? CustomerNo { get; set; }

    public string? ProductNo { get; set; }

    public string? ProductName { get; set; }

    public string Unit { get; set; } = null!;

    public string? CheckDate { get; set; }

    public string Currency { get; set; } = null!;

    public string StartDate { get; set; } = null!;

    public string? EndDate { get; set; }

    public string? StartDateD { get; set; }

    public string? ByQtyFlag { get; set; }

    public string ByQtyCurrency { get; set; } = null!;

    public decimal Qty { get; set; }

    public decimal ByQtyPrice { get; set; }
}
