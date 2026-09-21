using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class MDepartment
{
    public int Id { get; set; }

    public string DepCode { get; set; } = null!;

    public string DepName { get; set; } = null!;

    public string? DepLeader { get; set; }

    public string? Directions { get; set; }

    public int? DepLevel { get; set; }

    public string? ParentsDep { get; set; }

    public bool? OrgChartFlag { get; set; }

    public int? Horqueue { get; set; }

    public bool IsEnable { get; set; }

    public int DepGroup { get; set; }
}
