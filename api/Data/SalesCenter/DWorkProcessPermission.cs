using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class DWorkProcessPermission
{
    public int Id { get; set; }

    public string Wpno { get; set; } = null!;

    public byte EnableType { get; set; }

    public string Account { get; set; } = null!;

    public string? Creator { get; set; }

    public DateTime? CreateTime { get; set; }

    public string? Modifier { get; set; }

    public DateTime? ModiTime { get; set; }
}
