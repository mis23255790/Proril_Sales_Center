using System.Globalization;
using ClosedXML.Excel;
using Proril.SalesIssue.Api.Data.SalesCenter;

namespace Proril.SalesIssue.Api.Services.XlsFormat;

/// <summary>
/// CMN_XlsFileFormat 樣式欄位與 ClosedXML 之間的轉換，匯入（<see cref="XlsFormatImporter"/>）
/// 與套用（<see cref="XlsFormatTemplate"/>）共用，兩邊的字串格式才對得起來。
///
/// 與 1.0（CommonApiController.ImportXlsFormat + XlsFormatterApis）的差異，都是 1.0 的既有 bug：
///   - 顏色：1.0 儲存格存 <c>XLColor.ToString()</c>、欄存 ARGB，沒底色的欄會存成 "00000000"
///     再被讀成透明黑。這裡沒有填滿（PatternType = None）一律存 null，套用時不動底色；
///     Theme 色的 Tint 是小數，1.0 用 int.TryParse 解析永遠失敗變 0。
///   - 數字格式：1.0 套用時把格式字串用 ';' 切開只取第一段（會計格式的負數／零值段全丟），
///     也用 '=' 切 key/value（格式裡有 [>=1000] 就壞）。這裡只切第一個 '='，其餘原樣保留。
///   - 1.0 的 <c>Xlsettings</c> 用 reflection 呼叫 set_xxx，這裡只認得數字格式兩種 key，直接 switch。
/// </summary>
public static class XlsStyleCodec
{
    private const string ThemePrefix = "Color Theme:";
    private const string IndexPrefix = "Color Index:";
    private const string NumberFormatIdKey = "NumberFormat.NumberFormatId";
    private const string NumberFormatKey = "NumberFormat.Format";

    /// <summary>Excel 的「自動」色（系統前景色），存成 null，套用時不指定。</summary>
    private const int AutoColorIndex = 64;

    // ---------------------------------------------------------------- 讀（匯入）

    /// <summary>把 ClosedXML 樣式拆進版型列的 Style* / Xlsettings 欄位。</summary>
    public static void ReadStyle(IXLStyle style, CmnXlsFileFormat target)
    {
        target.StyleAlignmentH = style.Alignment.Horizontal.ToString();
        target.StyleAlignmentV = style.Alignment.Vertical.ToString();
        target.StyleWrapText = style.Alignment.WrapText;
        target.StyleBorderLeft = style.Border.LeftBorder.ToString();
        target.StyleBorderTop = style.Border.TopBorder.ToString();
        target.StyleBorderRight = style.Border.RightBorder.ToString();
        target.StyleBorderBottom = style.Border.BottomBorder.ToString();
        target.StyleFillColor = style.Fill.PatternType == XLFillPatternValues.None
            ? null
            : ColorToString(style.Fill.BackgroundColor);
        target.StyleFontSize = style.Font.FontSize;
        target.StyleFontBold = style.Font.Bold;
        target.StyleFontColor = ColorToString(style.Font.FontColor);
        target.Xlsettings = NumberFormatToSetting(style.NumberFormat);
    }

    public static string? ColorToString(XLColor? color)
    {
        if (color is null || !color.HasValue) return null;

        return color.ColorType switch
        {
            XLColorType.Color =>
                $"{color.Color.A:X2}{color.Color.R:X2}{color.Color.G:X2}{color.Color.B:X2}",
            XLColorType.Theme =>
                $"{ThemePrefix} {color.ThemeColor}, Tint: {color.ThemeTint.ToString(CultureInfo.InvariantCulture)}",
            XLColorType.Indexed => color.Indexed == AutoColorIndex ? null : $"{IndexPrefix} {color.Indexed}",
            _ => null
        };
    }

    /// <summary>內建格式存 Id，自訂格式存整串格式字串；「通用格式」回 null。</summary>
    public static string? NumberFormatToSetting(IXLNumberFormat numberFormat)
    {
        if (numberFormat.NumberFormatId > 0) return $"{NumberFormatIdKey}={numberFormat.NumberFormatId}";
        if (!string.IsNullOrEmpty(numberFormat.Format)) return $"{NumberFormatKey}={numberFormat.Format}";
        return null;
    }

    // ---------------------------------------------------------------- 寫（套用）

    /// <summary>把版型列的樣式套到 ClosedXML 樣式上；欄位是 null 的就不動（沿用原本樣式）。</summary>
    public static void ApplyStyle(IXLStyle style, CmnXlsFileFormat source)
    {
        if (Enum.TryParse(source.StyleAlignmentH, out XLAlignmentHorizontalValues alignH))
            style.Alignment.Horizontal = alignH;
        if (Enum.TryParse(source.StyleAlignmentV, out XLAlignmentVerticalValues alignV))
            style.Alignment.Vertical = alignV;
        if (source.StyleWrapText is { } wrap)
            style.Alignment.WrapText = wrap;

        if (Enum.TryParse(source.StyleBorderLeft, out XLBorderStyleValues borderL))
            style.Border.LeftBorder = borderL;
        if (Enum.TryParse(source.StyleBorderTop, out XLBorderStyleValues borderT))
            style.Border.TopBorder = borderT;
        if (Enum.TryParse(source.StyleBorderRight, out XLBorderStyleValues borderR))
            style.Border.RightBorder = borderR;
        if (Enum.TryParse(source.StyleBorderBottom, out XLBorderStyleValues borderB))
            style.Border.BottomBorder = borderB;

        if (ParseColor(source.StyleFillColor) is { } fill)
            style.Fill.BackgroundColor = fill;

        if (source.StyleFontSize is { } size && size > 0)
            style.Font.FontSize = size;
        if (source.StyleFontBold is { } bold)
            style.Font.Bold = bold;
        if (ParseColor(source.StyleFontColor) is { } fontColor)
            style.Font.FontColor = fontColor;

        ApplySetting(style, source.Xlsettings);
    }

    public static XLColor? ParseColor(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return null;
        var text = value.Trim();

        if (text.StartsWith(ThemePrefix, StringComparison.Ordinal))
        {
            // "Color Theme: Accent1, Tint: 0.3999"
            var parts = text[ThemePrefix.Length..].Split(',', 2);
            if (!Enum.TryParse(parts[0].Trim(), out XLThemeColor theme)) return null;

            var tint = 0d;
            if (parts.Length == 2)
            {
                var tintText = parts[1].Replace("Tint:", "", StringComparison.Ordinal).Trim();
                double.TryParse(tintText, NumberStyles.Float, CultureInfo.InvariantCulture, out tint);
            }
            return XLColor.FromTheme(theme, tint);
        }

        if (text.StartsWith(IndexPrefix, StringComparison.Ordinal))
        {
            return int.TryParse(text[IndexPrefix.Length..].Trim(), out var index) && index != AutoColorIndex
                ? XLColor.FromIndex(index)
                : null;
        }

        // ARGB（8 碼，匯入寫的格式）或 RGB（6 碼，手動改 DB 時比較好寫）
        if (text.Length == 8 && uint.TryParse(text, NumberStyles.HexNumber, null, out var argb))
            return XLColor.FromArgb((int)(argb >> 24), (int)((argb >> 16) & 0xFF), (int)((argb >> 8) & 0xFF), (int)(argb & 0xFF));
        if (text.Length == 6 && uint.TryParse(text, NumberStyles.HexNumber, null, out _))
            return XLColor.FromHtml($"#{text}");

        return null;
    }

    private static void ApplySetting(IXLStyle style, string? setting)
    {
        if (string.IsNullOrWhiteSpace(setting)) return;

        // 只切第一個 '='：格式字串本身可能帶 '='（例如 [>=1000]），也常帶 ';'（正;負;零;文字 四段）
        var idx = setting.IndexOf('=');
        if (idx <= 0) return;
        var key = setting[..idx].Trim();
        var value = setting[(idx + 1)..];

        switch (key)
        {
            case NumberFormatIdKey when int.TryParse(value, out var id):
                style.NumberFormat.NumberFormatId = id;
                break;
            case NumberFormatKey when value.Length > 0:
                style.NumberFormat.Format = value;
                break;
        }
    }
}
