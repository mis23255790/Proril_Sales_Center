using System.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Proril.SalesIssue.Api.Controllers.Shared;
using Proril.SalesIssue.Api.Data;
using Proril.SalesIssue.Api.Data.SalesCenter;
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
        SalesCenterDbContext scDb,
        JwtHelper jwtHelper,
        StoragePaths paths,
        ILogger<OrderInfoVerifyApiController> logger) : base(scDb, jwtHelper, logger)
    {
        _paths = paths;
    }

    private readonly StoragePaths _paths;

    /// <summary>
    /// 主查詢：訂單 + 明細 + 檢核狀態的攤平清單，一個品號一列，同一張訂單的多列共用同一份
    /// 表頭與 <see cref="CopPoCheckExRule"/>。列表頁籤與明細 modal 共用這支，差別只在參數
    /// 是否篩到單一訂單。
    ///
    /// **與 1.0 的差異**：<c>Body</c> 直接放 <c>List&lt;VPoListDetailViewModel&gt;</c>，
    /// 不像 1.0 用 <c>JsonConvert.SerializeObject</c> 包成字串再讓前端 <c>JSON.parse</c>——
    /// <c>CustomApiViewModel.Body</c> 本來就是 <c>object?</c>，直接放物件即可，
    /// 前端 <c>$fetch</c> 拿到的就是陣列。
    ///
    /// 2026-09-18 起支援分頁，但**分頁的單位是「訂單」，不是攤平後的品號明細列**——
    /// <paramref name="pageIndex"/>/<paramref name="pageSize"/> 是對 <see cref="GetFilteredOrders"/>
    /// 回傳的 <c>V_POList</c>（一列一張訂單）做 Skip/Take，取到本頁的訂單之後才 join 明細，
    /// 不然同一張訂單的品號會被切頁切散到不同頁。<paramref name="tab"/>（notChecked/checked）
    /// 對應畫面的兩個頁籤，換算成 <c>ConfirmFlag</c> 的 N/Y；不傳（明細 modal 的用法）就
    /// 不篩，回傳該訂單全部品號列。<paramref name="pageSize"/> &lt;= 0 代表不分頁——
    /// 明細 modal 就是靠這個預設值拿到單一訂單的完整品號清單，不會被分頁截斷。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel GetPOCheckView(
        string? copSource, string? orderType, string? orderNo, string? customerNo, string? startDate, string? endDate,
        string? tab = null, int pageIndex = 0, int pageSize = 0)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(GetPOCheckView),
            $"copSource:{copSource}, orderType:{orderType}, orderNo:{orderNo}, customerNo:{customerNo}, "
            + $"tab:{tab}, pageIndex:{pageIndex}, pageSize:{pageSize}");

        var allOrders = GetFilteredOrders(copSource, orderType, orderNo, customerNo, startDate, endDate);

        var summary = new OrderInfoVerifySummary
        {
            NotCheckedCount = allOrders.Count(o => o.ConfirmFlag == "N"),
            CheckedCount = allOrders.Count(o => o.ConfirmFlag == "Y")
        };

        var confirmFlag = tab switch
        {
            "checked" => "Y",
            "notChecked" => "N",
            _ => null
        };
        summary.TotalCount = confirmFlag switch
        {
            "Y" => summary.CheckedCount,
            "N" => summary.NotCheckedCount,
            _ => allOrders.Count
        };

        var list = GetOrderInfoList(copSource, orderType, orderNo, customerNo, startDate, endDate, confirmFlag, pageIndex, pageSize, allOrders);

        ca.IsSuccess = true;
        ca.Body = list;
        ca.Body2 = summary;
        return ca;
    }

    /// <summary>「檢核條件」說明清單，全部有效規則。</summary>
    [HttpGet]
    public CustomApiViewModel GetConditionList()
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        ca.IsSuccess = true;
        ca.Body = scDb.CopCheckRules.ToList();
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
        scDb.Database.ExecuteSqlInterpolated($"EXEC prc_COPOrderChk {copSource}, {poNo}, {custAmt}, {paidCheck}, {executor}, {result} OUTPUT");

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
        scDb.Database.ExecuteSqlInterpolated($"EXEC prc_COPPassCheck {checkNo}, {passItem}, {passMemo}, {executor}, {result} OUTPUT");

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
        ca.Body = scDb.Set<CopGetCredit>()
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
        ca.Body = scDb.Set<CopGetCreditCrm>()
            .FromSqlInterpolated($"EXEC prc_COPGetCredit_CRM {customNo}, {account}")
            .ToList();
        return ca;
    }

    /// <summary>
    /// 訂單層級的篩選（<c>V_POList</c> 一列一張訂單），GetPOCheckView 分頁與統計都靠這支——
    /// 分頁、頁籤筆數都要以「訂單數」為單位，不能用攤平後的品號明細列數，
    /// 所以獨立出來，讓 <see cref="GetPOCheckView"/> 跟 <see cref="GetOrderInfoList"/>
    /// 共用同一份「篩選後、切頁籤前」的訂單清單，不用各自重撈一次。
    /// </summary>
    private List<VPoList> GetFilteredOrders(
        string? copSource, string? orderType, string? orderNo, string? customerNo,
        string? startDate, string? endDate)
    {
        var vpoQuery = scDb.VPoLists.AsNoTracking().AsQueryable();

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

        return vpoList;
    }

    /// <summary>
    /// GetPOCheckView / ExportXls 共用的查詢核心，照抄 1.0 的多重 join。最終 join 全部在
    /// 記憶體（LINQ to Objects）做，1.0 也是先 ToList() 幾張表再 join——這些 join 用了字串
    /// 串接當複合鍵，SQL 端無法翻譯，join 本身沒辦法省。
    ///
    /// **與 1.0 的差異（效能）**：1.0／這裡最早的版本是每張支援表整表 ToList() 下來，
    /// 即使只查一張訂單也要下載全表，是這支 API 最主要的瓶頸。現在改成先用「本頁實際會用到
    /// 的訂單」（<paramref name="pageSize"/> 分頁後的 <c>vpoList</c>）算出 CopSource／
    /// PoNo（單別-單號）／部門代號 這幾組候選值，讓資料庫端先用 <c>IN</c> 過濾掉不相關的列，
    /// 下面的 join 邏輯完全不變。這些過濾條件刻意只比對 <see cref="GetFilteredOrders"/> 篩出
    /// 的訂單有哪些，是「安全的超集合」而不是精確比對（例如 CopPoDetailCheck 不比對 Sno、
    /// VPoDetailList 只比對單號不比對單別）——多抓幾筆沒關係，最後的 join 才是決定實際結果的
    /// 依據，這裡只是減少要下載到記憶體的資料量。
    ///
    /// <paramref name="preFilteredOrders"/> 有值就直接用（GetPOCheckView 已經先呼叫過
    /// <see cref="GetFilteredOrders"/>，不用再撈一次 <c>V_POList</c>）；ExportXls 沒有這份
    /// 資料，傳 null 讓這裡自己查。<paramref name="pageSize"/> &lt;= 0 代表不分頁
    /// （ExportXls 用預設值，永遠拿全部——這種情況候選值集合會接近全表，跟優化前效能相近，
    /// 是預期行為，匯出本來就要全部資料）。
    /// </summary>
    private List<VPoListDetailViewModel> GetOrderInfoList(
        string? copSource, string? orderType, string? orderNo, string? customerNo,
        string? startDate, string? endDate, string? confirmFlag,
        int pageIndex = 0, int pageSize = 0, List<VPoList>? preFilteredOrders = null)
    {
        var checkRules = scDb.CopCheckRules.ToList();

        var vpoList = preFilteredOrders ?? GetFilteredOrders(copSource, orderType, orderNo, customerNo, startDate, endDate);

        if (!string.IsNullOrEmpty(confirmFlag))
        {
            vpoList = vpoList.Where(v => v.ConfirmFlag == confirmFlag).ToList();
        }

        // 分頁的單位是訂單（這裡的一列），要在 join 品號明細之前切，
        // 不然同一張訂單的品號會被切頁切散到不同頁。
        vpoList = vpoList.OrderBy(v => v.單別).ThenBy(v => v.單號).ThenBy(v => v.CopSource).ToList();
        if (pageSize > 0)
        {
            vpoList = vpoList.Skip(Math.Max(pageIndex, 0) * pageSize).Take(pageSize).ToList();
        }

        if (vpoList.Count == 0)
        {
            return [];
        }

        var copSources = vpoList.Select(v => v.CopSource).Distinct().ToList();
        var poNoKeys = vpoList.Select(v => $"{v.單別.Trim()}-{v.單號.Trim()}").Distinct().ToList();
        var orderNos = vpoList.Select(v => v.單號.Trim()).Distinct().ToList();
        var depNos = vpoList.Select(v => v.部門代號).Distinct().ToList();

        var copPoCheckList = scDb.CopPoChecks.AsNoTracking()
            .Where(c => c.CopSource != null && copSources.Contains(c.CopSource)
                && c.PoNo != null && poNoKeys.Contains(c.PoNo.Trim()))
            .ToList()
            .Select(c => new CopPoCheckExRule(c, checkRules)).ToList();

        var copPoDetailCheckRaw = scDb.CopPoDetailChecks.AsNoTracking()
            .Where(c => c.CopSource != null && copSources.Contains(c.CopSource)
                && c.PoNo != null && poNoKeys.Contains(c.PoNo.Trim()))
            .ToList();
        var copPoDetailCheckList = copPoDetailCheckRaw
            .Select(c => new CopPoDetailCheckExRule(c, checkRules)).ToList();

        var vpoDetailList = scDb.VPoDetailLists.AsNoTracking()
            .Where(d => copSources.Contains(d.CopSource) && orderNos.Contains(d.單號.Trim()))
            .ToList();

        var productNos = vpoDetailList.Select(d => d.品號).Where(p => p != null).Distinct().ToList();
        var productEnglishAlls = productNos.Count == 0
            ? new List<Proril.SalesIssue.Api.Data.VProductEnglishAll>()
            : scDb.VProductEnglishAlls.AsNoTracking()
                .Where(p => p.ProductNo != null && productNos.Contains(p.ProductNo))
                .ToList();

        var depData = scDb.CopDepData.AsNoTracking()
            .Where(d => d.DepNo != null && depNos.Contains(d.DepNo))
            .ToList();

        var upFileData = scDb.VUpFileData.AsNoTracking()
            .Where(u => u.KeyValues != null && poNoKeys.Contains(u.KeyValues))
            .ToList();

        // 只用「本頁訂單檢核明細」牽到的 OrderChkNo 當候選值（超集合：不管 Sno，
        // 比原始 join 的 LastOrDefault() 寬鬆一點沒關係，join 邏輯本身沒動）。
        var orderChkNos = copPoDetailCheckRaw.Select(c => c.OrderChkNo).Where(o => o != null).Distinct().ToList();
        var passChecks = orderChkNos.Count == 0
            ? new List<Proril.SalesIssue.Api.Data.CopPassCheck>()
            : scDb.CopPassChecks.AsNoTracking()
                .Where(p => p.OrderChkNo != null && orderChkNos.Contains(p.OrderChkNo))
                .ToList();

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
