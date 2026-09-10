using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class DWorkProcessDetail
{
    public int Id { get; set; }

    public string Wpno { get; set; } = null!;

    public string Sno { get; set; } = null!;

    public string? ProcessCaption { get; set; }

    public string? ProcessCaption2 { get; set; }

    public string? ProcessContent { get; set; }

    public string? Worker { get; set; }

    public string? AStatus { get; set; }

    public string? UploadFile { get; set; }

    public string? RenameFile { get; set; }

    public string? ZipFile { get; set; }

    public string? Creator { get; set; }

    public string? Modifier { get; set; }

    public DateTime? CreateTime { get; set; }

    public DateTime? ModiTime { get; set; }
}
