using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class MFunction
{
    public int Id { get; set; }

    /// <summary>AAABBCC：SystemNo(3) + GroupNo(2) + 序號(2)。見 database/FunctionNoFormatMigration.sql。</summary>
    public string FunctionNo { get; set; } = null!;

    public string? FunctionName { get; set; }

    public int SystemNo { get; set; }

    public int? GroupNo { get; set; }

    public string? GroupName { get; set; }

    public string? ImagrePath { get; set; }

    public string? Href { get; set; }

    public string? AStatus { get; set; }

    public string? RedirectHref { get; set; }
}
