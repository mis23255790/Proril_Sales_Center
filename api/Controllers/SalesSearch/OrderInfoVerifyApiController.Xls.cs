using ClosedXML.Excel;
using Microsoft.AspNetCore.Mvc;
using Proril.SalesIssue.Api.Models;

namespace Proril.SalesIssue.Api.Controllers.SalesSearch;

/*
 * Excel 匯出。
 *
 * 1.0 的匯出格式是讀 CMN_XlsFileFormat 資料表動態組欄寬/表頭/樣式（XlsFormatterApis_Cmn），
 * 那套通用格式引擎是給多個「還沒搬」的模組共用的排版基礎設施，只為這一個匯出去搬整套
 * DB 驅動格式系統不成比例。這裡改成直接在 C# 寫死欄位配置，輸出結果（分頁、欄位、
 * 上色規則）與 1.0 一致，只是格式設定不再走 DB。
 */
public partial class OrderInfoVerifyApiController
{
    private const string SheetOrderSummary = "訂單總表";

    /// <summary>
    /// 匯出 Excel：「訂單總表」一列一張訂單 + 每張訂單一個「訂單細項」分頁。
    /// 金額欄位權限用本模組自己的 FunctionId(425)，1.0 匯出用的是 MixSalesShipping(410)——
    /// 那兩個 FunctionId 對不上號查無明顯理由，這裡統一用 425。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel ExportXls(string? orderType, string? orderNo, string? customerNo, string? startDate, string? endDate, string? confirmFlag)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(ExportXls), $"orderType:{orderType}, customerNo:{customerNo}, confirmFlag:{confirmFlag}");

        var orderInfo = GetOrderInfoList(null, orderType, orderNo, customerNo, startDate, endDate, confirmFlag);
        if (orderInfo.Count == 0)
        {
            ca.Message = "查無資料可匯出!!!";
            return ca;
        }

        var account = GetAccountByToken();
        var showAmount = HasAmountPermission(account, FunctionIds.OrderInfoVerify, OrderInfoVerifyConst.AmountLinkType);

        using var workbook = new XLWorkbook();
        WriteOrderSummarySheet(workbook, orderInfo, showAmount);
        WriteOrderDetailSheets(workbook, orderInfo, showAmount);

        var dir = _paths.ExportDir(account);
        Directory.CreateDirectory(dir);
        var fileName = $"COP_{DateTime.Now:yyyyMMdd_HHmm}.xlsx";
        workbook.SaveAs(Path.Combine(dir, fileName));

        ca.IsSuccess = true;
        ca.Body = $"Temp/{account}/Export/{fileName}";
        return ca;
    }

    private bool HasAmountPermission(string account, int functionNo, int linkType)
    {
        if (db.MUsers.Any(u => u.Account == account && u.IsAdmin)) return true;
        return db.MPermissions.Any(p => p.LinkNumber == account && p.FunctionNo == functionNo && p.LinkType == linkType);
    }

    /// <summary>檢核結果上色：Y=淡綠／P=淡黃／N=淡紅／其他(未檢核)=灰，照抄 1.0 色碼。</summary>
    private static void ApplyRowColor(IXLRow row, string? finFlag)
    {
        row.Style.Fill.BackgroundColor = finFlag switch
        {
            "Y" => XLColor.FromHtml("#FF98FF98"),
            "P" => XLColor.FromHtml("#FFFFC40C"),
            "N" => XLColor.FromHtml("#FFFDBCB4"),
            _ => XLColor.FromHtml("#FFDCDCDC")
        };
    }

    /// <summary>17 個表頭檢核欄位，任一 N→N，任一 P→P，否則 Y，無檢核資料回 null。</summary>
    private static string? HeaderFinFlag(CopPoCheckExRule? check)
    {
        if (check is null) return null;
        string?[] fields =
        [
            check.DepBlankChk, check.DepChk, check.PackListBlankChk, check.PriceBlankChk, check.PreDateChk,
            check.CustAmtZeroChk, check.CustSumAmtChk, check.CustPochk, check.TransChk, check.ProcessCodeChk,
            check.TradeChk, check.OutPortChk, check.InPortChk, check.UpFileChk, check.RateChk, check.PaidChk
        ];
        if (fields.Any(f => f == "N")) return "N";
        if (fields.Any(f => f == "P")) return "P";
        return "Y";
    }

    private static readonly string[] OrderSummaryHeadersWithAmount =
    [
        "序", "ERP來源", "單別名稱", "單別", "單號", "訂單日期", "客戶代號", "客戶名稱", "部門代號",
        "部門名稱", "PackingList備註", "客戶單號", "訂單金額", "交易條件", "交易條件名稱",
        "起始港口", "目的港口", "運輸方式", "業務名稱", "業務人員", "附件檔案"
    ];

    private static readonly string[] OrderSummaryHeadersNoAmount =
    [
        "序", "ERP來源", "單別名稱", "單別", "單號", "訂單日期", "客戶代號", "客戶名稱", "部門代號",
        "部門名稱", "PackingList備註", "客戶單號",
        "起始港口", "目的港口", "運輸方式", "業務名稱", "業務人員", "附件檔案"
    ];

    private void WriteOrderSummarySheet(XLWorkbook workbook, List<VPoListDetailViewModel> orderInfo, bool showAmount)
    {
        var ws = workbook.AddWorksheet(SheetOrderSummary);
        var headers = showAmount ? OrderSummaryHeadersWithAmount : OrderSummaryHeadersNoAmount;
        for (var i = 0; i < headers.Length; i++) ws.Cell(1, i + 1).Value = headers[i];
        ws.Row(1).Style.Font.Bold = true;

        var y = 2;
        var sno = 1;
        string? curKey = null;

        foreach (var order in orderInfo)
        {
            var key = $"{order.CopSource}-{order.單別}-{order.單號}";
            if (key == curKey) continue;
            curKey = key;

            var x = 1;
            ws.Cell(y, x++).Value = sno++;
            ws.Cell(y, x++).Value = order.CopSource;
            ws.Cell(y, x++).Value = order.單別名稱;
            ws.Cell(y, x++).Value = order.單別;
            ws.Cell(y, x++).Value = order.單號;
            ws.Cell(y, x++).Value = order.訂單日期;
            ws.Cell(y, x++).Value = order.客戶代號;
            ws.Cell(y, x++).Value = order.客戶名稱;
            ws.Cell(y, x++).Value = order.部門代號;
            ws.Cell(y, x++).Value = order.DepName;
            ws.Cell(y, x++).Value = order.Packinglist備註;
            ws.Cell(y, x++).Value = order.客戶單號;
            if (showAmount)
            {
                ws.Cell(y, x++).Value = order.訂單金額;
                ws.Cell(y, x++).Value = order.交易條件;
                ws.Cell(y, x++).Value = order.交易條件名稱;
            }
            ws.Cell(y, x++).Value = order.起始港口;
            ws.Cell(y, x++).Value = order.目的港口;
            ws.Cell(y, x++).Value = order.運輸方式;
            ws.Cell(y, x++).Value = order.業務名稱;
            ws.Cell(y, x++).Value = order.業務人員;
            ws.Cell(y, x++).Value = order.附件檔案;

            ApplyRowColor(ws.Row(y), HeaderFinFlag(order.CopPoCheck));
            y++;
        }

        ws.Columns().AdjustToContents();
        ws.SetAutoFilter();
    }

    private static readonly string[] OrderDetailHeadersWithAmount =
        ["序", "ERP來源", "單別名稱", "單別", "單號", "序號", "品號", "品名", "規格", "幣別", "匯率", "訂單數量", "單位", "外幣單價", "外幣金額", "台幣金額", "預交日", "檢核結果"];

    private static readonly string[] OrderDetailHeadersNoAmount =
        ["序", "ERP來源", "單別名稱", "單別", "單號", "序號", "品號", "品名", "規格", "訂單數量", "單位", "預交日", "檢核結果"];

    private void WriteOrderDetailSheets(XLWorkbook workbook, List<VPoListDetailViewModel> orderInfo, bool showAmount)
    {
        var headers = showAmount ? OrderDetailHeadersWithAmount : OrderDetailHeadersNoAmount;
        var orderSno = 1;
        string? curKey = null;
        IXLWorksheet? ws = null;
        var y = 2;
        var lineSno = 1;

        foreach (var detail in orderInfo)
        {
            var key = $"{detail.CopSource}-{detail.單別}-{detail.單號}";
            if (key != curKey)
            {
                curKey = key;
                ws = workbook.AddWorksheet($"{orderSno++}");
                for (var i = 0; i < headers.Length; i++) ws.Cell(1, i + 1).Value = headers[i];
                ws.Row(1).Style.Font.Bold = true;
                y = 2;
                lineSno = 1;
            }

            var x = 1;
            ws!.Cell(y, x++).Value = lineSno++;
            ws.Cell(y, x++).Value = detail.CopSource;
            ws.Cell(y, x++).Value = detail.單別名稱;
            ws.Cell(y, x++).Value = detail.VPoDetail.單別;
            ws.Cell(y, x++).Value = detail.VPoDetail.單號;
            ws.Cell(y, x++).Value = detail.VPoDetail.序號;
            ws.Cell(y, x++).Value = detail.VPoDetail.品號;
            ws.Cell(y, x++).Value = detail.VPoDetail.品名;
            ws.Cell(y, x++).Value = detail.VPoDetail.規格;
            if (showAmount)
            {
                ws.Cell(y, x++).Value = detail.VPoDetail.幣別;
                ws.Cell(y, x++).Value = detail.VPoDetail.匯率;
            }
            ws.Cell(y, x++).Value = detail.VPoDetail.訂單數量;
            ws.Cell(y, x++).Value = detail.VPoDetail.單位;
            if (showAmount)
            {
                ws.Cell(y, x++).Value = detail.VPoDetail.外幣單價;
                ws.Cell(y, x++).Value = detail.VPoDetail.外幣金額;
                ws.Cell(y, x++).Value = detail.VPoDetail.台幣金額;
            }
            ws.Cell(y, x++).Value = detail.VPoDetail.預交日;
            ws.Cell(y, x++).Value = detail.VPoDetail.FinFlag;

            ApplyRowColor(ws.Row(y), detail.VPoDetail.FinFlag);
            y++;
        }

        foreach (var sheet in workbook.Worksheets.Where(w => w.Name != SheetOrderSummary))
        {
            sheet.Columns().AdjustToContents();
            sheet.SetAutoFilter();
        }
    }
}
