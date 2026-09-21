using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class CopProductCheck
{
    public int Id { get; set; }

    public string? ChkNo { get; set; }

    public string? ChkSource { get; set; }

    public string? OrderChkNo { get; set; }

    public DateTime? ChkTime { get; set; }

    public string? ProductNo { get; set; }

    public string? ProductName { get; set; }

    public string? ProductNameEn { get; set; }

    public string? ProductSpec { get; set; }

    public string? ProductSpecEn { get; set; }

    public string? NoChk { get; set; }

    public string? Phchk { get; set; }

    public string? Hzchk { get; set; }

    public string? StartChk { get; set; }

    public string? VolChk { get; set; }

    public string? FloatChk { get; set; }

    public string? WireSpecChk { get; set; }

    public string? WireSizeChk { get; set; }

    public string? PlusChk { get; set; }

    public string? Ext1Chk { get; set; }

    public string? Ext2Chk { get; set; }

    public string? Ext3Chk { get; set; }

    public string? FinChk { get; set; }

    public string? Memo { get; set; }

    public string? AStatus { get; set; }

    public string? Creator { get; set; }

    public DateTime? CreateTime { get; set; }

    public string? Modifier { get; set; }

    public DateTime? ModiTime { get; set; }
}
