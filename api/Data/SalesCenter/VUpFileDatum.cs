using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class VUpFileDatum
{
    public string Parent { get; set; } = null!;

    public string? KeyValues { get; set; }

    public string CompanyId { get; set; } = null!;

    public string UserId { get; set; } = null!;

    public string? Type { get; set; }

    public string SeqNo { get; set; } = null!;

    public string? FileName { get; set; }

    public string? DocId { get; set; }

    public string? Revision { get; set; }

    public string? AddDate { get; set; }

    public string? AddTime { get; set; }

    public string? KeyFields { get; set; }
}
