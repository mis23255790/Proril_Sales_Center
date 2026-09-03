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

    /// <summary>
    /// ERP 客戶清單，左併對照到的內網客戶代碼（客戶維護頁的「ERP客戶」頁籤）。
    ///
    /// V_ERPCustomer 同一個 Ma001 可能重複匯入多筆，用 Trim 後的 Ma001 去重取第一筆，
    /// 對齊 1.0 的 <c>DistinctBy(x => x.Ma001)</c>。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel GetERPCustom(string? customNo, string? erpCustomNo)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(GetERPCustom), $"erpCustomNo:{erpCustomNo}");

        var customerByErpNo = db.CrmCustomers
            .Where(c => !string.IsNullOrWhiteSpace(c.ErpcustomerNo))
            .ToList()
            .GroupBy(c => (c.ErpcustomerNo ?? "").Trim())
            .ToDictionary(g => g.Key, g => g.First());

        var list = db.VErpcustomers
            .ToList()
            .GroupBy(e => (e.Ma001 ?? "").Trim())
            .Select(g => g.First())
            .Select(e =>
            {
                customerByErpNo.TryGetValue((e.Ma001 ?? "").Trim(), out var custom);
                return new VErpcustomerViewModel
                {
                    Erpsource = e.Erpsource,
                    Ma001 = e.Ma001,
                    Ma002 = e.Ma002,
                    Ma003 = e.Ma003,
                    Ma005 = e.Ma005,
                    Ma006 = e.Ma006,
                    Ma007 = e.Ma007,
                    Ma008 = e.Ma008,
                    Ma009 = e.Ma009,
                    Ma019 = e.Ma019,
                    Ma023 = e.Ma023,
                    Ma024 = e.Ma024,
                    ErpheadCustomer = e.ErpheadCustomer,
                    CustomerNo = custom?.CustomerNo ?? ""
                };
            }).ToList();

        if (!string.IsNullOrWhiteSpace(erpCustomNo))
        {
            var target = erpCustomNo.Trim();
            list = list.Where(e => (e.Ma001 ?? "").Trim() == target).ToList();
        }

        ca.IsSuccess = true;
        ca.Body = list;
        return ca;
    }

    /// <summary>
    /// 新增或更新客戶。customerNo 空白或查無資料 = 新增，代碼依「兩位數年份 + 3 位數流水號」
    /// 自動產生（對齊 1.0：同年度、流水號 &lt;= 100 的既有客戶取最大號再 +1）；否則更新既有客戶。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel SaveCustom([FromQuery] CrmCustomer crmCustom)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(SaveCustom),
            $"customerNo:{crmCustom.CustomerNo}, erpCustomNo:{crmCustom.ErpcustomerNo}, shortName:{crmCustom.ShortName}, longName:{crmCustom.LongName}");

        var allCustomers = db.CrmCustomers.Where(c => c.AStatus == ActiveStatus.Active).ToList();

        if (!string.IsNullOrWhiteSpace(crmCustom.ErpcustomerNo))
        {
            var erpTarget = crmCustom.ErpcustomerNo.Trim();
            var customerNoTarget = (crmCustom.CustomerNo ?? "").Trim();
            var conflict = allCustomers.Any(c =>
                (c.ErpcustomerNo ?? "").Trim() == erpTarget
                && (c.CustomerNo ?? "").Trim() != customerNoTarget);
            if (conflict)
            {
                ca.Message = $"已有內網客戶代碼關連到ERP客戶代碼{crmCustom.ErpcustomerNo}";
                return ca;
            }
        }

        var target = string.IsNullOrWhiteSpace(crmCustom.CustomerNo)
            ? null
            : allCustomers.FirstOrDefault(c => (c.CustomerNo ?? "").Trim() == crmCustom.CustomerNo.Trim());

        if (target is null)
        {
            var yearPrefix = DateTime.Now.Year.ToString()[2..];
            var lastNo = allCustomers
                .Where(c => (c.CustomerNo ?? "").StartsWith(yearPrefix)
                    && int.TryParse((c.CustomerNo ?? "").Substring(2), out var seq) && seq <= 100)
                .OrderByDescending(c => c.CustomerNo)
                .Select(c => c.CustomerNo)
                .FirstOrDefault();

            var nextSeq = 1;
            if (lastNo is not null && int.TryParse(lastNo.Substring(2), out var parsed))
                nextSeq = parsed + 1;

            target = new CrmCustomer
            {
                CustomerNo = $"{yearPrefix}{nextSeq:000}",
                AStatus = ActiveStatus.Active,
                Creator = GetAccountByToken(),
                CreateTime = DateTime.Now
            };
            db.CrmCustomers.Add(target);
        }
        else
        {
            target.Modifier = GetAccountByToken();
            target.ModiTime = DateTime.Now;
        }

        target.ErpcustomerNo = crmCustom.ErpcustomerNo ?? "";
        target.ShortName = crmCustom.ShortName;
        target.LongName = crmCustom.LongName;
        target.ContactName = crmCustom.ContactName;
        target.ContactTel1 = crmCustom.ContactTel1;
        target.ContactTel2 = crmCustom.ContactTel2;
        target.ContactFax = crmCustom.ContactFax;
        target.ContactEmail = crmCustom.ContactEmail;
        target.Addr1 = crmCustom.Addr1;
        target.Addr2 = crmCustom.Addr2;
        target.SalesNo = crmCustom.SalesNo;
        target.SalesName = crmCustom.SalesName;
        target.PotentialCustom = crmCustom.PotentialCustom;

        db.SaveChanges();

        ca.IsSuccess = true;
        ca.Body = target.CustomerNo;
        return ca;
    }
}
