using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Proril.SalesIssue.Api.Controllers.Shared;
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
/// </summary>
[Authorize]
public partial class MixSalesShipApiController : BaseApiController
{
    public MixSalesShipApiController(
        // ProrilWebDbContext db,
        Data.SalesCenter.SalesCenterDbContext scDb,
        JwtHelper jwtHelper,
        StoragePaths paths,
        ILogger<MixSalesShipApiController> logger) : base(scDb, jwtHelper, logger)
    {
        _paths = paths;
    }

    private readonly StoragePaths _paths;

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

        ca.IsSuccess = true;
        ca.Body = QueryByProduct(customerNo, productType, productNo, productName, productSpec,
            startDate, endDate, serialNo, poNo, inPlanNumber, groupName, groupDesc);
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

        ca.IsSuccess = true;
        ca.Body = QueryBySalesOrder(customerNo, productType, productNo, productName, productSpec,
            startDate, endDate, serialNo, poNo, OrderType, OrderNo, inPlanNumber, groupName, groupDesc);
        return ca;
    }

    /// <summary>
    /// <c>EXEC prc_QuerySalesOrder</c>（依品號分群）。
    ///
    /// **與 1.0 的差異**：改用 <c>FromSqlInterpolated</c> 讓 EF 自己參數化。1.0 是直接把
    /// 使用者輸入串進 SQL 字串再 <c>FromSql</c>，有 SQL injection 風險。
    /// SP 內部還是會把這些值再串成動態 SQL（那是 SP 自己的事，不改資料庫），
    /// 但至少 Controller 這一層不再是拼字串。
    /// </summary>
    private List<CopSalesOrder> QueryByProduct(
        string? customerNo, string? productType, string? productNo, string? productName, string? productSpec,
        string? startDate, string? endDate, string? serialNo, string? poNo, string? inPlanNumber,
        string? groupName, string? groupDesc)
    {
        scDb.Database.SetCommandTimeout(SpCommandTimeoutSeconds);

        return scDb.CopSalesOrders
            .FromSqlInterpolated($@"EXEC prc_QuerySalesOrder
                {customerNo ?? ""}, {productType ?? ""}, {productNo ?? ""}, {productName ?? ""}, {productSpec ?? ""},
                {startDate ?? ""}, {endDate ?? ""},
                {serialNo ?? ""}, {poNo ?? ""}, {inPlanNumber ?? ""}, {groupName ?? ""}, {groupDesc ?? ""}")
            .AsNoTracking()
            .ToList();
    }

    /// <summary><c>EXEC prc_QuerySalesOrder_1</c>（依銷貨單分群）。</summary>
    private List<CopSalesOrder> QueryBySalesOrder(
        string? customerNo, string? productType, string? productNo, string? productName, string? productSpec,
        string? startDate, string? endDate, string? serialNo, string? poNo,
        string? orderType, string? orderNo, string? inPlanNumber,
        string? groupName, string? groupDesc)
    {
        scDb.Database.SetCommandTimeout(SpCommandTimeoutSeconds);

        return scDb.CopSalesOrders
            .FromSqlInterpolated($@"EXEC prc_QuerySalesOrder_1
                {customerNo ?? ""}, {productType ?? ""}, {productNo ?? ""}, {productName ?? ""}, {productSpec ?? ""},
                {startDate ?? ""}, {endDate ?? ""},
                {serialNo ?? ""}, {poNo ?? ""}, {orderType ?? ""}, {orderNo ?? ""}, {inPlanNumber ?? ""},
                {groupName ?? ""}, {groupDesc ?? ""}")
            .AsNoTracking()
            .ToList();
    }
}
