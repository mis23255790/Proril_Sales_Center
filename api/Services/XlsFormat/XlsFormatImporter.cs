using ClosedXML.Excel;
using Proril.SalesIssue.Api.Data.SalesCenter;

namespace Proril.SalesIssue.Api.Services.XlsFormat;

/// <summary>範本裡一個分頁的解析結果。<see cref="Recognized"/> = 分頁名稱在目標功能的清單內（有寫進 DB）。</summary>
public sealed record XlsFormatSheetSummary(string WsName, int Rows, int Columns, bool Recognized);

public sealed record XlsFormatParseResult(List<CmnXlsFileFormat> Formats, List<XlsFormatSheetSummary> Sheets, string? Error)
{
    public static XlsFormatParseResult Fail(string error) => new([], [], error);
}

/// <summary>
/// 把上傳的 Excel 範本拆成 CMN_XlsFileFormat 的列。對應 1.0 的
/// <c>CommonApiController.ImportXlsFormat</c>（PUR 版，比 ImportCmnXlsFormat 完整：
/// 數字帶格式、欄的數字格式與隱藏欄），只是寫進 CMN_XlsFileFormat。
///
/// 每個看得見的分頁產生四種列（跟 1.0 相同，套用端靠欄位組合分辨）：
///   列（Height）、欄（Width + 欄樣式 + 數字格式 + 隱藏）、分頁（SplitRow / SplitColumn 凍結窗格）、
///   儲存格（Caption + 樣式 + 數字格式）。
///
/// 與 1.0 的差異：
///   - 範圍從 A1 算到最後一個有內容的列／欄（1.0 用 Rows()/Columns() 的第一個到最後一個，
///     範本如果不是從 A 欄開始，1.0 的儲存格迴圈會用 row.Cell(1..n) 錯位）。
///   - 儲存格數量上限 <see cref="MaxCells"/>：範本只該有表頭，誤傳一份整包資料的匯出檔
///     會寫進幾十萬列，這裡直接擋掉。
///   - 不在目標功能分頁清單內的分頁不寫進 DB（寫了也永遠不會被讀到），回傳時標成未辨識。
///   - 多一個 StyleWrapText：表頭常用 Alt+Enter 換行，1.0 沒存自動換行，匯出後換行不生效。
///   - 合併儲存格一樣不支援（1.0 也沒有）。
/// </summary>
public static class XlsFormatImporter
{
    public const int MaxCells = 5000;
    private const int MaxCaptionLength = 400;
    private const int MaxSheetNameLength = 40;

    public static XlsFormatParseResult Parse(XLWorkbook workbook, XlsFormatTarget target, string subNo, string account)
    {
        var now = DateTime.Now;
        var formats = new List<CmnXlsFileFormat>();
        var sheets = new List<XlsFormatSheetSummary>();
        var totalCells = 0;

        foreach (var ws in workbook.Worksheets)
        {
            if (ws.Visibility != XLWorksheetVisibility.Visible) continue;

            var lastRow = ws.LastRowUsed()?.RowNumber() ?? 0;
            var lastCol = ws.LastColumnUsed()?.ColumnNumber() ?? 0;
            var recognized = target.SheetNames.Contains(ws.Name);
            sheets.Add(new XlsFormatSheetSummary(ws.Name, lastRow, lastCol, recognized));

            if (!recognized || lastRow == 0 || lastCol == 0) continue;

            if (ws.Name.Length > MaxSheetNameLength)
                return XlsFormatParseResult.Fail($"分頁名稱「{ws.Name}」超過 {MaxSheetNameLength} 字");

            totalCells += lastRow * lastCol;
            if (totalCells > MaxCells)
            {
                return XlsFormatParseResult.Fail(
                    $"範本太大（超過 {MaxCells} 格）。範本只需要保留表頭列與欄位設定，請刪掉資料列後再匯入。");
            }

            CmnXlsFileFormat NewFormat() => new()
            {
                PermissionKey = target.PermissionKey,
                FunctionSubNo = subNo,
                Wsname = ws.Name,
                Creator = account,
                CreateTime = now
            };

            // 列：列高
            for (var r = 1; r <= lastRow; r++)
            {
                var f = NewFormat();
                f.ColumnStartId = "A";
                f.ColumnEndId = XLHelper.GetColumnLetterFromNumber(lastCol);
                f.RowStartId = r;
                f.RowEndId = r;
                f.Height = ws.Row(r).Height;
                formats.Add(f);
            }

            // 欄：欄寬、欄樣式、數字格式、隱藏
            for (var c = 1; c <= lastCol; c++)
            {
                var column = ws.Column(c);
                var f = NewFormat();
                f.ColumnStartId = column.ColumnLetter();
                f.ColumnEndId = column.ColumnLetter();
                f.RowStartId = 1;
                f.RowEndId = lastRow;
                f.Width = column.Width;
                f.IsHidden = column.IsHidden;
                XlsStyleCodec.ReadStyle(column.Style, f);
                formats.Add(f);
            }

            // 分頁：凍結窗格
            var sheet = NewFormat();
            sheet.ColumnStartId = "A";
            sheet.ColumnEndId = XLHelper.GetColumnLetterFromNumber(lastCol);
            sheet.RowStartId = 1;
            sheet.RowEndId = lastRow;
            sheet.SplitRow = ws.SheetView.SplitRow;
            sheet.SplitColumn = ws.SheetView.SplitColumn;
            formats.Add(sheet);

            // 儲存格：文字與樣式
            for (var r = 1; r <= lastRow; r++)
            {
                for (var c = 1; c <= lastCol; c++)
                {
                    var cell = ws.Cell(r, c);

                    // GetFormattedString：數字也照顯示格式讀成文字（1.0 CMN 版只讀文字格，數字表頭會消失）。
                    // 換行統一成 \r\n：匯入時有些換行只有 \r，寫回 Excel 後不會斷行（1.0 的註解）。
                    var caption = cell.GetFormattedString()
                        .Replace("\r\n", "\n").Replace("\r", "\n").Replace("\n", "\r\n");
                    if (caption.Length > MaxCaptionLength)
                        return XlsFormatParseResult.Fail($"分頁「{ws.Name}」{cell.Address} 的文字超過 {MaxCaptionLength} 字");

                    var f = NewFormat();
                    f.ColumnStartId = cell.Address.ColumnLetter;
                    f.ColumnEndId = cell.Address.ColumnLetter;
                    f.RowStartId = r;
                    f.RowEndId = r;
                    f.Caption = caption.Length > 0 ? caption : null;
                    f.FormulaA1 = cell.HasFormula ? cell.FormulaA1 : null;
                    XlsStyleCodec.ReadStyle(cell.Style, f);
                    formats.Add(f);
                }
            }
        }

        if (sheets.Count == 0)
            return XlsFormatParseResult.Fail("範本裡沒有任何看得見的分頁");

        if (!sheets.Any(s => s.Recognized))
        {
            return XlsFormatParseResult.Fail(
                $"範本的分頁名稱都對不上「{target.Label}」的匯出分頁。分頁要命名為：{string.Join("、", target.SheetNames)}"
                + $"（範本裡是：{string.Join("、", sheets.Select(s => s.WsName))}）");
        }

        if (formats.Count == 0)
            return XlsFormatParseResult.Fail("範本裡對得上的分頁都是空的");

        return new XlsFormatParseResult(formats, sheets, null);
    }
}
