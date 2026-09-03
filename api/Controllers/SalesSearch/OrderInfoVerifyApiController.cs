using System.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Proril.SalesIssue.Api.Controllers.Shared;
using Proril.SalesIssue.Api.Data;
using Proril.SalesIssue.Api.Helpers;
using Proril.SalesIssue.Api.Models;

namespace Proril.SalesIssue.Api.Controllers.SalesSearch;

/// <summary>
/// 訂單資料檢核（1.0 Mix/OrderInfoVerify）。端點名稱與參數大小寫刻意與 1.0 的
/// OrderInfoVerifyApi 一字不差。跟已搬的銷貨檢索／未完成訂單檢索不同，這個模組含寫入操作
/// （<see cref="CheckCOPOrderInfo"/>／<see cref="COPOrderInfoPassCheck"/> 會執行預存程序
/// 寫回 COP_PoCheck/COP_PoDetailCheck/COP_PassCheck），所以後端也整支搬過來，不是純轉發。
/// </summary>
[Authorize]
public partial class OrderInfoVerifyApiController : BaseApiController
{
    public OrderInfoVerifyApiController(
        SalesIssueDbContext db,
        JwtHelper jwtHelper,
        StoragePaths paths,
        ILogger<OrderInfoVerifyApiController> logger) : base(db, jwtHelper, logger)
    {
        _paths = paths;
    }

    private readonly StoragePaths _paths;

    /// <summary>
    /// 主查詢：訂單 + 明細 + 檢核狀態的攤平清單，一個品號一列，同一張訂單的多列共用同一份
    /// 表頭與 <see cref="CopPoCheckExRule"/>。列表 tab 與明細 modal 共用這支，差別只在參數
    /// 是否篩到單一訂單。
    ///
    /// **與 1.0 的差異**：<c>Body</c> 直接放 <c>List&lt;VPoListDetailViewModel&gt;</c>，
    /// 不像 1.0 用 <c>JsonConvert.SerializeObject</c> 包成字串再讓前端 <c>JSON.parse</c>——
    /// <c>CustomApiViewModel.Body</c> 本來就是 <c>object?</c>，直接放物件即可，
    /// 前端 <c>$fetch</c> 拿到的就是陣列。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel GetPOCheckView(string? copSource, string? orderType, string? orderNo, string? customerNo, string? startDate, string? endDate)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(GetPOCheckView), $"copSource:{copSource}, orderType:{orderType}, orderNo:{orderNo}, customerNo:{customerNo}");

        var list = GetOrderInfoList(copSource, orderType, orderNo, customerNo, startDate, endDate, null);

        ca.IsSuccess = true;
        ca.Body = list;
        return ca;
    }

    /// <summary>「檢核條件」說明清單，全部有效規則。</summary>
    [HttpGet]
    public CustomApiViewModel GetConditionList()
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        ca.IsSuccess = true;
        ca.Body = db.CopCheckRules.ToList();
        return ca;
    }

    /// <summary>
    /// 執行一次訂單檢核：呼叫 prc_COPOrderChk，結果由 SP 自己寫回 COP_PoCheck/COP_PoDetailCheck。
    ///
    /// SP 是黑盒子（不能改資料庫），回傳訊息字串裡有沒有出現 "SUCCESS" 是唯一能判斷成敗的方式，
    /// 這是沿用 1.0 既有的怪判斷法，不是這裡新寫的。<paramref name="creditAvalAmt"/> 雖然收在
    /// 簽章上（跟 1.0 一樣，相容前端既有呼叫），但沒有真的傳進 SQL——1.0 本來就是這樣，
    /// SP 內部另外用 <paramref name="poNo"/> 查信用額度。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel CheckCOPOrderInfo(string copSource, string poNo, float custAmt, string paidCheck, float creditAvalAmt, string? executor)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(CheckCOPOrderInfo), $"copSource:{copSource}, poNo:{poNo}, custAmt:{custAmt}");

        executor = string.IsNullOrWhiteSpace(executor) ? GetAccountByToken() : executor;

        var result = new SqlParameter("@Results", SqlDbType.NVarChar, 255) { Direction = ParameterDirection.Output };
        db.Database.ExecuteSqlInterpolated($"EXEC prc_COPOrderChk {copSource}, {poNo}, {custAmt}, {paidCheck}, {executor}, {result} OUTPUT");

        ca.Body = result.Value?.ToString();
        if (((string?)ca.Body ?? "").Contains("SUCCESS"))
        {
            ca.IsSuccess = true;
        }
        else
        {
            ca.Message = $"-->{ca.Body} ";
        }

        return ca;
    }

    /// <summary>對單一檢核項目下「特規 Pass」：呼叫 prc_COPPassCheck，寫回 COP_PassCheck。</summary>
    [HttpGet]
    public CustomApiViewModel COPOrderInfoPassCheck(string checkNo, string passItem, string passMemo, string? executor)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(COPOrderInfoPassCheck), $"checkNo:{checkNo}, passItem:{passItem}");

        executor = string.IsNullOrWhiteSpace(executor) ? GetAccountByToken() : executor;

        var result = new SqlParameter("@Results", SqlDbType.NVarChar, 255) { Direction = ParameterDirection.Output };
        db.Database.ExecuteSqlInterpolated($"EXEC prc_COPPassCheck {checkNo}, {passItem}, {passMemo}, {executor}, {result} OUTPUT");

        ca.Body = result.Value?.ToString();
        if (((string?)ca.Body ?? "").Contains("SUCCESS"))
        {
            ca.IsSuccess = true;
        }
        else
        {
            ca.Message = $"-->{ca.Body} ";
        }

        return ca;
    }

    /// <summary>
    /// 客戶信用額度（訂單檢核用）。
    /// 與 1.0 的差異：改用 <c>FromSqlInterpolated</c> 讓 EF 自己參數化，1.0 是直接字串插值組
    /// SQL 執行，有 SQL injection 風險。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel SP_GetCredit(string customNo)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(SP_GetCredit), $"customNo:{customNo}");

        var account = GetAccountByToken();
        ca.IsSuccess = true;
        ca.Body = db.Set<CopGetCredit>()
            .FromSqlInterpolated($"EXEC prc_COPGetCredit {customNo}, {account}")
            .ToList();
        return ca;
    }

    /// <summary>客戶信用額度（幣別分開版本）。目前前端沒有呼叫這支，比照 1.0 只搬後端端點。</summary>
    [HttpGet]
    public CustomApiViewModel SP_GetCreditCRM(string customNo)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(SP_GetCreditCRM), $"customNo:{customNo}");

        var account = GetAccountByToken();
        ca.IsSuccess = true;
        ca.Body = db.Set<CopGetCreditCrm>()
            .FromSqlInterpolated($"EXEC prc_COPGetCredit_CRM {customNo}, {account}")
            .ToList();
        return ca;
    }

    /// <summary>
    /// GetPOCheckView / ExportXls 共用的查詢核心，照抄 1.0 的多重 join。全部在記憶體
    /// （LINQ to Objects）做，1.0 也是先 ToList() 幾張表再 join——這些 join 用了字串串接當
    /// 複合鍵，SQL 端無法翻譯，本來就得先撈到記憶體。
    /// </summary>
    private List<VPoListDetailViewModel> GetOrderInfoList(
        string? copSource, string? orderType, string? orderNo, string? customerNo,
        string? startDate, string? endDate, string? confirmFlag)
    {
        var checkRules = db.CopCheckRules.ToList();
        var copPoCheckList = db.CopPoChecks.AsNoTracking().ToList()
            .Select(c => new CopPoCheckExRule(c, checkRules)).ToList();
        var copPoDetailCheckList = db.CopPoDetailChecks.AsNoTracking().ToList()
            .Select(c => new CopPoDetailCheckExRule(c, checkRules)).ToList();

        var vpoQuery = db.VPoLists.AsNoTracking().AsQueryable();

        if (!string.IsNullOrWhiteSpace(copSource))
        {
            var trimmed = copSource.Trim();
            vpoQuery = vpoQuery.Where(v => v.CopSource.Trim() == trimmed);
        }
        if (!string.IsNullOrWhiteSpace(orderNo))
        {
            var trimmed = orderNo.Trim();
            vpoQuery = vpoQuery.Where(v => v.單號.Trim() == trimmed);
        }
        if (!string.IsNullOrWhiteSpace(orderType))
        {
            var trimmed = orderType.Trim();
            vpoQuery = vpoQuery.Where(v => v.單別 == trimmed);
        }
        if (!string.IsNullOrWhiteSpace(customerNo))
        {
            var trimmed = customerNo.Trim();
            vpoQuery = vpoQuery.Where(v => v.客戶代號 == trimmed);
        }

        var vpoList = vpoQuery.ToList();

        // 訂單日期是 yyyyMMdd 字串，用字串比較（照抄 1.0）。
        if (!string.IsNullOrEmpty(startDate) && DateTime.TryParse(startDate, out var start))
        {
            var startCompact = start.ToString("yyyyMMdd");
            vpoList = vpoList.Where(v => string.Compare(v.訂單日期, startCompact, StringComparison.Ordinal) >= 0).ToList();
        }
        if (!string.IsNullOrEmpty(endDate) && DateTime.TryParse(endDate, out var end))
        {
            var endCompact = end.AddDays(1).ToString("yyyyMMdd");
            vpoList = vpoList.Where(v => string.Compare(v.訂單日期, endCompact, StringComparison.Ordinal) < 0).ToList();
        }
        if (!string.IsNullOrEmpty(confirmFlag))
        {
            vpoList = vpoList.Where(v => v.ConfirmFlag == confirmFlag).ToList();
        }

        var vpoDetailList = db.VPoDetailLists.AsNoTracking().ToList();
        var productEnglishAlls = db.VProductEnglishAlls.AsNoTracking().ToList();
        var depData = db.CopDepData.AsNoTracking().ToList();
        var upFileData = db.VUpFileData.AsNoTracking().ToList();
        var passChecks = db.CopPassChecks.AsNoTracking().ToList();

        var query = from tbl in vpoList
                    join poCheck in copPoCheckList
                        on new { F1 = tbl.CopSource, F2 = $"{tbl.單別.Trim()}-{tbl.單號.Trim()}" }
                        equals new { F1 = poCheck.CopSource ?? "", F2 = (poCheck.PoNo ?? "").Trim() } into tblPoCheck
                    join detail in vpoDetailList
                        on new { F1 = tbl.CopSource, F2 = tbl.單別.Trim(), F3 = tbl.單號.Trim() }
                        equals new { F1 = detail.CopSource, F2 = detail.單別.Trim(), F3 = detail.單號.Trim() }
                    join poDetailCheck in copPoDetailCheckList
                        on new { F1 = tbl.CopSource, F2 = $"{detail.單別.Trim()}-{detail.單號.Trim()}", F3 = detail.序號 }
                        equals new { F1 = poDetailCheck.CopSource ?? "", F2 = (poDetailCheck.PoNo ?? "").Trim(), F3 = poDetailCheck.Sno ?? "" } into tblPoDetailCheck
                    join productE in productEnglishAlls
                        on detail.品號 equals productE.ProductNo into tblProductE
                    join dep in depData
                        on tbl.部門代號 equals dep.DepNo into tblDep
                    join upFile in upFileData
                        on $"{tbl.單別.Trim()}-{tbl.單號.Trim()}" equals upFile.KeyValues into tblUpFile
                    // 照抄 1.0：用 LastOrDefault()（不是「OrderChkNo 最大」），保持與既有資料行為一致。
                    join passCheck in passChecks
                        on tblPoDetailCheck.LastOrDefault()?.OrderChkNo
                        equals passCheck.OrderChkNo into tblPassCheck
                    orderby tbl.單別, tbl.單號, tbl.CopSource, detail.序號
                    select new VPoListDetailViewModel(
                        tbl,
                        tblPoCheck.OrderByDescending(o => o.OrderChkNo).FirstOrDefault(),
                        detail,
                        tblPoDetailCheck.OrderByDescending(o => o.OrderChkNo).FirstOrDefault(),
                        tblPassCheck.OrderByDescending(o => o.Sno).ToList(),
                        tblProductE.FirstOrDefault(),
                        tblDep.FirstOrDefault(),
                        tblUpFile.FirstOrDefault());

        return query.ToList();
    }
}
