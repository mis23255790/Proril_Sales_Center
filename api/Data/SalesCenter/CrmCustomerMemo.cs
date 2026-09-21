using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class CrmCustomerMemo
{
    public int Id { get; set; }

    public string? CustomerNo { get; set; }

    public string? MemoType { get; set; }

    public string? MemoDesc { get; set; }

    public string? FileName { get; set; }

    public string? AStatus { get; set; }

    public string? Creator { get; set; }

    public DateTime? CreateTime { get; set; }

    public string? Modifier { get; set; }

    public DateTime? ModiTime { get; set; }
}
