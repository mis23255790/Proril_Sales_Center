using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Proril.SalesIssue.Api.Controllers.Shared;
using Proril.SalesIssue.Api.Data;
using Proril.SalesIssue.Api.Helpers;
using Proril.SalesIssue.Api.Models;

namespace Proril.SalesIssue.Api.Controllers.SalesSearch;

/// <summary>
/// 未完成訂單檢索（1.0 Mix/QueryUnFinish 的 SalesOrderUnFinishApi）。端點名稱與參數大小寫
/// 刻意與 1.0 一字不差，前端只要改 <c>NUXT_PUBLIC_API_BASE</c> 就能切過來。
///
/// 查詢本身全部由預存程序完成（<c>prc_QueryUnfinOrder</c> 依品號分群、
/// <c>prc_QueryUnfinOrder_1</c> 依訂單分群），這兩支 SP repo 內找不到對應 .sql，
/// 只存在資料庫端（跟銷貨檢索的 prc_QuerySalesOrder(_1) 不同，不會順便匯入 ERP 資料，
/// 純讀）。Controller 只負責把參數傳進去、把結果集原樣回傳。
///
/// 只搬未完成訂單檢索這一頁會用到的三支端點（GetUnfinOrder / QueryUnfinOrder_1 / ExportXls）。
/// </summary>
[Authorize]
public partial class SalesOrderUnFinishApiController : BaseApiController
{
    public SalesOrderUnFinishApiController(
        ProrilWebDbContext db,
        Data.SalesCenter.SalesCenterDbContext scDb,
        JwtHelper jwtHelper,
        StoragePaths paths,
        ILogger<SalesOrderUnFinishApiController> logger) : base(db, scDb, jwtHelper, logger)
    {
        _paths = paths;
    }

    private readonly StoragePaths _paths;

    /// <summary>依品號（TD004）分群的查詢，餵給「品號細項」「品號統計」兩個頁籤。</summary>
    [HttpGet]
    public CustomApiViewModel GetUnfinOrder(
        string? inCopSource, string? inCustomerNo, string? productType, string? productNo, string? productName,
        string? productSpec, string? startDate, string? endDate, string? deliveryStartDate, string? deliveryEndDate,
        string? serialNo, string? poNo, string? orderType, string? orderNo, string? inPlanNumber,
        string? groupName, string? groupDesc)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(GetUnfinOrder), $"productNo:{productNo}, productName:{productName}, groupName:{groupName}");

        ca.IsSuccess = true;
        ca.Body = FilterByOrderType(
            CallQueryUnfinOrder(inCopSource, inCustomerNo, productType, productNo, productName, productSpec,
                startDate, endDate, deliveryStartDate, deliveryEndDate, serialNo, poNo, inPlanNumber, groupName, groupDesc),
            orderType);
        return ca;
    }

    /// <summary>
    /// 依訂單（TC001 + TC002）分群的查詢，餵給「訂單細項」「訂單統計」兩個頁籤，
    /// 「單一訂單明細」modal 也是打這支——用 <paramref name="poNo"/> 帶
    /// <c>"{訂單單別}-{訂單單號}"</c> 組合字串篩單一訂單，不是靠 <paramref name="orderType"/>/
    /// <paramref name="orderNo"/>（這點跟銷貨檢索的明細 modal 不同）。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel QueryUnfinOrder_1(
        string? inCopSource, string? inCustomerNo, string? productType, string? productNo, string? productName,
        string? productSpec, string? startDate, string? endDate, string? deliveryStartDate, string? deliveryEndDate,
        string? serialNo, string? poNo, string? orderType, string? orderNo, string? inPlanNumber,
        string? groupName, string? groupDesc)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(QueryUnfinOrder_1), $"productNo:{productNo}, poNo:{poNo}, groupName:{groupName}");

        ca.IsSuccess = true;
        ca.Body = FilterByOrderType(
            CallQueryUnfinOrder1(inCopSource, inCustomerNo, productType, productNo, productName, productSpec,
                startDate, endDate, deliveryStartDate, deliveryEndDate, serialNo, poNo, inPlanNumber, groupName, groupDesc),
            orderType);
        return ca;
    }

    /// <summary>
    /// <c>EXEC prc_QueryUnfinOrder</c>。
    ///
    /// **與 1.0 的差異**：改用 <c>FromSqlInterpolated</c> 讓 EF 自己參數化，不再是拼字串
    /// 直接 <c>FromSql</c>（有 SQL injection 風險）。SP 內部仍會把值再組成動態 SQL，
    /// 那是 SP 自己的事，不改資料庫。
    /// </summary>
    private List<UnfinOrder> CallQueryUnfinOrder(
        string? inCopSource, string? inCustomerNo, string? productType, string? productNo, string? productName,
        string? productSpec, string? startDate, string? endDate, string? deliveryStartDate, string? deliveryEndDate,
        string? serialNo, string? poNo, string? inPlanNumber, string? groupName, string? groupDesc)
    {
        return db.Set<UnfinOrder>()
            .FromSqlInterpolated($@"EXEC prc_QueryUnfinOrder
                {inCopSource ?? ""}, {inCustomerNo ?? ""}, {productType ?? ""}, {productNo ?? ""}, {productName ?? ""}, {productSpec ?? ""},
                {startDate ?? ""}, {endDate ?? ""}, {deliveryStartDate ?? ""}, {deliveryEndDate ?? ""},
                {serialNo ?? ""}, {poNo ?? ""}, {inPlanNumber ?? ""}, {groupName ?? ""}, {groupDesc ?? ""}")
            .AsNoTracking()
            .ToList();
    }

    /// <summary><c>EXEC prc_QueryUnfinOrder_1</c>。</summary>
    private List<UnfinOrder> CallQueryUnfinOrder1(
        string? inCopSource, string? inCustomerNo, string? productType, string? productNo, string? productName,
        string? productSpec, string? startDate, string? endDate, string? deliveryStartDate, string? deliveryEndDate,
        string? serialNo, string? poNo, string? inPlanNumber, string? groupName, string? groupDesc)
    {
        return db.Set<UnfinOrder>()
            .FromSqlInterpolated($@"EXEC prc_QueryUnfinOrder_1
                {inCopSource ?? ""}, {inCustomerNo ?? ""}, {productType ?? ""}, {productNo ?? ""}, {productName ?? ""}, {productSpec ?? ""},
                {startDate ?? ""}, {endDate ?? ""}, {deliveryStartDate ?? ""}, {deliveryEndDate ?? ""},
                {serialNo ?? ""}, {poNo ?? ""}, {inPlanNumber ?? ""}, {groupName ?? ""}, {groupDesc ?? ""}")
            .AsNoTracking()
            .ToList();
    }

    /// <summary>
    /// <c>prc_QueryUnfinOrder(_1)</c> 沒有 orderType 參數，SP 不支援按訂單單別篩選，
    /// 這裡對已查出的結果再過濾一次；小計／總計列（FooterFlag=Y）一律保留，只濾明細/統計列。
    /// </summary>
    private static List<UnfinOrder> FilterByOrderType(List<UnfinOrder> rows, string? orderType)
        => string.IsNullOrWhiteSpace(orderType)
            ? rows
            : rows.Where(x => x.FooterFlag == "Y" || x.Tc001 == orderType).ToList();
}
