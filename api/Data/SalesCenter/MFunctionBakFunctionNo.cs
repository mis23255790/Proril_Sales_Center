using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class MFunctionBakFunctionNo
{
    public int Id { get; set; }

    public int FunctionNo { get; set; }

    public string? FunctionName { get; set; }

    public int SystemNo { get; set; }

    public int? GroupNo { get; set; }

    public string? GroupName { get; set; }

    public string? ImagrePath { get; set; }

    public string? Href { get; set; }

    public string? AStatus { get; set; }

    public string? RedirectHref { get; set; }
}
