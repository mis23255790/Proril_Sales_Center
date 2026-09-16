using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Proril.SalesIssue.Api.Data;
using Proril.SalesIssue.Api.Models;

namespace Proril.SalesIssue.Api.Controllers.SalesSearch;

/*
 * 客戶相關資訊頁的「銷售」與「訂單」兩個頁籤，1.0 對應 MixSalesShipApiController 的
 * GetSalesTotal / GetCustomerUnfinOrder。
 *
 * 端點掛在 MixSalesShipApiController 是照 1.0 的位置（MixSalesShipApi/GetSalesTotal 等）。
 * 「信用額度」頁籤的兩支在 MixSalesShipApiController.CustomerCredit.cs。
 *
 * 兩支讀的 V_SalesTotal / V_UnfinOrder 都已經在 Proril_Sales_Center（scDb）：
 *   V_UnfinOrder   2026-09-15 隨未完成訂單檢索搬過去（SalesOrderUnfinishObjectsMigration.sql）
 *   V_SalesTotal   2026-09-16 隨這次搬過去（CustomerRelatedObjectsMigration.sql）
 *
 * **1.0 的 GetCustomerOrderTotal 沒有搬**：它的過濾條件寫反了
 * （`if (erpCustomerNo == null || erpCustomerNo.Length > 0) qry.Clear();`，
 * 應該是 `<= 0`），有帶客戶代號時反而清空、永遠回空清單；1.0 前端接收端也整段註解掉了。
 * 是完整的死碼，不搬。
 */
public partial class MixSalesShipApiController
{
    /// <summary>
    /// 客戶的年／月銷售統計（V_SalesTotal）。
    ///
    /// 用 **ERP 客戶代號**過濾——View 的 <c>CustomerNo</c> 欄位存的是 ERP 客編
    /// （來源是 COP_SalesOrder），不是內網客編。沒帶 <paramref name="erpCustomerNo"/>
    /// 直接回空清單（不是回全部），對齊 1.0：這支沒有「查全部客戶」的用途。
    ///
    /// 回傳同時混著年度總計（YM 4 碼）與單月（YM 6 碼）兩種列，由前端依長度分流。
    /// </summary>
    /// <param name="customerNo">1.0 簽章裡有這個參數，但函式本體從沒用到，維持原樣不用它。</param>
    [HttpGet]
    public CustomApiViewModel GetSalesTotal(string? customerNo, string? erpCustomerNo)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(GetSalesTotal), $"erpCustomerNo:{erpCustomerNo}");

        ca.IsSuccess = true;

        if (string.IsNullOrWhiteSpace(erpCustomerNo))
        {
            ca.Body = new List<VSalesTotal>();
            return ca;
        }

        var target = erpCustomerNo.Trim();
        ca.Body = scDb.Set<VSalesTotal>().AsNoTracking().ToList()
            .Where(s => (s.CustomerNo ?? "").Trim() == target)
            .OrderByDescending(s => s.Ym)
            .ToList();
        return ca;
    }

    /// <summary>
    /// 客戶的未完成訂單明細（V_UnfinOrder 原始列，逐筆品項）。
    ///
    /// 同樣用 **ERP 客戶代號**過濾（View 的 <c>TC004</c>），沒帶就回空清單。
    ///
    /// 這裡刻意回原始明細、不做分群：1.0 前端拿到之後自己依「單別+單號」彙總、
    /// 依品號開頭把金額分成成品(5)/零件(x) 兩欄、並濾掉 2700 詢問單，
    /// 2.0 照搬那段到 Vue 端（見 app/pages/sales-center/sales-search/customer-related.vue）。
    /// 跟未完成訂單檢索那一頁走的 prc_QueryUnfinOrder(_1) 是兩條不同路徑，不要混用。
    /// </summary>
    /// <param name="customerNo">1.0 簽章裡有這個參數，但函式本體從沒用到，維持原樣不用它。</param>
    [HttpGet]
    public CustomApiViewModel GetCustomerUnfinOrder(string? customerNo, string? erpCustomerNo)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(GetCustomerUnfinOrder), $"erpCustomerNo:{erpCustomerNo}");

        ca.IsSuccess = true;

        if (string.IsNullOrWhiteSpace(erpCustomerNo))
        {
            ca.Body = new List<VUnfinOrder>();
            return ca;
        }

        // ERP 同步進來的客戶代號常帶尾端空白，兩邊都 Trim 再比對（見 CLAUDE.md）。
        // View 每次查都直接打 ERP linked server，沒辦法在 SQL 端用 Trim 過濾後才拉回來，
        // 只能整包拉回記憶體再篩——跟 1.0 一樣。
        var target = erpCustomerNo.Trim();
        ca.Body = scDb.Set<VUnfinOrder>().AsNoTracking().ToList()
            .Where(o => (o.Tc004 ?? "").Trim() == target)
            .ToList();
        return ca;
    }
}
