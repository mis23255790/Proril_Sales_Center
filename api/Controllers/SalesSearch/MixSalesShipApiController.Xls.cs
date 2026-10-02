using ClosedXML.Excel;
using Microsoft.AspNetCore.Mvc;
using Proril.SalesIssue.Api.Data;
using Proril.SalesIssue.Api.Models;
using Proril.SalesIssue.Api.Services.XlsFormat;
using CopSalesOrder = Proril.SalesIssue.Api.Data.SalesCenter.CopSalesOrder;

namespace Proril.SalesIssue.Api.Controllers.SalesSearch;

/*
 * 銷貨檢索的 Excel 匯出。
 *
 * 版型：CMN_XlsFileFormat（系統管理 / 格式匯入）有這支的版型就套版型（表頭、欄寬、樣式、
 * 數字格式、凍結窗格），沒有就用下面寫死的預設版面。資料欄位的位置一律由 ColSpec 決定，
 * 版型只管外觀，見 Services/XlsFormat/XlsFormatTemplate.cs。
 *
 * 預設版面的表頭文字與數字格式是當初直接查 1.0 PUR_XlsFileFormat（FunctionNo=410）抄下來的；
 * 與 1.0 的差異是欄寬改成 AdjustToContents()，不照抄那組小數點後七位的固定欄寬。
 * 1.0 的 PUR_XlsFileFormat 資料沒有搬（2026-09-30 決定），要 1.0 那份版面就把範本重新匯入。
 */
public partial class MixSalesShipApiController
{
    private const string QtyFormat = @"_-* #,##0_-;\-* #,##0_-;_-* ""-""_-;_-@_-";
    private const string MoneyFormat = @"_-""$""* #,##0_-;\-""$""* #,##0_-;_-""$""* ""-""_-;_-@_-";

    /// <summary>斑馬紋底色，1.0 的 XLColor.FromArgb(0xe2e3e5)。</summary>
    private static readonly XLColor ZebraColor = XLColor.FromArgb(0xe2, 0xe3, 0xe5);

    /// <summary>一個欄位：表頭文字、取值、數字格式（null 表示不套）。</summary>
    private sealed record ColSpec(string Header, Func<CopSalesOrder, XLCellValue> Value, string? Format = null);

    private static XLCellValue Text(string? v) => v ?? "";
    private static XLCellValue Num(decimal? v) => v.HasValue ? v.Value : Blank.Value;

    /// <summary>
    /// 匯出四個分頁：品號細項／品號統計／銷貨單細項／銷貨單統計。
    ///
    /// 前兩頁的資料來源是 <c>prc_QuerySalesOrder</c>（固定用 TH004 分群），後兩頁是
    /// <c>prc_QuerySalesOrder_1</c>（固定用 TH001 分群）——不管呼叫端送什麼 groupName，
    /// 匯出一律兩種分群各跑一次，1.0 也是這樣。
    ///
    /// 回傳的 <c>Body</c> 是相對於 ShareRoot 的路徑，前端要補 <c>/ShareRoot/</c> 前綴
    /// 再走 Nuxt 的 <c>server/api/download.get.ts</c> 下載。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel ExportXls(
        string? customerNo, string? productType, string? productNo, string? productName, string? productSpec,
        string? startDate, string? endDate, string? serialNo, string? poNo,
        string? orderType, string? orderNo, string? inPlanNumber,
        string? groupName, string? groupDesc)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(ExportXls), $"customerNo:{customerNo}, orderType:{orderType}, orderNo:{orderNo}");

        var productInfo = QueryByProduct(customerNo, productType, productNo, productName, productSpec,
            startDate, endDate, serialNo, poNo, inPlanNumber, "TH004", groupDesc);
        var salesOrders = QueryBySalesOrder(customerNo, productType, productNo, productName, productSpec,
            startDate, endDate, serialNo, poNo, orderType, orderNo, inPlanNumber, "TH001", groupDesc);

        if (productInfo.Count == 0 && salesOrders.Count == 0)
        {
            ca.Message = "查無資料可匯出!!!";
            return ca;
        }

        var account = GetAccountByToken();
        var showAmount = HasPermission(account, PermissionKeys.SalesSearch.MixSalesShippingViewAmount);

        var template = XlsFormatTemplate.Load(scDb, PermissionKeys.SalesSearch.MixSalesShipping, XlsFormatTargets.SubNoFor(showAmount));

        using var workbook = new XLWorkbook();
        // 細項頁取「非 Y」（N + S + T），統計頁取「非 N」（S + Y + T），與畫面上的頁籤一致。
        WriteSheet(workbook, template, "品號細項", ProductDetailCols(showAmount),
            productInfo.Where(r => r.FooterFlag != "Y"), GroupKeyByProduct);
        WriteSheet(workbook, template, "品號統計", ProductGroupCols(showAmount),
            productInfo.Where(r => r.FooterFlag != "N"), GroupKeyByProduct);
        WriteSheet(workbook, template, "銷貨單細項", SalesOrderDetailCols(showAmount),
            salesOrders.Where(r => r.FooterFlag != "Y"), GroupKeyBySalesOrder);
        WriteSheet(workbook, template, "銷貨單統計", SalesOrderGroupCols(showAmount),
            FillGroupCustomer(salesOrders).Where(r => r.FooterFlag != "N"), GroupKeyBySalesOrder);

        var dir = _paths.ExportDir(account);
        Directory.CreateDirectory(dir);
        var fileName = $"COP_{DateTime.Now:yyyyMMdd_HHmm}.xlsx";
        workbook.SaveAs(Path.Combine(dir, fileName));

        ca.IsSuccess = true;
        ca.Body = $"Temp/{account}/Export/{fileName}";
        return ca;
    }

    private static string GroupKeyByProduct(CopSalesOrder r) => r.Th004 ?? "";
    private static string GroupKeyBySalesOrder(CopSalesOrder r) => $"{r.Th001}{r.Th002}";

    /// <summary>
    /// 「銷貨單統計」專用：SP 產生的小計／總計列不帶客戶欄位，補上前一筆明細列的客戶。
    /// 1.0 是在寫 cell 的迴圈裡就地改物件，這裡抽成獨立步驟，行為相同
    /// （只有 <c>CustomerName</c> 是空字串才補，null 不補——1.0 的
    /// <c>salesOrder.CustomerName?.Length &lt;= 0</c> 對 null 會是 false）。
    /// </summary>
    private static List<CopSalesOrder> FillGroupCustomer(List<CopSalesOrder> rows)
    {
        string? customerNo = "";
        string? customerName = "";

        foreach (var row in rows)
        {
            if (row.FooterFlag == "N")
            {
                customerNo = row.CustomerNo;
                customerName = row.CustomerName;
            }
            else if (row.CustomerName is { Length: 0 })
            {
                row.CustomerNo = customerNo;
                row.CustomerName = customerName;
            }
        }

        return rows;
    }

    /// <summary>
    /// 寫一個分頁：A 欄是列序號，其餘照 <paramref name="cols"/>；同一群組的相鄰列共用一個
    /// 群組序號，偶數群組整列上斑馬紋底色。
    /// 有版型時表頭、欄寬、數字格式都照版型，資料從版型表頭的下一列開始寫。
    /// </summary>
    private static void WriteSheet(
        XLWorkbook workbook, XlsFormatTemplate template, string sheetName, IReadOnlyList<ColSpec> cols,
        IEnumerable<CopSalesOrder> rows, Func<CopSalesOrder, string> groupKey)
    {
        var ws = workbook.AddWorksheet(sheetName);

        var headerRows = template.Apply(ws, sheetName);
        var templated = headerRows > 0;
        if (!templated)
        {
            ws.Cell(1, 1).Value = "序號";
            for (var i = 0; i < cols.Count; i++)
            {
                ws.Cell(1, i + 2).Value = cols[i].Header;
                if (cols[i].Format is { } format) ws.Column(i + 2).Style.NumberFormat.Format = format;
            }
            headerRows = 1;
        }

        var y = headerRows + 1;
        var sno = 1;
        var groupIndex = 0;
        string? curKey = null;

        foreach (var row in rows)
        {
            ws.Cell(y, 1).Value = sno++;
            for (var i = 0; i < cols.Count; i++) ws.Cell(y, i + 2).Value = cols[i].Value(row);

            var key = groupKey(row);
            if (curKey != key)
            {
                curKey = key;
                groupIndex++;
            }
            if (groupIndex % 2 == 0) ws.Row(y).Style.Fill.BackgroundColor = ZebraColor;

            y++;
        }

        if (!templated) ws.Columns().AdjustToContents();
        ws.Range(headerRows, 1, Math.Max(y - 1, headerRows), cols.Count + 1).SetAutoFilter();
    }

    /// <summary>品號細項（無金額權限時砍掉單價／幣別／匯率／台幣各欄）。</summary>
    private static List<ColSpec> ProductDetailCols(bool showAmount) => SalesOrderDetailCols(showAmount);

    /// <summary>
    /// 銷貨單細項。品號細項用的是同一組欄位——1.0 的 PUR_XlsFileFormat 裡這兩個分頁的
    /// 表頭逐欄相同，差別只在資料來源分別是兩支 SP。
    /// </summary>
    private static List<ColSpec> SalesOrderDetailCols(bool showAmount)
    {
        var cols = new List<ColSpec>
        {
            new("客戶代號", r => Text(r.CustomerNo)),
            new("客戶名稱", r => Text(r.CustomerName)),
            new("銷貨單別", r => Text(r.Th001)),
            new("銷貨單號", r => Text(r.Th002)),
            new("銷貨序號", r => Text(r.Th003)),
            new("品號", r => Text(r.Th004)),
            new("品名", r => Text(r.Th005)),
            new("規格", r => Text(r.Th006)),
            new("單位", r => Text(r.Th009)),
            new("倉別", r => Text(r.Th007)),
            new("數量", r => Num(r.Th008), QtyFormat)
        };

        if (showAmount)
        {
            cols.AddRange(
            [
                new ColSpec("單價", r => Num(r.Th012), MoneyFormat),
                new ColSpec("數量*單價", r => Num(r.Th013), MoneyFormat),
                new ColSpec("幣別", r => Text(r.Tg011)),
                new ColSpec("匯率", r => Num(r.Tg012)),
                new ColSpec("台幣未稅金額", r => Num(r.Th037), MoneyFormat),
                new ColSpec("台幣稅額", r => Num(r.Th038), MoneyFormat),
                new ColSpec("台幣總額", r => Num(r.SumAmt), MoneyFormat)
            ]);
        }

        cols.AddRange(
        [
            new ColSpec("訂單單別", r => Text(r.Th014)),
            new ColSpec("訂單單號", r => Text(r.Th015)),
            new ColSpec("訂單序號", r => Text(r.Th016)),
            new ColSpec("序號", r => Text(r.SerialNosJson)),
            new ColSpec("製令單別", r => Text(r.Ta001)),
            new ColSpec("製令單號", r => Text(r.Ta002)),
            new ColSpec("計畫批號", r => Text(r.PlanNumber))
        ]);

        return cols;
    }

    /// <summary>品號統計：一個品號一列。</summary>
    private static List<ColSpec> ProductGroupCols(bool showAmount)
    {
        var cols = new List<ColSpec>
        {
            new("品號", r => Text(r.Th004)),
            new("品名", r => Text(r.Th005)),
            new("規格", r => Text(r.Th006)),
            new("單位", r => Text(r.Th009)),
            new("數量", r => Num(r.SumQty), QtyFormat)
        };

        if (showAmount) cols.Add(new ColSpec("台幣總額", r => Num(r.SumAmt), MoneyFormat));

        return cols;
    }

    /// <summary>銷貨單統計：一張銷貨單一列。</summary>
    private static List<ColSpec> SalesOrderGroupCols(bool showAmount)
    {
        var cols = new List<ColSpec>
        {
            new("客戶代號", r => Text(r.CustomerNo)),
            new("客戶名稱", r => Text(r.CustomerName)),
            new("銷貨單別", r => Text(r.Th001)),
            new("銷貨單號", r => Text(r.Th002)),
            new("數量", r => Num(r.SumQty), QtyFormat)
        };

        if (showAmount) cols.Add(new ColSpec("台幣總額", r => Num(r.SumAmt), MoneyFormat));

        return cols;
    }
}
