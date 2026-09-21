using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class MSystem
{
    public int Id { get; set; }

    public int SystemNo { get; set; }

    public string SystemName { get; set; } = null!;

    public int SystemType { get; set; }

    public string? TypeName { get; set; }

    public int Sort { get; set; }

    public string? ImagePath { get; set; }

    public string Href { get; set; } = null!;

    public string? RedirectHref { get; set; }
}
