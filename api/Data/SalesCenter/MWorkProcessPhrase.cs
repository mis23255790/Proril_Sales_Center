using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class MWorkProcessPhrase
{
    public int Id { get; set; }

    public string PhraseType { get; set; } = null!;

    public string PhraseCode { get; set; } = null!;

    public string PhraseName { get; set; } = null!;

    public string? Directions { get; set; }

    public bool? PubFlag { get; set; }

    public string? Principal { get; set; }

    public string? PotentialCustom { get; set; }

    public string? AStatus { get; set; }

    public string? Creator { get; set; }

    public DateTime? CreateTime { get; set; }
}
