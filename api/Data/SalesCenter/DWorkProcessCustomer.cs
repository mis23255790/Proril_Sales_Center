using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class DWorkProcessCustomer
{
    public int Id { get; set; }

    public string Wpno { get; set; } = null!;

    public string? CustomerNo { get; set; }

    public string? CustomerType { get; set; }

    public string? AStatus { get; set; }

    public string? Creator { get; set; }

    public DateTime? CreateTime { get; set; }

    public string? Modifier { get; set; }

    public DateTime? ModiTime { get; set; }
}
