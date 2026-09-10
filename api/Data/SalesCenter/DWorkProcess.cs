using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class DWorkProcess
{
    public int Id { get; set; }

    public string Wpno { get; set; } = null!;

    public string? SopTitle { get; set; }

    public string? Descript { get; set; }

    public string PhraseList { get; set; } = null!;

    public string? VerNo { get; set; }

    public DateTime? PubDate { get; set; }

    public bool? PubFlag { get; set; }

    public bool? FinFlag { get; set; }

    public int? ProgressStatus { get; set; }

    public string? AStatus { get; set; }

    public string? Creator { get; set; }

    public string? Leader { get; set; }

    public string? Authorize { get; set; }

    public string? Modifier { get; set; }

    public DateTime? CreateTime { get; set; }

    public DateTime? ModiTime { get; set; }
}
