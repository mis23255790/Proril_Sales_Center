using Proril.SalesIssue.Api.Models;

namespace Proril.SalesIssue.Api.Services.XlsFormat;

/// <summary>一個可以套版型的匯出功能。<see cref="SheetNames"/> 是範本裡要用的分頁名稱。</summary>
public sealed record XlsFormatTarget(string PermissionKey, string Label, IReadOnlyList<string> SheetNames, string? Note = null);

/// <summary>
/// 哪些匯出會讀 CMN_XlsFileFormat。格式匯入頁的下拉選單、匯入時的檢查都看這份清單。
///
/// 1.0 的格式匯入頁是列出整份 M_Function 讓人挑 FunctionNo，挑到沒有匯出的功能也照樣寫進去，
/// 分頁名稱打錯也不會有任何提示（匯出時就是找不到版型）。2.0 只列真的會讀版型的匯出，
/// 分頁名稱對不上的在匯入時直接告知。
///
/// 新增一支會讀版型的匯出：在這裡加一筆，匯出端用 <see cref="XlsFormatTemplate.Load"/> 取版型。
/// </summary>
public static class XlsFormatTargets
{
    /// <summary>有金額權限的版型（沿用 1.0 的 FunctionSubNo 慣例：0 = 含金額，1 = 不含金額）。</summary>
    public const string SubNoWithAmount = "0";

    /// <summary>沒有金額權限的版型（金額欄位整欄拿掉，欄位位置跟 0 不同，所以要另一份版型）。</summary>
    public const string SubNoNoAmount = "1";

    public static readonly IReadOnlyList<(string Value, string Label)> SubNos =
    [
        (SubNoWithAmount, "有金額權限"),
        (SubNoNoAmount, "無金額權限")
    ];

    public const string OrderInfoVerifySummarySheet = "訂單總表";

    /// <summary>訂單資料檢核的明細分頁是一張訂單一個（分頁名稱 1、2、3…），全部套這個版型。</summary>
    public const string OrderInfoVerifyDetailSheet = "訂單細項";

    public static readonly IReadOnlyList<XlsFormatTarget> All =
    [
        new(PermissionKeys.SalesSearch.MixSalesShipping, "銷貨檢索",
            ["品號細項", "品號統計", "銷貨單細項", "銷貨單統計"]),
        new(PermissionKeys.SalesSearch.QueryUnFinish, "未完成訂單",
            ["品號細項", "品號統計", "訂單細項", "訂單統計"]),
        new(PermissionKeys.SalesSearch.OrderInfoVerify, "訂單資料檢核",
            [OrderInfoVerifySummarySheet, OrderInfoVerifyDetailSheet],
            "匯出時每張訂單一個明細分頁（1、2、3…），全部套「訂單細項」的版型。")
    ];

    public static XlsFormatTarget? Find(string? permissionKey)
        => All.FirstOrDefault(t => string.Equals(t.PermissionKey, permissionKey?.Trim(), StringComparison.Ordinal));

    public static bool IsValidSubNo(string? subNo) => SubNos.Any(s => s.Value == subNo?.Trim());

    public static string SubNoFor(bool showAmount) => showAmount ? SubNoWithAmount : SubNoNoAmount;
}
