using ClosedXML.Excel;
using Microsoft.AspNetCore.Mvc;
using Proril.SalesIssue.Api.Data;
using Proril.SalesIssue.Api.Models;

namespace Proril.SalesIssue.Api.Controllers.SalesSearch;

/*
 * 未完成訂單檢索的 Excel 匯出。
 *
 * 1.0 的欄位配置（表頭文字、欄寬、數字格式、分頁名稱）是讀 PUR_XlsFileFormat 資料表
 * （FunctionNo=420）動態組出來的，那套通用格式引擎（XlsFormatterApis）是給多個還沒搬的
 * 模組共用的排版基礎設施，只為這一個匯出去搬整套 DB 驅動格式系統不成比例。這裡比照
 * MixSalesShipApiController.Xls.cs / OrderInfoVerifyApiController.Xls.cs 的作法，把欄位
 * 配置寫死在 C#——表頭文字、欄位順序與頁面上四個頁籤的表格逐欄對齊
 * （app/pages/sales-center/sales-search/unfinished-orders.vue 的 DETAIL_COLS_BASE /
 * PRODUCT_GROUP_COLS / SO_GROUP_COLS），欄寬改成 AdjustToContents()，
 * 不再照抄 DB 裡那組固定欄寬，這是與 1.0 已知的唯一外觀差異。
 */
public partial class SalesOrderUnFinishApiController
{
    /// <summary>M_Permission.LinkType，未完成訂單金額欄位的權限碼（跟銷貨檢索的 100 相同，
    /// 但 FunctionNo 不同，兩個功能各自獨立判斷）。</summary>
    private const int AmountLinkType = 100;

    private const string QtyFormat = @"_-* #,##0_-;\-* #,##0_-;_-* ""-""_-;_-@_-";
    private const string MoneyFormat = @"_-""$""* #,##0_-;\-""$""* #,##0_-;_-""$""* ""-""_-;_-@_-";

    /// <summary>斑馬紋底色，1.0 的 XLColor.FromArgb(0xe2e3e5)。</summary>
    private static readonly XLColor ZebraColor = XLColor.FromArgb(0xe2, 0xe3, 0xe5);

    /// <summary>一個欄位：表頭文字、取值、數字格式（null 表示不套）。</summary>
    private sealed record ColSpec(string Header, Func<UnfinOrder, XLCellValue> Value, string? Format = null);

    private static XLCellValue Text(string? v) => v ?? "";
    private static XLCellValue Num(decimal? v) => v.HasValue ? v.Value : Blank.Value;

    /// <summary>
    /// 匯出四個分頁：品號細項／品號統計／訂單細項／訂單統計。
    ///
    /// 前兩頁的資料來源是 <c>prc_QueryUnfinOrder</c>（固定用 TD004 分群），後兩頁是
    /// <c>prc_QueryUnfinOrder_1</c>（固定用 TC001 分群）——不管呼叫端送什麼 groupName，
    /// 匯出一律兩種分群各跑一次，1.0 也是這樣（<c>getProductInfo</c>/<c>getSalesOrder</c>
    /// 內部寫死 group_name，忽略傳進來的 groupName）。
    ///
    /// **與 1.0 的差異**：舊版 <c>onExportCopXls()</c> 呼叫 <c>API_ExportXls</c> 時參數位置
    /// 對錯（<c>inPlanNumber</c> 的值落到 <c>orderType</c> 的參數槽），2.0 前端改用具名參數
    /// 呼叫，這裡收到的參數就不會有那個既有 bug。
    ///
    /// 回傳的 <c>Body</c> 是相對於 ShareRoot 的路徑，前端要補 <c>/ShareRoot/</c> 前綴
    /// 再走 Nuxt 的 <c>server/api/download.get.ts</c> 下載。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel ExportXls(
        string? inCopSource, string? inCustomerNo, string? productType, string? productNo, string? productName,
        string? productSpec, string? startDate, string? endDate, string? deliveryStartDate, string? deliveryEndDate,
        string? serialNo, string? poNo, string? orderType, string? orderNo, string? inPlanNumber,
        string? groupName, string? groupDesc)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(ExportXls), $"productNo:{productNo}, orderType:{orderType}");

        var productInfo = FilterByOrderType(
            CallQueryUnfinOrder(inCopSource, inCustomerNo, productType, productNo, productName, productSpec,
                startDate, endDate, deliveryStartDate, deliveryEndDate, serialNo, poNo, inPlanNumber, "TD004", groupDesc),
            orderType);
        var salesOrders = FilterByOrderType(
            CallQueryUnfinOrder1(inCopSource, inCustomerNo, productType, productNo, productName, productSpec,
                startDate, endDate, deliveryStartDate, deliveryEndDate, serialNo, poNo, inPlanNumber, "TC001", groupDesc),
            orderType);

        if (productInfo.Count == 0 && salesOrders.Count == 0)
        {
            ca.Message = "查無資料可匯出!!!";
            return ca;
        }

        var account = GetAccountByToken();
        var showAmount = HasAmountPermission(account);

        using var workbook = new XLWorkbook();
        // 細項頁取「非 Y」（N + S + T），統計頁取「非 N」（S + Y + T），與畫面上的頁籤一致。
        WriteSheet(workbook, "品號細項", DetailCols(showAmount, includeGiftQty: false),
            productInfo.Where(r => r.FooterFlag != "Y"), GroupKeyByProduct);
        WriteSheet(workbook, "品號統計", ProductGroupCols(showAmount),
            productInfo.Where(r => r.FooterFlag != "N"), GroupKeyByProduct);
        WriteSheet(workbook, "訂單細項", DetailCols(showAmount, includeGiftQty: true),
            salesOrders.Where(r => r.FooterFlag != "Y"), GroupKeyBySalesOrder);
        WriteSheet(workbook, "訂單統計", SoGroupCols(showAmount),
            salesOrders.Where(r => r.FooterFlag != "N"), GroupKeyBySalesOrder);

        var dir = _paths.ExportDir(account);
        Directory.CreateDirectory(dir);
        var fileName = $"SOUnFin_{DateTime.Now:yyyyMMdd_HHmm}.xlsx";
        workbook.SaveAs(Path.Combine(dir, fileName));

        ca.IsSuccess = true;
        ca.Body = $"Temp/{account}/Export/{fileName}";
        return ca;
    }

    /// <summary>金額欄位權限：admin 直接放行，否則看 M_Permission 有沒有 (0320102, 100) 這一筆。</summary>
    private bool HasAmountPermission(string account)
    {
        if (scDb.MUsers.Any(u => u.Account == account && u.IsAdmin)) return true;
        return scDb.MPermissions.Any(p =>
            p.LinkNumber == account && p.FunctionNo == FunctionIds.QueryUnFinish && p.LinkType == AmountLinkType);
    }

    private static string GroupKeyByProduct(UnfinOrder r) => r.Td004 ?? "";
    private static string GroupKeyBySalesOrder(UnfinOrder r) => $"{r.Tc001}-{r.Tc002}";

    /// <summary>
    /// 寫一個分頁：A 欄是列序號，其餘照 <paramref name="cols"/>；同一群組的相鄰列共用一個
    /// 群組序號，偶數群組整列上斑馬紋底色。
    /// </summary>
    private static void WriteSheet(
        XLWorkbook workbook, string sheetName, IReadOnlyList<ColSpec> cols,
        IEnumerable<UnfinOrder> rows, Func<UnfinOrder, string> groupKey)
    {
        var ws = workbook.AddWorksheet(sheetName);

        ws.Cell(1, 1).Value = "序號";
        for (var i = 0; i < cols.Count; i++)
        {
            ws.Cell(1, i + 2).Value = cols[i].Header;
            if (cols[i].Format is { } format) ws.Column(i + 2).Style.NumberFormat.Format = format;
        }

        var y = 2;
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

        ws.Columns().AdjustToContents();
        ws.Range(1, 1, Math.Max(y - 1, 1), cols.Count + 1).SetAutoFilter();
    }

    /// <summary>
    /// 品號細項／訂單細項共用的欄位，跟頁面上 DETAIL_COLS_BASE 逐欄對齊；
    /// <paramref name="includeGiftQty"/> 為 true 時（訂單細項）在最後補一欄「贈品量」(TD024)。
    /// </summary>
    private static List<ColSpec> DetailCols(bool showAmount, bool includeGiftQty)
    {
        var cols = new List<ColSpec>
        {
            new("訂單單別", r => Text(r.Tc001)),
            new("訂單單號", r => Text(r.Tc002)),
            new("訂單序號", r => Text(r.Td003)),
            new("訂單日期", r => Text(r.Tc003)),
            new("預交日", r => Text(r.Td013)),
            new("客戶代號", r => Text(r.Tc004)),
            new("客戶名稱", r => Text(r.Ma002)),
            new("運輸方式", r => Text(r.Tc019)),
            new("品號", r => Text(r.Td004)),
            new("品名", r => Text(r.Td005)),
            new("規格", r => Text(r.Td006)),
            new("訂單數量", r => Num(r.Td008), QtyFormat),
            new("單位", r => Text(r.Td010))
        };

        if (showAmount)
        {
            cols.AddRange(
            [
                new ColSpec("原幣單價", r => Num(r.Td011), MoneyFormat),
                new ColSpec("原幣金額", r => Num(r.Td012), MoneyFormat),
                new ColSpec("幣別", r => Text(r.Tc008)),
                new ColSpec("匯率", r => Num(r.Tc009)),
                new ColSpec("台幣金額", r => Num(r.Ntd), MoneyFormat)
            ]);
        }

        cols.AddRange(
        [
            new ColSpec("計畫批號", r => Text(r.PlanNumber)),
            new ColSpec("ERP", r => Text(r.CopSource)),
            new ColSpec("單別名稱", r => Text(r.Mq002)),
            new ColSpec("業務人員", r => Text(r.Tc006)),
            new ColSpec("業務名稱", r => Text(r.Mv002)),
            new ColSpec("送貨地址", r => Text(r.Tc010))
        ]);

        if (showAmount)
        {
            cols.AddRange(
            [
                new ColSpec("付款條件", r => Text(r.Tc014)),
                new ColSpec("課稅別", r => Text(r.Tc016))
            ]);
        }

        cols.Add(new ColSpec("銘版序號", r => Text(r.SerialNosJson)));

        if (includeGiftQty) cols.Add(new ColSpec("贈品量", r => Num(r.Td024), QtyFormat));

        return cols;
    }

    /// <summary>品號統計：一個品號一列，跟頁面上 PRODUCT_GROUP_COLS 逐欄對齊。</summary>
    private static List<ColSpec> ProductGroupCols(bool showAmount)
    {
        var cols = new List<ColSpec>
        {
            new("品號", r => Text(r.Td004)),
            new("品名", r => Text(r.Td005)),
            new("規格", r => Text(r.Td006)),
            new("單位", r => Text(r.Td010)),
            new("數量", r => Num(r.Td008), QtyFormat)
        };

        if (showAmount) cols.Add(new ColSpec("台幣總額", r => Num(r.Ntd), MoneyFormat));

        return cols;
    }

    /// <summary>訂單統計：一張訂單一列，跟頁面上 SO_GROUP_COLS 逐欄對齊。</summary>
    private static List<ColSpec> SoGroupCols(bool showAmount)
    {
        var cols = new List<ColSpec>
        {
            new("訂單單別", r => Text(r.Tc001)),
            new("訂單單號", r => Text(r.Tc002)),
            new("訂單序號", r => Text(r.Td003)),
            new("訂單日期", r => Text(r.Tc003)),
            new("預交日", r => Text(r.Td013)),
            new("客戶代號", r => Text(r.Tc004)),
            new("客戶名稱", r => Text(r.Ma002)),
            new("運輸方式", r => Text(r.Tc019)),
            new("訂單數量", r => Num(r.Td008), QtyFormat)
        };

        if (showAmount) cols.Add(new ColSpec("台幣金額", r => Num(r.Ntd), MoneyFormat));

        cols.AddRange(
        [
            new ColSpec("計畫批號", r => Text(r.PlanNumber)),
            new ColSpec("ERP", r => Text(r.CopSource)),
            new ColSpec("單別名稱", r => Text(r.Mq002)),
            new ColSpec("業務人員", r => Text(r.Tc006)),
            new ColSpec("業務名稱", r => Text(r.Mv002)),
            new ColSpec("送貨地址", r => Text(r.Tc010))
        ]);

        if (showAmount)
        {
            cols.AddRange(
            [
                new ColSpec("付款條件", r => Text(r.Tc014)),
                new ColSpec("課稅別", r => Text(r.Tc016))
            ]);
        }

        return cols;
    }
}
