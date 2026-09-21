using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Proril.SalesIssue.Api.Data;
using Proril.SalesIssue.Api.Models;

namespace Proril.SalesIssue.Api.Controllers.SalesSearch;

/*
 * 銷貨檢索頁面「客戶相關」頁籤的信用額度查詢，1.0 對應 MixSalesShipApiController 的
 * GetCustomerCredit / GetCustomerCreditCRM。
 *
 * 1.0 的作法是在方法裡 new 一個 OrderInfoVerifyApiController 出來借用它的
 * SP_GetCredit(_CRM)（controller 互相 new 是既有的耦合寫法，架在同一個 ControllerContext
 * 上才能共用 Request/User）。2.0 不跨 controller 借用，直接內聯同一支 EXEC——
 * 跟 OrderInfoVerifyApiController.SP_GetCredit(_CRM) 完全一樣的查詢，只是這裡另外
 * join V_ERPCustomer 補母公司簡稱/全名。
 *
 * 跟 OrderInfoVerifyApi.SP_GetCreditCRM 一樣，目前 2.0 前端沒有任何頁面呼叫這兩支，
 * 比照 1.0 只搬後端，先備著給之後的客戶相關頁面用。
 */
public partial class MixSalesShipApiController
{
    /// <summary>
    /// 客戶信用額度（<c>prc_COPGetCredit</c>）+ 母公司簡稱/全名。
    /// **與 1.0 的差異**：SQL 改用 <c>FromSqlInterpolated</c> 參數化，不再是字串插值。
    /// </summary>
    /// <param name="customerNo">1.0 簽章裡有這個參數，但函式本體從沒用到，維持原樣不用它。</param>
    [HttpGet]
    public CustomApiViewModel GetCustomerCredit(string? customerNo, string? erpCustomerNo)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(GetCustomerCredit), $"erpCustomerNo:{erpCustomerNo}");

        var account = GetAccountByToken();
        var credits = scDb.Set<CopGetCredit>()
            .FromSqlInterpolated($"EXEC prc_COPGetCredit {erpCustomerNo ?? ""}, {account}")
            .ToList();
        var parents = scDb.VErpcustomers.Where(v => v.Ma001 == erpCustomerNo).ToList();

        ca.IsSuccess = true;
        ca.Body = JoinParent(credits, parents, (c, p) => new CustomerCreditRow(c, p?.Ma002, p?.Ma003));
        return ca;
    }

    /// <summary>客戶信用額度（幣別分開版本，<c>prc_COPGetCredit_CRM</c>）+ 母公司簡稱/全名。</summary>
    /// <param name="customerNo">同 <see cref="GetCustomerCredit"/>，1.0 簽章有但沒用到。</param>
    [HttpGet]
    public CustomApiViewModel GetCustomerCreditCRM(string? customerNo, string? erpCustomerNo)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(GetCustomerCreditCRM), $"erpCustomerNo:{erpCustomerNo}");

        var account = GetAccountByToken();
        var credits = scDb.Set<CopGetCreditCrm>()
            .FromSqlInterpolated($"EXEC prc_COPGetCredit_CRM {erpCustomerNo ?? ""}, {account}")
            .ToList();
        var parents = scDb.VErpcustomers.Where(v => v.Ma001 == erpCustomerNo).ToList();

        ca.IsSuccess = true;
        ca.Body = JoinParent(credits, parents, (c, p) => new CustomerCreditCrmRow(c, p?.Ma002, p?.Ma003));
        return ca;
    }

    /// <summary>
    /// 1.0 是 <c>from credit in credits from parent in parents select ...</c> 的 cross join：
    /// <paramref name="parents"/> 查無資料（V_ERPCustomer 沒有這個 <c>erpCustomerNo</c>）
    /// 整批就消失，不是漏寫 left join——<c>Ma001</c> 對單一 <c>erpCustomerNo</c> 本來就
    /// 最多一筆，等同「有母公司資料才顯示」，照抄既有行為。
    /// </summary>
    private static List<TRow> JoinParent<TCredit, TRow>(
        List<TCredit> credits, List<Proril.SalesIssue.Api.Data.SalesCenter.VErpcustomer> parents,
        Func<TCredit, Proril.SalesIssue.Api.Data.SalesCenter.VErpcustomer?, TRow> selector)
        => (from credit in credits from parent in parents select selector(credit, parent)).ToList();
}
