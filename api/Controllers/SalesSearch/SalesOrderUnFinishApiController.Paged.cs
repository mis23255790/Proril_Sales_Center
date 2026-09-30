using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Caching.Memory;
using Proril.SalesIssue.Api.Data;
using Proril.SalesIssue.Api.Data.SalesCenter;
using Proril.SalesIssue.Api.Models;

namespace Proril.SalesIssue.Api.Controllers.SalesSearch;

/*
 * 未完成訂單檢索的後端分頁（2.0 新增，1.0 沒有這支）。
 *
 * prc_QueryUnfinOrder(_1) 背後的 V_UnfinOrder 沒有落地快取表，每次都直接打 ERP linked server，
 * 「每次翻頁就重跑 SP」代價太高，所以這裡把兩支 SP 的結果（已套用 orderType 過濾、
 * 銘版序號、金額遮罩）放進 IMemoryCache，翻頁／切頁籤只從快取切出那一頁。
 * 資料庫與 ERP 的負載跟改之前一樣（一次查詢跑兩支 SP），省的是傳輸量與瀏覽器記憶體。
 *
 * GetUnfinOrder / QueryUnfinOrder_1 維持 1.0 的一次全撈，兩個明細 modal 與 1.0 相容性都還靠它們。
 */
public partial class SalesOrderUnFinishApiController
{
    /// <summary>快取時間；過期後翻頁會自動重跑 SP，不會出錯，只是那一次比較慢。</summary>
    private static readonly TimeSpan PageCacheDuration = TimeSpan.FromMinutes(10);

    private sealed record UnfinOrderQueryResult(List<UnfinOrder> ProductRows, List<UnfinOrder> SoRows);

    /// <summary>
    /// 四個頁籤共用的分頁查詢。<paramref name="tab"/> = productDetail / productGroup /
    /// soDetail / soGroup；品號兩個頁籤取 prc_QueryUnfinOrder（TD004），訂單兩個頁籤取
    /// prc_QueryUnfinOrder_1（TC001），細項取 FooterFlag != Y、統計取 FooterFlag != N
    /// （原本在前端 app/utils/salesOrderUnfinish.ts 做，搬到這裡）。
    ///
    /// <paramref name="refresh"/> = true（按查詢／重設）一定重跑兩支 SP 並覆蓋快取；
    /// false（翻頁、切頁籤、切每頁筆數）有快取就直接用。快取 key 是全部查詢條件 + 有沒有金額權限，
    /// 前端翻頁時必須送「上次按查詢時」的條件，不是畫面上改到一半的條件。
    /// <paramref name="pageIndex"/> 從 0 起算，<paramref name="pageSize"/> &lt;= 0 代表不分頁。
    /// </summary>
    [HttpGet]
    public async Task<CustomApiViewModel> GetUnfinOrderPage(
        string? inCopSource, string? inCustomerNo, string? productType, string? productNo, string? productName,
        string? productSpec, string? startDate, string? endDate, string? deliveryStartDate, string? deliveryEndDate,
        string? serialNo, string? poNo, string? orderType, string? inPlanNumber,
        string? tab, int pageIndex = 0, int pageSize = 20, bool refresh = false)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(GetUnfinOrderPage),
            $"tab:{tab}, pageIndex:{pageIndex}, pageSize:{pageSize}, refresh:{refresh}, productNo:{productNo}, poNo:{poNo}");

        var showAmount = HasPermission(PermissionKeys.SalesSearch.QueryUnFinishViewAmount);

        var cacheKey = string.Join('\u001f', "UnfinOrderPage", showAmount,
            inCopSource, inCustomerNo, productType, productNo, productName, productSpec,
            startDate, endDate, deliveryStartDate, deliveryEndDate, serialNo, poNo, orderType, inPlanNumber);

        if (refresh || !_cache.TryGetValue(cacheKey, out UnfinOrderQueryResult? result) || result is null)
        {
            result = await QueryBoth(inCopSource, inCustomerNo, productType, productNo, productName, productSpec,
                startDate, endDate, deliveryStartDate, deliveryEndDate, serialNo, poNo, orderType, inPlanNumber, showAmount);
            _cache.Set(cacheKey, result, PageCacheDuration);
        }

        var productDetail = result.ProductRows.Where(x => x.FooterFlag != "Y").ToList();
        var productGroup = result.ProductRows.Where(x => x.FooterFlag != "N").ToList();
        var soDetail = result.SoRows.Where(x => x.FooterFlag != "Y").ToList();
        var soGroup = result.SoRows.Where(x => x.FooterFlag != "N").ToList();

        var rows = tab switch
        {
            "productDetail" => productDetail,
            "productGroup" => productGroup,
            "soDetail" => soDetail,
            "soGroup" => soGroup,
            _ => null
        };
        if (rows is null)
        {
            ca.Message = $"tab 只能是 productDetail / productGroup / soDetail / soGroup，目前是「{tab}」";
            return ca;
        }

        ca.IsSuccess = true;
        ca.Body = pageSize <= 0
            ? rows
            : rows.Skip(Math.Max(pageIndex, 0) * pageSize).Take(pageSize).ToList();
        ca.Body2 = new UnfinOrderPageSummary
        {
            TotalCount = rows.Count,
            ProductDetailCount = productDetail.Count,
            ProductGroupCount = productGroup.Count,
            SoDetailCount = soDetail.Count,
            SoGroupCount = soGroup.Count,
            TotalAmount = productDetail.Sum(x => x.Ntd ?? 0)
        };
        return ca;
    }

    /// <summary>
    /// 兩支 SP 平行跑（改之前前端也是 Promise.all 同時打兩支，第一次查詢的等待時間不變）。
    /// DbContext 不能跨執行緒共用，各自 new 一個；銘版序號與金額遮罩等兩邊都回來才做。
    /// </summary>
    private async Task<UnfinOrderQueryResult> QueryBoth(
        string? inCopSource, string? inCustomerNo, string? productType, string? productNo, string? productName,
        string? productSpec, string? startDate, string? endDate, string? deliveryStartDate, string? deliveryEndDate,
        string? serialNo, string? poNo, string? orderType, string? inPlanNumber, bool showAmount)
    {
        await using var productDb = new SalesCenterDbContext(_scDbOptions);
        await using var soDb = new SalesCenterDbContext(_scDbOptions);

        var productTask = Task.Run(() => CallQueryUnfinOrder(inCopSource, inCustomerNo, productType, productNo, productName,
            productSpec, startDate, endDate, deliveryStartDate, deliveryEndDate, serialNo, poNo, inPlanNumber, "TD004", "", productDb));
        var soTask = Task.Run(() => CallQueryUnfinOrder1(inCopSource, inCustomerNo, productType, productNo, productName,
            productSpec, startDate, endDate, deliveryStartDate, deliveryEndDate, serialNo, poNo, inPlanNumber, "TC001", "", soDb));
        await Task.WhenAll(productTask, soTask);

        return new UnfinOrderQueryResult(
            MaskAmounts(ApplySerialNos(FilterByOrderType(productTask.Result, orderType)), showAmount),
            MaskAmounts(ApplySerialNos(FilterByOrderType(soTask.Result, orderType)), showAmount));
    }
}
