using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class CopDepDatum
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
