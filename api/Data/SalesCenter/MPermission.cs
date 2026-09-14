using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class MPermission
{
    public int Id { get; set; }

    public string? LinkNumber { get; set; }

    public string FunctionNo { get; set; } = null!;

    public string? Creator { get; set; }

    public byte LinkType { get; set; }

    public DateTime? CreateTime { get; set; }

    public int? PermissionLinkTypeId { get; set; }

    public string? Modifier { get; set; }

    public DateTime? ModiTime { get; set; }
}
