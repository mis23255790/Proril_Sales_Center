using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Proril.SalesIssue.Api.Controllers.Shared;
using Proril.SalesIssue.Api.Filters;
using Proril.SalesIssue.Api.Data;
using Proril.SalesIssue.Api.Helpers;
using Proril.SalesIssue.Api.Models;
using CopSalesOrder = Proril.SalesIssue.Api.Data.SalesCenter.CopSalesOrder;

namespace Proril.SalesIssue.Api.Controllers.SalesSearch;

/// <summary>
/// 銷貨檢索（1.0 Mix/SalesShipping 的 MixSalesShipApi）。端點名稱與參數大小寫刻意與 1.0
/// 一字不差，前端只要改 <c>NUXT_PUBLIC_API_BASE</c> 就能切過來。
///
/// 查詢本身全部由預存程序完成（<c>prc_QuerySalesOrder</c> 依品號分群、
/// <c>prc_QuerySalesOrder_1</c> 依銷貨單分群），Controller 只負責把參數傳進去、
/// 把結果集原樣回傳。兩支 SP 進來的第一件事都是 <c>EXEC prc_ImportSalesOrder</c>，
/// 從鼎新 ERP 增量補齊 <c>COP_SalesOrder</c>，所以查詢本身會寫資料——不是純讀。
///
/// **只搬銷貨檢索這一頁會用到的三支端點**（GetSalesOrder / GetSalesOrder_1 / ExportXls）。
/// 1.0 同一支 controller 底下還有 GetCOPOrder（全表查詢，畫面上沒入口）、
/// GetFinalQuotation / ExportCustomerPrice（報價）、GetSalesTotal / GetCustomerCredit /
/// GetCustomerCreditCRM / GetCustomerOrderTotal / GetCustomerUnfinOrder（客戶相關頁籤），
/// 那些屬於別的模組，2.0 前端目前也沒有呼叫，不在這次搬移範圍。
/// 2.0 另外加了後端分頁用的 GetSalesOrderPage（見 MixSalesShipApiController.Paged.cs）。
/// </summary>
[Authorize]
[RequirePermission(PermissionKeys.SalesSearch.MixSalesShipping)]
public partial class MixSalesShipApiController : BaseApiController
{
    public MixSalesShipApiController(
        Data.SalesCenter.SalesCenterDbContext scDb,
        JwtHelper jwtHelper,
        StoragePaths paths,
        IMemoryCache cache,
        DbContextOptions<Data.SalesCenter.SalesCenterDbContext> scDbOptions,
        ILogger<MixSalesShipApiController> logger) : base(scDb, jwtHelper, logger)
    {
        _paths = paths;
        _cache = cache;
        _scDbOptions = scDbOptions;
    }

    private readonly StoragePaths _paths;
    private readonly IMemoryCache _cache;
    private readonly DbContextOptions<Data.SalesCenter.SalesCenterDbContext> _scDbOptions;

    /// <summary>
    /// SP 內部會先跑 prc_ImportSalesOrder 從 ERP linked server 拉資料，30 秒的預設逾時不夠。
    /// 1.0 是 <c>SetCommandTimeout(120)</c>，照搬。
    /// </summary>
    private const int SpCommandTimeoutSeconds = 120;

    /// <summary>依品號（TH004）分群的查詢，餵給「品號細項」「品號統計」兩個頁籤。</summary>
    [HttpGet]
    public CustomApiViewModel GetSalesOrder(
        string? customerNo, string? productType, string? productNo, string? productName, string? productSpec,
        string? startDate, string? endDate, string? serialNo, string? poNo, string? inPlanNumber,
        string? groupName, string? groupDesc)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(GetSalesOrder), $"customerNo:{customerNo}, productType:{productType}, groupName:{groupName}");

        var showAmount = HasPermission(PermissionKeys.SalesSearch.MixSalesShippingViewAmount);

        ca.IsSuccess = true;
        ca.Body = MaskAmounts(QueryByProduct(customerNo, productType, productNo, productName, productSpec,
            startDate, endDate, serialNo, poNo, inPlanNumber, groupName, groupDesc), showAmount);
        return ca;
    }

    /// <summary>
    /// 依銷貨單（TH001 + TH002）分群的查詢，餵給「銷貨單細項」「銷貨單統計」兩個頁籤，
    /// 兩個明細 modal 也是打這支（帶 <paramref name="OrderType"/>／<paramref name="OrderNo"/>
    /// 篩到單一張銷貨單）。
    ///
    /// 參數大小寫沿用 1.0（<c>OrderType</c>／<c>OrderNo</c> 是大寫開頭，其餘小寫開頭），
    /// 不要順手改成 camelCase——前端 query string 是照這個拼的。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel GetSalesOrder_1(
        string? customerNo, string? productType, string? productNo, string? productName, string? productSpec,
        string? startDate, string? endDate, string? serialNo, string? poNo,
        string? OrderType, string? OrderNo, string? inPlanNumber,
        string? groupName, string? groupDesc)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(GetSalesOrder_1), $"customerNo:{customerNo}, orderType:{OrderType}, orderNo:{OrderNo}, groupName:{groupName}");

        var showAmount = HasPermission(PermissionKeys.SalesSearch.MixSalesShippingViewAmount);

        ca.IsSuccess = true;
        ca.Body = MaskAmounts(QueryBySalesOrder(customerNo, productType, productNo, productName, productSpec,
            startDate, endDate, serialNo, poNo, OrderType, OrderNo, inPlanNumber, groupName, groupDesc), showAmount);
        return ca;
    }

    /// <summary>
    /// 沒有 viewAmount 權限時把金額相關欄位清成 null。權限不足時後端也清掉金額，不只靠前端隱藏欄位
    /// （直接打 API 一樣看不到）。清的欄位與 <see cref="SalesOrderDetailCols"/> 在 showAmount=false
    /// 時拿掉的那組一致：單價、數量*單價、幣別、匯率、台幣未稅、台幣稅額、台幣總額。
    /// </summary>
    private static List<CopSalesOrder> MaskAmounts(List<CopSalesOrder> rows, bool showAmount)
    {
        if (showAmount) return rows;

        foreach (var row in rows)
        {
            row.Th012 = null;
            row.Th013 = null;
            row.Tg011 = null;
            row.Tg012 = null;
            row.Th037 = null;
            row.Th038 = null;
            row.SumAmt = null;
        }

        return rows;
    }

    /// <summary>
    /// <c>EXEC prc_QuerySalesOrder</c>（依品號分群）。
    ///
    /// **與 1.0 的差異**：改用 <c>FromSqlInterpolated</c> 讓 EF 自己參數化。1.0 是直接把
    /// 使用者輸入串進 SQL 字串再 <c>FromSql</c>，有 SQL injection 風險。
    /// SP 內部還是會把這些值再串成動態 SQL（那是 SP 自己的事，不改資料庫），
    /// 但至少 Controller 這一層不再是拼字串。
    ///
    /// <paramref name="db"/> 不傳就用 request 的 <c>scDb</c>；GetSalesOrderPage 要兩支 SP 平行跑，
    /// DbContext 不能跨執行緒共用，那邊會各自 new 一個傳進來。
    ///
    /// <paramref name="skipImport"/> = true 時 SP 不跑 <c>prc_ImportSalesOrder</c>（<c>@SkipImport = 1</c>），
    /// 呼叫端要自己先跑過 <see cref="ImportSalesOrderAsync"/>。
    /// </summary>
    private List<CopSalesOrder> QueryByProduct(
        string? customerNo, string? productType, string? productNo, string? productName, string? productSpec,
        string? startDate, string? endDate, string? serialNo, string? poNo, string? inPlanNumber,
        string? groupName, string? groupDesc, Data.SalesCenter.SalesCenterDbContext? db = null, bool skipImport = false)
    {
        db ??= scDb;
        db.Database.SetCommandTimeout(SpCommandTimeoutSeconds);

        return db.CopSalesOrders
            .FromSqlInterpolated($@"EXEC prc_QuerySalesOrder
                {customerNo ?? ""}, {productType ?? ""}, {productNo ?? ""}, {productName ?? ""}, {productSpec ?? ""},
                {startDate ?? ""}, {endDate ?? ""},
                {serialNo ?? ""}, {poNo ?? ""}, {inPlanNumber ?? ""}, {groupName ?? ""}, {groupDesc ?? ""},
                {skipImport}")
            .AsNoTracking()
            .ToList();
    }

    /// <summary><c>EXEC prc_QuerySalesOrder_1</c>（依銷貨單分群）。<paramref name="db"/>／<paramref name="skipImport"/> 同上，見 <see cref="QueryByProduct"/>。</summary>
    private List<CopSalesOrder> QueryBySalesOrder(
        string? customerNo, string? productType, string? productNo, string? productName, string? productSpec,
        string? startDate, string? endDate, string? serialNo, string? poNo,
        string? orderType, string? orderNo, string? inPlanNumber,
        string? groupName, string? groupDesc, Data.SalesCenter.SalesCenterDbContext? db = null, bool skipImport = false)
    {
        db ??= scDb;
        db.Database.SetCommandTimeout(SpCommandTimeoutSeconds);

        return db.CopSalesOrders
            .FromSqlInterpolated($@"EXEC prc_QuerySalesOrder_1
                {customerNo ?? ""}, {productType ?? ""}, {productNo ?? ""}, {productName ?? ""}, {productSpec ?? ""},
                {startDate ?? ""}, {endDate ?? ""},
                {serialNo ?? ""}, {poNo ?? ""}, {orderType ?? ""}, {orderNo ?? ""}, {inPlanNumber ?? ""},
                {groupName ?? ""}, {groupDesc ?? ""}, {skipImport}")
            .AsNoTracking()
            .ToList();
    }

    /// <summary>
    /// 單獨跑一次 <c>prc_ImportSalesOrder</c>（從 ERP 增量補 <c>COP_SalesOrder</c>）。
    /// 給要連跑兩支查詢 SP 的地方用：先匯入一次，兩支再帶 <c>skipImport: true</c>，
    /// 不然兩支各匯入一次、還會在 <c>COP_SalesOrder</c> 的鎖上互等。
    /// </summary>
    private async Task ImportSalesOrderAsync(Data.SalesCenter.SalesCenterDbContext? db = null)
    {
        db ??= scDb;
        db.Database.SetCommandTimeout(SpCommandTimeoutSeconds);
        await db.Database.ExecuteSqlRawAsync("DECLARE @ret varchar(50); EXEC prc_ImportSalesOrder 'system', @ret OUTPUT;");
    }
}
