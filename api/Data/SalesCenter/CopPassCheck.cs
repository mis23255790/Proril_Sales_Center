using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class CopPassCheck
{
    public int Id { get; set; }

    public string? OrderChkNo { get; set; }

    public string? Sno { get; set; }

    public DateTime? PassTime { get; set; }

    public string? PassItems { get; set; }

    public string? PassMemo { get; set; }

    public string? Memo { get; set; }

    public string? AStatus { get; set; }

    public string? Creator { get; set; }

    public DateTime? CreateTime { get; set; }

    public string? Modifier { get; set; }

    public DateTime? ModiTime { get; set; }
}
