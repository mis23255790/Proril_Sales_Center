using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Proril.SalesIssue.Api.Data;
using Proril.SalesIssue.Api.Helpers;
using Proril.SalesIssue.Api.Models;

namespace Proril.SalesIssue.Api.Controllers.Shared;

/// <summary>
/// 客戶查詢。議題編輯頁的「客戶別」下拉就是打這支。
/// </summary>
[Authorize]
public class CustomQueryApiController : BaseApiController
{
    public CustomQueryApiController(
        SalesIssueDbContext db,
        JwtHelper jwtHelper,
        ILogger<CustomQueryApiController> logger) : base(db, jwtHelper, logger)
    {
    }

    /// <summary>
    /// 客戶清單（含 ERP 對照名稱）。
    ///
    /// includeErpCustom = false 時排除「已經在 ERP 裡的客戶」，只留純 CRM 的潛在客戶。
    /// V_ERPCustomer 是唯讀 View，所以比對前兩邊都要 Trim：
    /// ERP 同步進來的編號常帶尾端空白，而這裡是 LINQ to Objects，
    /// 不像 SQL 的 = 會自動忽略尾端空白。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel GetCustom(string? customNo, string? erpCustomNo, bool includeErpCustom)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };
        try
        {
            WriteStepLog(nameof(GetCustom), $"customNo:{customNo}, erpCustomNo:{erpCustomNo}, includeErp:{includeErpCustom}");

            var customers = db.CrmCustomers.Where(c => c.AStatus == ActiveStatus.Active).ToList();
            var erpCustomers = db.VErpcustomers.ToList();

            var erpByNo = erpCustomers
                .GroupBy(e => (e.Ma001 ?? "").Trim())
                .ToDictionary(g => g.Key, g => g.First());

            var list = customers.Select(c =>
            {
                erpByNo.TryGetValue((c.ErpcustomerNo ?? "").Trim(), out var erp);
                return new CrmCustomerViewModel(c)
                {
                    ERPCustomShortName = erp?.Ma002 ?? "",
                    ERPCustomLongName = erp?.Ma003 ?? ""
                };
            }).ToList();

            if (!string.IsNullOrWhiteSpace(customNo))
            {
                var target = customNo.Trim();
                list = list.Where(c => (c.CustomerNo ?? "").Trim() == target).ToList();
            }

            if (!string.IsNullOrWhiteSpace(erpCustomNo))
            {
                var target = erpCustomNo.Trim();
                list = list.Where(c => (c.ErpcustomerNo ?? "").Trim() == target).ToList();
            }

            if (!includeErpCustom)
            {
                list = list.Where(c => !erpByNo.ContainsKey((c.ErpcustomerNo ?? "").Trim())).ToList();
            }

            ca.IsSuccess = true;
            ca.Body = list.OrderBy(c => c.LongName).ToList();
            return ca;
        }
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            ca.Message = ex.InnerException?.Message ?? ex.Message;
        }
        return ca;
    }
}
