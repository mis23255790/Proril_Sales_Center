using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class CopCheckRule
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

    public int? TestDacPak { get; set; }
}
