using System;
using System.Collections.Generic;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

/// <summary>
/// Excel 匯出版型（database/XlsFormatObjectsMigration.sql）。
/// 與 1.0 同名，但 key 從 FunctionNo(int) 改成 <see cref="PermissionKey"/>，見腳本開頭註解。
/// 一列是列／欄／分頁／儲存格其中一種，判斷方式見 <c>Services/XlsFormat/XlsFormatTemplate.cs</c>。
/// </summary>
public partial class CmnXlsFileFormat
{
    public int Id { get; set; }

    public string PermissionKey { get; set; } = null!;

    public string FunctionSubNo { get; set; } = null!;

    public string Wsname { get; set; } = null!;

    public string? ColumnStartId { get; set; }

    public string? ColumnEndId { get; set; }

    public int? RowStartId { get; set; }

    public int? RowEndId { get; set; }

    public string? Caption { get; set; }

    public string? FormulaA1 { get; set; }

    public string? StyleAlignmentH { get; set; }

    public string? StyleAlignmentV { get; set; }

    public string? StyleBorderLeft { get; set; }

    public string? StyleBorderTop { get; set; }

    public string? StyleBorderRight { get; set; }

    public string? StyleBorderBottom { get; set; }

    public string? StyleFillColor { get; set; }

    public double? StyleFontSize { get; set; }

    public bool? StyleFontBold { get; set; }

    public string? StyleFontColor { get; set; }

    public bool? StyleWrapText { get; set; }

    public double? Width { get; set; }

    public double? Height { get; set; }

    public int? SplitRow { get; set; }

    public int? SplitColumn { get; set; }

    public string? Xlsettings { get; set; }

    public bool? IsHidden { get; set; }

    public string? Creator { get; set; }

    public DateTime? CreateTime { get; set; }

    public string? Modifier { get; set; }

    public DateTime? ModiTime { get; set; }
}
