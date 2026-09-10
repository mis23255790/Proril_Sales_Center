using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class HFileLink
{
    public int Id { get; set; }

    public string? FilePath { get; set; }

    public string? FileType { get; set; }

    public int LinkFunctionNo { get; set; }

    public string LinkNo { get; set; } = null!;

    public DateTime UpdateTime { get; set; }

    public string UpdateUser { get; set; } = null!;
}
