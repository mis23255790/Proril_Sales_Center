using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class DWorkProcessSearch
{
    public int Id { get; set; }

    public string Wpno { get; set; } = null!;

    public string? PhraseType { get; set; }

    public string? PhraseCode { get; set; }

    public string? AStatus { get; set; }

    public string? Creator { get; set; }

    public DateTime? CreateTime { get; set; }

    public string? Modifier { get; set; }

    public DateTime? ModiTime { get; set; }
}
