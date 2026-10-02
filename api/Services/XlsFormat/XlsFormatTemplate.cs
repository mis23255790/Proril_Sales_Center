using ClosedXML.Excel;
using Microsoft.EntityFrameworkCore;
using Proril.SalesIssue.Api.Data.SalesCenter;

namespace Proril.SalesIssue.Api.Services.XlsFormat;

/// <summary>
/// 一支匯出（PermissionKey + FunctionSubNo）的版型，依分頁名稱分組。
///
/// 用法（匯出端）：
/// <code>
/// var template = XlsFormatTemplate.Load(scDb, PermissionKeys.Xxx, XlsFormatTargets.SubNoFor(showAmount));
/// var ws = workbook.AddWorksheet("分頁名稱");
/// var headerRows = template.Apply(ws, "分頁名稱");
/// if (headerRows == 0) { /* 沒有版型：照原本寫死的表頭、欄寬 */ }
/// // 資料從 headerRows + 1 列開始寫
/// </code>
///
/// **先套版型、再寫資料**（與 1.0 相同）：欄樣式套在整欄，之後寫進去的資料格會沿用；
/// 資料列的底色（檢核結果上色、斑馬紋）是寫資料時才上的，不會被欄樣式蓋掉。
/// 版型只管表頭與欄位外觀，**資料寫在哪一欄仍由匯出端程式決定**——範本的欄位順序要跟匯出一致，
/// 這點跟 1.0 一樣。
/// </summary>
public sealed class XlsFormatTemplate
{
    private readonly Dictionary<string, List<CmnXlsFileFormat>> _sheets;

    private XlsFormatTemplate(Dictionary<string, List<CmnXlsFileFormat>> sheets) => _sheets = sheets;

    public static XlsFormatTemplate Empty { get; } = new([]);

    public static XlsFormatTemplate Load(SalesCenterDbContext db, string permissionKey, string subNo)
    {
        var rows = db.CmnXlsFileFormats
            .AsNoTracking()
            .Where(f => f.PermissionKey == permissionKey && f.FunctionSubNo == subNo)
            .OrderBy(f => f.Id)
            .ToList();

        return new XlsFormatTemplate(rows
            .GroupBy(f => f.Wsname)
            .ToDictionary(g => g.Key, g => g.ToList()));
    }

    public IReadOnlyCollection<string> SheetNames => _sheets.Keys;

    public bool Has(string sheetName) => _sheets.ContainsKey(sheetName);

    /// <summary>
    /// 把 <paramref name="sheetName"/> 的版型套到 <paramref name="ws"/>。
    /// 回傳表頭佔幾列（最後一個有文字的版型列，至少 1）；沒有這個分頁的版型回 0，工作表不動。
    /// </summary>
    public int Apply(IXLWorksheet ws, string sheetName)
    {
        if (!_sheets.TryGetValue(sheetName, out var formats) || formats.Count == 0) return 0;

        // 欄 → 列 → 儲存格 → 分頁：儲存格樣式要最後蓋，才不會被整欄樣式洗掉
        foreach (var f in formats.Where(IsColumn))
        {
            var column = ws.Column(f.ColumnStartId!);
            if (f.Width is { } width && width > 0) column.Width = width;
            XlsStyleCodec.ApplyStyle(column.Style, f);
            if (f.IsHidden == true) column.Hide();
        }

        foreach (var f in formats.Where(IsRow))
        {
            if (f.Height is { } height && height > 0) ws.Row(f.RowStartId!.Value).Height = height;
        }

        var headerRows = 1;
        foreach (var f in formats.Where(IsCell))
        {
            var cell = ws.Cell(f.RowStartId!.Value, f.ColumnStartId!);
            XlsStyleCodec.ApplyStyle(cell.Style, f);
            if (!string.IsNullOrEmpty(f.Caption))
            {
                cell.Value = f.Caption;
                headerRows = Math.Max(headerRows, f.RowStartId.Value);
            }
        }

        if (formats.FirstOrDefault(IsSheet) is { } sheet)
        {
            var splitRow = sheet.SplitRow ?? 0;
            var splitColumn = sheet.SplitColumn ?? 0;
            if (splitRow > 0 || splitColumn > 0) ws.SheetView.Freeze(splitRow, splitColumn);
        }

        return headerRows;
    }

    // 一列是哪一種，靠欄位組合分辨（與 XlsFormatImporter 寫入的方式對應）
    private static bool IsRow(CmnXlsFileFormat f) => f.Height is not null && f.RowStartId is not null;
    private static bool IsColumn(CmnXlsFileFormat f) => f.Width is not null && !string.IsNullOrEmpty(f.ColumnStartId);
    private static bool IsSheet(CmnXlsFileFormat f) => f.SplitRow is not null || f.SplitColumn is not null;

    private static bool IsCell(CmnXlsFileFormat f)
        => f.Height is null && f.Width is null && !IsSheet(f)
           && f.RowStartId is not null && !string.IsNullOrEmpty(f.ColumnStartId);
}
