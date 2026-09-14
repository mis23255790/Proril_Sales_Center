using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class MPermissionLinkType
{
    public int Id { get; set; }

    /// <summary>AAABBCC，對應 <see cref="MFunction.FunctionNo"/>。</summary>
    public string FunctionNo { get; set; } = null!;

    public byte LinkType { get; set; }

    public string LinkTypeName { get; set; } = null!;

    public int? ParentLinkTypeId { get; set; }

    public string? Creator { get; set; }

    public DateTime? CreateTime { get; set; }

    public string? Modifier { get; set; }

    public DateTime? ModifyTime { get; set; }
}
