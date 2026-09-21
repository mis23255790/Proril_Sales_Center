using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class MPermissionGroupBakFunctionNo
{
    public int Id { get; set; }

    public int GroupType { get; set; }

    public string? GroupNo { get; set; }

    public int? FunctionNo { get; set; }

    public byte? LinkType { get; set; }

    public string? TypeDesc { get; set; }

    public string? GroupDesc { get; set; }

    public string? AStatus { get; set; }

    public string? Creator { get; set; }

    public DateTime? CreateTime { get; set; }

    public string? Modifier { get; set; }

    public DateTime? ModiTime { get; set; }
}
