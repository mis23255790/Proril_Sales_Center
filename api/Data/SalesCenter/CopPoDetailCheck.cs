using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class CopPoDetailCheck
{
    public int Id { get; set; }

    public string? OrderChkNo { get; set; }

    public DateTime? ChkTime { get; set; }

    public string? CopSource { get; set; }

    public string? PoNo { get; set; }

    public string? Sno { get; set; }

    public string? ProductNo { get; set; }

    public string? ProductNoChk { get; set; }

    public string? QtyChk { get; set; }

    public string? AmtChk { get; set; }

    public string? PriceChk { get; set; }

    public string? PackListChk { get; set; }

    public string? LinkTypeChk { get; set; }

    public string? LinkNoChk { get; set; }

    public string? LinkSnoChk { get; set; }

    public string? LinkQtyChk { get; set; }

    public string? LinkPriceChk { get; set; }

    public string? LinkChk { get; set; }

    public string? MoqamtChk { get; set; }

    public string? LinkMoqamtChk { get; set; }

    public string? FinChk { get; set; }

    public string? Memo { get; set; }

    public string? AStatus { get; set; }

    public string? Creator { get; set; }

    public DateTime? CreateTime { get; set; }

    public string? Modifier { get; set; }

    public DateTime? ModiTime { get; set; }
}
