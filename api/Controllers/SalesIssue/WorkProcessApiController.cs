using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Proril.SalesIssue.Api.Controllers.Shared;
using Proril.SalesIssue.Api.Filters;
using Proril.SalesIssue.Api.Data;
using Proril.SalesIssue.Api.Data.SalesCenter;
using Proril.SalesIssue.Api.Helpers;
using Proril.SalesIssue.Api.Models;

namespace Proril.SalesIssue.Api.Controllers.SalesIssue;

/// <summary>
/// 業務議題主 API。端點名稱與參數大小寫刻意與 1.0 的 WorkProcessApi 一字不差，
/// 前端把 NUXT_PUBLIC_API_BASE 指過來就能直接跑，不必改任何一行。
///
/// 議題本身（D_WorkProcess* / M_WorkProcessPhrase / M_WorkProcessType / CRM_Customer）
/// 打 <see cref="scDb"/>（Proril_Sales_Center，已確認單一擁有者，可以放心切）；
/// M_User / M_Permission 這兩張表 2026-09-14 已隨權限控管搬遷一起切到 <see cref="scDb"/>，
/// 這支不再需要 <c>ProrilWebDbContext</c>，見 CLAUDE.md 「權限控管已完成搬遷」段落。
/// </summary>
[Authorize]
[RequirePermission(PermissionKeys.SalesIssue.ProcessMaintain)]
public partial class WorkProcessApiController : BaseApiController
{
    private const int SopTitleMaxLength = 80;

    private readonly StoragePaths _paths;

    public WorkProcessApiController(
        ProrilWebDbContext db,
        SalesCenterDbContext scDb,
        JwtHelper jwtHelper,
        StoragePaths paths,
        ILogger<WorkProcessApiController> logger) : base(db, scDb, jwtHelper, logger)
    {
        _paths = paths;
    }

    // ------------------------------------------------------------------ 議題列表

    /// <summary>
    /// 議題列表（編輯視角）。
    ///
    /// 2026-09-18 之前 startDate / endDate 雖然收但完全不做事（1.0 在 2026-06-08
    /// 改成 order by 客戶別時把過濾註解掉，前端改成自己對「最後修改時間」過濾）。
    /// 現在為了做後端分頁，日期區間與快速搜尋 (<paramref name="keyword"/>) 都改回
    /// 後端過濾 —— 分頁的基準必須跟篩選條件一致，不然「切到第 2 頁」跟「篩日期」
    /// 兩件事會互相打架。
    ///
    /// <paramref name="tab"/>：ongoing / finished / all（對應畫面的三個狀態頁籤），
    /// 用來決定回傳哪個子集合，但三個頁籤各自的筆數 (Body2) 是以「篩選後、切頁籤前」
    /// 的資料算出來的，不會因為目前選哪個頁籤而變動。
    ///
    /// <paramref name="pageIndex"/> 從 0 起算，<paramref name="pageSize"/> &lt;= 0
    /// 代表不分頁（前端「全部」）。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel GetSOPList_Edit(
        string? type2_phrase_name, string? type3_phrase_name,
        string? caption_name, string? content_name,
        bool pub_only, string? startDate, string? endDate,
        string? keyword = null, string? tab = null,
        int pageIndex = 0, int pageSize = 20)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(GetSOPList_Edit),
            $"type2:{type2_phrase_name}, type3:{type3_phrase_name}, caption:{caption_name}, content:{content_name}, "
            + $"pub_only:{pub_only}, startDate:{startDate}, endDate:{endDate}, keyword:{keyword}, tab:{tab}, "
            + $"pageIndex:{pageIndex}, pageSize:{pageSize}");

        var account = GetAccountByToken();
        var isAdmin = IsAdmin(account);

        // 有「SOP-公開」細項權限就看得到全部（原本是 FunctionNo 0070102 + LinkType 20，只認本人的列；
        // 改成字串權限後同其他檢查一樣看所屬角色 ∪ everyone）
        var isPublic = HasPermission(account, PermissionKeys.SalesIssue.ProcessMaintainPublishSop);

        ca = GetSopListCore(type2_phrase_name, type3_phrase_name, caption_name, content_name, pub_only);
        if (!ca.IsSuccess) return ca;

        var sopList = ca.Body as List<DWorkProcessesEx> ?? new List<DWorkProcessesEx>();

        if (!isAdmin && !isPublic)
        {
            // 逐議題的權限過濾：本人或全體帳號，且為「編輯」或「公開」層級
            var permissions = scDb.DWorkProcessPermissions
                .Where(p => p.EnableType == (byte)EWorkProcessPermission.Edit
                         || p.EnableType == (byte)EWorkProcessPermission.Public)
                .ToList()
                .Where(p => (p.Account ?? "").Trim() == account
                         || (p.Account ?? "").Trim() == PermissionConst.AccountForAll)
                .Select(p => (p.Wpno ?? "").Trim())
                .ToHashSet();

            sopList = sopList
                .Where(wp => permissions.Contains((wp.Wpno ?? "").Trim()))
                .GroupBy(wp => wp.Wpno)
                .Select(g => g.First())
                .ToList();
        }

        // 最後修改起訖日：跟前端 rowTime 邏輯一致，沒有最後修改時間就退回建立時間
        if (!string.IsNullOrWhiteSpace(startDate) && DateTime.TryParse(startDate, out var start))
        {
            sopList = sopList.Where(wp => (wp.LastModiTime ?? wp.ModiTime ?? wp.CreateTime) >= start.Date).ToList();
        }
        if (!string.IsNullOrWhiteSpace(endDate) && DateTime.TryParse(endDate, out var end))
        {
            var endExclusive = end.Date.AddDays(1);
            sopList = sopList.Where(wp => (wp.LastModiTime ?? wp.ModiTime ?? wp.CreateTime) < endExclusive).ToList();
        }

        // 快速搜尋：涵蓋編號／主題／最新進度／人員／類別／客戶別，跟前端原本的欄位範圍一致
        if (!string.IsNullOrWhiteSpace(keyword))
        {
            var kw = keyword.Trim();
            sopList = sopList.Where(wp =>
                (wp.Wpno ?? "").Contains(kw)
                || (wp.SopTitle ?? "").Contains(kw)
                || (wp.ProcessCaption ?? "").Contains(kw)
                || (wp.ProcessCaption2 ?? "").Contains(kw)
                || (wp.UserName ?? "").Contains(kw)
                || (wp.LastModifierName ?? "").Contains(kw)
                || (wp.PhraseNameList ?? "").Contains(kw)
                || (wp.CustomerName ?? "").Contains(kw)
            ).ToList();
        }

        if (sopList.Count == 0)
        {
            ca.IsSuccess = false;
            ca.Message = "查無工作流程項目資料!!!";
            ca.Body = new List<DWorkProcessesEx>();
            ca.Body2 = new SalesIssueListSummary();
            return ca;
        }

        var summary = new SalesIssueListSummary
        {
            OngoingCount = sopList.Count(wp => wp.FinFlag != true),
            FinishedCount = sopList.Count(wp => wp.FinFlag == true),
            AllCount = sopList.Count
        };

        var tabFiltered = tab switch
        {
            "ongoing" => sopList.Where(wp => wp.FinFlag != true).ToList(),
            "finished" => sopList.Where(wp => wp.FinFlag == true).ToList(),
            _ => sopList
        };
        summary.TotalCount = tabFiltered.Count;

        var ordered = tabFiltered.OrderByDescending(wp => wp.LastModiTime).ToList();
        var paged = pageSize <= 0
            ? ordered
            : ordered.Skip(Math.Max(pageIndex, 0) * pageSize).Take(pageSize).ToList();

        ca.IsSuccess = true;
        ca.Message = null;
        ca.Body = paged;
        ca.Body2 = summary;
        return ca;
    }

    /// <summary>
    /// 組議題列表。
    ///
    /// **與 1.0 的行為差異（刻意修掉的 bug）**：
    /// 1.0 在這裡對 M_User 用了兩個 inner join（Creator 與「最新一則進度的 Modifier」），
    /// 所以只要 Creator 不在 M_User、最新進度的 Modifier 不在 M_User、
    /// 或這張議題**一則進度都還沒有**（FirstOrDefault() 是 null，配不到任何帳號），
    /// 整張議題就會從列表無聲消失。最後那一項讓「剛建好還沒寫進度的議題」直接看不到。
    /// 這裡改成左外接：接不到就顯示空字串，議題本身照樣列出來。
    ///
    /// 另外所有帳號比對都 Trim()：資料是先 ToList() 再比，
    /// LINQ to Objects 的字串比較不像 SQL 會忽略尾端空白。
    /// </summary>
    private CustomApiViewModel GetSopListCore(
        string? type2PhraseName, string? type3PhraseName,
        string? captionName, string? contentName, bool pubOnly)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        var processes = scDb.DWorkProcesses.Where(o => o.AStatus == ActiveStatus.Active).ToList();

        // 內文很大，列表不需要，撈的時候就跳過（1.0 也是這樣）
        var details = scDb.DWorkProcessDetails
            .Where(d => d.AStatus == ActiveStatus.Active)
            .Select(d => new DWorkProcessDetail
            {
                Id = d.Id,
                Wpno = d.Wpno,
                Sno = d.Sno,
                ProcessCaption = d.ProcessCaption,
                ProcessCaption2 = d.ProcessCaption2,
                Worker = d.Worker,
                AStatus = d.AStatus,
                UploadFile = d.UploadFile,
                RenameFile = d.RenameFile,
                ZipFile = d.ZipFile,
                Creator = d.Creator,
                CreateTime = d.CreateTime,
                Modifier = d.Modifier,
                ModiTime = d.ModiTime
            })
            .ToList();

        var phrases = scDb.MWorkProcessPhrases.Where(o => o.AStatus == ActiveStatus.Active).ToList();
        var searches = scDb.DWorkProcessSearches.Where(o => o.AStatus == ActiveStatus.Active).ToList();
        var wpCustomers = scDb.DWorkProcessCustomers.Where(o => o.AStatus == ActiveStatus.Active).ToList();
        var crmCustomers = scDb.CrmCustomers.Where(o => o.AStatus == ActiveStatus.Active).ToList();
        var users = scDb.MUsers.ToList();

        var userNameByAccount = users
            .GroupBy(u => (u.Account ?? "").Trim())
            .ToDictionary(g => g.Key, g => g.First().UserName ?? "");

        var latestDetailByWpno = details
            .GroupBy(d => (d.Wpno ?? "").Trim())
            .ToDictionary(g => g.Key, g => g.OrderByDescending(d => d.ModiTime).ThenByDescending(d => d.Id).First());

        var searchesByWpno = searches
            .GroupBy(s => (s.Wpno ?? "").Trim())
            .ToDictionary(g => g.Key, g => g.GroupBy(s => (s.PhraseCode ?? "").Trim()).Select(x => x.First()).ToList());

        var customerByWpno = wpCustomers
            .GroupBy(c => (c.Wpno ?? "").Trim())
            .ToDictionary(g => g.Key, g => g.First());

        var crmByNo = crmCustomers
            .GroupBy(c => (c.CustomerNo ?? "").Trim())
            .ToDictionary(g => g.Key, g => g.First());

        var phraseNameByKey = phrases
            .GroupBy(p => ((p.PhraseType ?? "").Trim(), (p.PhraseCode ?? "").Trim()))
            .ToDictionary(g => g.Key, g => g.First().PhraseName);

        var list = processes.Select(wp =>
        {
            var wpno = (wp.Wpno ?? "").Trim();
            latestDetailByWpno.TryGetValue(wpno, out var latest);
            customerByWpno.TryGetValue(wpno, out var wpCustomer);

            CrmCustomer? crm = null;
            var customerNo = (wpCustomer?.CustomerNo ?? "").Trim();
            if (customerNo.Length > 0) crmByNo.TryGetValue(customerNo, out crm);

            var wpSearches = searchesByWpno.TryGetValue(wpno, out var s) ? s : new List<DWorkProcessSearch>();

            return new DWorkProcessesEx(wp)
            {
                ProcessCaption = latest?.ProcessCaption ?? "",
                ProcessCaption2 = latest?.ProcessCaption2 ?? "",
                ProcessContent = "",
                Account = (wp.Creator ?? "").Trim(),
                UserName = userNameByAccount.TryGetValue((wp.Creator ?? "").Trim(), out var cn) ? cn : "",
                LastModifierName = userNameByAccount.TryGetValue((latest?.Modifier ?? "").Trim(), out var mn) ? mn : "",
                LastModiTime = latest?.ModiTime,
                EnableType = (byte)'0',
                PotentialCustom = crm?.PotentialCustom ?? "",
                CustomerNo = customerNo,
                CustomerName = crm?.ShortName ?? "",
                PhraseTypeList = string.Join(";", wpSearches.Select(x => (x.PhraseType ?? "").Trim())),
                PhraseCodeList = string.Join(";", wpSearches.Select(x => (x.PhraseCode ?? "").Trim())),
                PhraseNameList = string.Join(";", wpSearches.Select(x =>
                    phraseNameByKey.TryGetValue(((x.PhraseType ?? "").Trim(), (x.PhraseCode ?? "").Trim()), out var pn) ? pn : "")),
                PhraseList = string.Join(";", wpSearches.Select(x =>
                    phraseNameByKey.TryGetValue(((x.PhraseType ?? "").Trim(), (x.PhraseCode ?? "").Trim()), out var pn) ? pn : ""))
            };
        })
        .OrderByDescending(x => x.LastModiTime)
        .ToList();

        if (list.Count == 0)
        {
            ca.Message = "查無工作流程項目類別資料!!!";
            return ca;
        }

        if (!string.IsNullOrWhiteSpace(captionName))
        {
            list = list.Where(wp =>
                    (wp.ProcessCaption ?? "").Contains(captionName)
                 || (wp.SopTitle ?? "").Contains(captionName)).ToList();
            if (list.Count == 0)
            {
                ca.Message = $"查無工作流程項目 大綱關鍵字:{captionName} 資料!!!";
                return ca;
            }
        }

        if (!string.IsNullOrWhiteSpace(contentName))
        {
            // 列表沒有載入 ProcessContent，所以內文關鍵字要回資料庫查一次
            var matched = scDb.DWorkProcessDetails
                .Where(d => d.AStatus == ActiveStatus.Active
                         && ((d.ProcessContent != null && d.ProcessContent.Contains(contentName))
                          || (d.ProcessCaption2 != null && d.ProcessCaption2.Contains(contentName))))
                .Select(d => d.Wpno)
                .ToList()
                .Select(w => (w ?? "").Trim())
                .ToHashSet();

            list = list.Where(wp => matched.Contains((wp.Wpno ?? "").Trim())).ToList();
            if (list.Count == 0)
            {
                ca.Message = $"查無工作流程項目 內文關鍵字:{contentName} 資料!!!";
                return ca;
            }
        }

        if (pubOnly)
        {
            list = list.Where(wp => wp.PubFlag == true).ToList();
            if (list.Count == 0)
            {
                ca.Message = "查無工作流程項目 pub_only: true 資料!!!";
                return ca;
            }
        }

        if (!string.IsNullOrWhiteSpace(type2PhraseName))
        {
            list = list.Where(wp => (wp.PhraseNameList ?? "").Contains(type2PhraseName)).ToList();
            if (list.Count == 0)
            {
                ca.Message = $"查無工作流程項目 Type 類別:{type2PhraseName} 資料!!!";
                return ca;
            }
        }

        if (!string.IsNullOrWhiteSpace(type3PhraseName))
        {
            list = list.Where(wp => (wp.CustomerName ?? "").Contains(type3PhraseName)).ToList();
            if (list.Count == 0)
            {
                ca.Message = $"查無工作流程項目 Job 類別:{type3PhraseName} 資料!!!";
                return ca;
            }
        }

        ca.Body = list
            .GroupBy(wp => wp.Wpno)
            .Select(g => g.First())
            .OrderBy(wp => wp.CustomerName)
            .ToList();
        ca.IsSuccess = true;
        return ca;
    }

    /// <summary>全部議題（含已失效）。前端只拿它算下一個編號。</summary>
    [HttpGet]
    public CustomApiViewModel GetSOPListAll()
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        var list = scDb.DWorkProcesses.OrderByDescending(wp => wp.CreateTime).ToList();
        if (list.Count == 0)
        {
            ca.Message = "查無工作流程項目類別資料!!!";
            return ca;
        }

        ca.IsSuccess = true;
        ca.Body = list;
        return ca;
    }

    // ------------------------------------------------------------------ 議題表頭

    [HttpGet]
    public CustomApiViewModel GetSOPOrder(string wpno)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(GetSOPOrder), $"wpno:{wpno}");

        var padded = StoragePaths.PadWpno(wpno);
        if (padded.Length == 0)
        {
            ca.Message = $"wpno:{wpno} 有誤!!!";
            return ca;
        }

        var wp = scDb.DWorkProcesses.FirstOrDefault(o => o.AStatus == ActiveStatus.Active && o.Wpno == padded);
        if (wp is null)
        {
            ca.Message = $"查無工作流程項目資料:{padded}!!!";
            return ca;
        }

        var result = new DWorkProcessesEx(wp);

        var wpCustomer = scDb.DWorkProcessCustomers
            .FirstOrDefault(c => c.Wpno == padded && c.AStatus == ActiveStatus.Active);
        if (wpCustomer is not null)
        {
            var customerNo = (wpCustomer.CustomerNo ?? "").Trim();
            result.CustomerNo = customerNo;
            result.CustomerName = scDb.CrmCustomers
                .Where(c => c.AStatus == ActiveStatus.Active)
                .ToList()
                .FirstOrDefault(c => (c.CustomerNo ?? "").Trim() == customerNo)?.ShortName ?? "";
        }

        var searchResult = GetWPOrderPhrase(padded);
        if (searchResult.IsSuccess && searchResult.Body is List<DWorkProcessSearchEx> searches)
        {
            result.PhraseTypeList = string.Join(";", searches.Select(s => (s.PhraseType ?? "").Trim()));
            result.PhraseCodeList = string.Join(";", searches.Select(s => (s.PhraseCode ?? "").Trim()));
            result.PhraseNameList = string.Join(";", searches.Select(s => s.PhraseName ?? ""));
        }

        ca.IsSuccess = true;
        ca.Body = result;
        return ca;
    }

    /// <summary>
    /// 新增或更新議題表頭。
    ///
    /// CustomerNo 不寫在這裡 —— 客戶關聯是 D_WorkProcessCustomer，
    /// 由 SetWPOrderCustom 負責。1.0 也是這樣（那行被註解掉了）。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel SaveOrder([FromQuery] DWorkProcess wpOrder)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(SaveOrder), $"wpno:{wpOrder?.Wpno}");

        if (wpOrder is null || string.IsNullOrWhiteSpace(wpOrder.Wpno))
        {
            ca.Message = "wpno為空!!!";
            return ca;
        }

        var padded = StoragePaths.PadWpno(wpOrder.Wpno);
        if (padded.Length == 0)
        {
            ca.Message = $"wpOrder. wpNo:{wpOrder.Wpno} 有誤!!!";
            return ca;
        }
        wpOrder.Wpno = padded;

        if (string.IsNullOrWhiteSpace(wpOrder.SopTitle))
        {
            ca.Message = "SopTitle 為空!!!";
            return ca;
        }

        if (wpOrder.SopTitle.Length > SopTitleMaxLength)
        {
            ca.Message = "Sop標題超過長度!!!";
            return ca;
        }

        if (wpOrder.PubDate is null && wpOrder.PubFlag == true)
        {
            wpOrder.PubDate = DateTime.Now;
        }

        var account = GetAccountByToken();
        var existing = scDb.DWorkProcesses.FirstOrDefault(wp => wp.Wpno == padded);

        if (existing is null)
        {
            wpOrder.PhraseList ??= "";
            wpOrder.FinFlag ??= false;
            wpOrder.AStatus = ActiveStatus.Active;
            wpOrder.Creator = account;
            wpOrder.CreateTime = DateTime.Now;
            wpOrder.Modifier = account;
            wpOrder.ModiTime = DateTime.Now;

            scDb.DWorkProcesses.Add(wpOrder);
        }
        else
        {
            existing.SopTitle = wpOrder.SopTitle;
            existing.PhraseList = wpOrder.PhraseList ?? "";
            existing.Descript = wpOrder.Descript;
            existing.VerNo = wpOrder.VerNo;
            existing.PubDate = wpOrder.PubDate;
            existing.PubFlag = wpOrder.PubFlag;
            existing.FinFlag = wpOrder.FinFlag;
            existing.Modifier = account;
            existing.ModiTime = DateTime.Now;

            scDb.DWorkProcesses.Update(existing);
        }

        scDb.SaveChanges();
        ca.IsSuccess = true;
        return ca;
    }

    /// <summary>軟刪除議題：aStatus 寫成 'N'，資料仍留在 DB。</summary>
    [HttpGet]
    public CustomApiViewModel DisableOrder(string wpNo)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(DisableOrder), $"wpNo:{wpNo}");

        var padded = StoragePaths.PadWpno(wpNo);
        if (padded.Length == 0)
        {
            ca.Message = $"wpNo:{wpNo} 有誤!!!";
            return ca;
        }

        var wp = scDb.DWorkProcesses.FirstOrDefault(o => o.Wpno == padded);
        if (wp is null)
        {
            ca.Message = $"查無工作流程單:{padded}!!!";
            return ca;
        }

        wp.AStatus = ActiveStatus.Inactive;
        wp.Modifier = GetAccountByToken();
        wp.ModiTime = DateTime.Now;
        scDb.DWorkProcesses.Update(wp);
        scDb.SaveChanges();

        ca.IsSuccess = true;
        return ca;
    }

    // ------------------------------------------------------------------ 進度明細

    /// <summary>
    /// 議題的所有進度。
    /// 排序用 ProcessCaption 而不是 SNo —— 標題慣例上放日期，這樣才是時序。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel GetSOPDetail(string wpNo)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(GetSOPDetail), $"wpNo:{wpNo}");

        var padded = StoragePaths.PadWpno(wpNo);
        if (padded.Length == 0)
        {
            ca.Message = $"wpno:{wpNo} 有誤!!!";
            return ca;
        }

        var details = scDb.DWorkProcessDetails
            .Where(d => d.Wpno == padded)
            .OrderBy(d => d.ProcessCaption)
            .ToList();

        if (details.Count == 0)
        {
            ca.Message = $"查無工作流程項目細項資料:{padded}!!!";
            ca.IsSuccess = true;
            return ca;
        }

        var userNameByAccount = scDb.MUsers.ToList()
            .GroupBy(u => (u.Account ?? "").Trim())
            .ToDictionary(g => g.Key, g => g.First().UserName);

        ca.Body = details.Select(d => new DWorkProcessDetailViewModel(d)
        {
            CreatorName = userNameByAccount.TryGetValue((d.Creator ?? "").Trim(), out var c) ? c : null,
            ModifierName = userNameByAccount.TryGetValue((d.Modifier ?? "").Trim(), out var m) ? m : null
        }).ToList();
        ca.IsSuccess = true;
        return ca;
    }

    /// <summary>單筆進度。</summary>
    [HttpGet]
    public CustomApiViewModel GetSOPDetailWSNo(string wpNo, string sNo)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(GetSOPDetailWSNo), $"wpNo:{wpNo}, sNo:{sNo}");

        var padded = StoragePaths.PadWpno(wpNo);
        if (padded.Length == 0)
        {
            ca.Message = $"wpno:{wpNo} 有誤!!!";
            return ca;
        }

        var paddedSno = StoragePaths.PadSno(sNo);
        var detail = scDb.DWorkProcessDetails.FirstOrDefault(d => d.Wpno == padded && d.Sno == paddedSno);

        // 新增中的進度還不存在，這不是錯誤
        ca.IsSuccess = true;
        ca.Body = detail;
        if (detail is null) ca.Message = $"{padded}:{paddedSno} 尚未建立";
        return ca;
    }

    /// <summary>
    /// 取單筆進度（編輯內文用）。
    ///
    /// 名字叫 EditorText，但為了與 1.0 相容，Body 回的是**整個 DWorkProcessDetail 物件**，
    /// 不是內文字串。前端要自己取 .processContent。
    /// 1.0 這支沒有幫 SNo 補零，這裡補上 —— 少了它，傳 "1" 而不是 "0001" 會查無資料。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel GetEditorText(string WPNo, string SNo)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(GetEditorText), $"WPNo:{WPNo}, SNo:{SNo}");

        var padded = StoragePaths.PadWpno(WPNo);
        if (padded.Length == 0)
        {
            ca.Message = $"{WPNo} 有誤!!!";
            return ca;
        }

        var paddedSno = StoragePaths.PadSno(SNo);
        var detail = scDb.DWorkProcessDetails.FirstOrDefault(d => d.Wpno == padded && d.Sno == paddedSno);
        if (detail is null)
        {
            ca.Message = $"{padded}:{paddedSno} 查無資料!!!";
            return ca;
        }

        ca.IsSuccess = true;
        ca.Body = detail;
        return ca;
    }

    /// <summary>
    /// 新增或更新一則進度。
    /// 必須是 multipart POST：內文含 base64 圖片時 query string 會超過長度上限。
    /// </summary>
    [HttpPost]
    public CustomApiViewModel SaveDetail([FromForm] DWorkProcessDetail wpDetail)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        if (wpDetail is null)
        {
            ca.Message = "wpDetail is null";
            return ca;
        }

        WriteStepLog(nameof(SaveDetail), $"wpNo:{wpDetail.Wpno}, sNo:{wpDetail.Sno}");

        var padded = StoragePaths.PadWpno(wpDetail.Wpno);
        if (padded.Length == 0)
        {
            ca.Message = $"wpNo:{wpDetail.Wpno} 有誤!!!";
            return ca;
        }
        wpDetail.Wpno = padded;

        if (!int.TryParse((wpDetail.Sno ?? "").Trim(), out var sno) || sno <= 0)
        {
            ca.Message = "Sno 為0 !!!";
            return ca;
        }
        wpDetail.Sno = sno.ToString("D4");
        wpDetail.ProcessContent = (wpDetail.ProcessContent ?? "").Trim();

        var account = GetAccountByToken();
        var existing = scDb.DWorkProcessDetails.FirstOrDefault(d => d.Wpno == wpDetail.Wpno && d.Sno == wpDetail.Sno);

        if (existing is null)
        {
            wpDetail.AStatus = ActiveStatus.Active;
            wpDetail.Creator = account;
            wpDetail.CreateTime = DateTime.Now;
            wpDetail.Modifier = account;
            wpDetail.ModiTime = DateTime.Now;
            scDb.DWorkProcessDetails.Add(wpDetail);
        }
        else
        {
            existing.ProcessCaption = wpDetail.ProcessCaption;
            existing.ProcessCaption2 = wpDetail.ProcessCaption2;
            existing.ProcessContent = wpDetail.ProcessContent;
            existing.Worker = wpDetail.Worker;
            existing.UploadFile = wpDetail.UploadFile;
            existing.RenameFile = wpDetail.RenameFile;
            existing.Modifier = account;
            existing.ModiTime = DateTime.Now;
            scDb.DWorkProcessDetails.Update(existing);
        }

        scDb.SaveChanges();
        ca.IsSuccess = true;
        return ca;
    }

    /// <summary>刪除一則進度（真刪除，不是軟刪除）。</summary>
    [HttpPost]
    public CustomApiViewModel DeleteSno(string wpNo, string sNo)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(DeleteSno), $"wpNo:{wpNo}, sNo:{sNo}");

        var padded = StoragePaths.PadWpno(wpNo);
        if (padded.Length == 0)
        {
            ca.Message = $"wpNo:{wpNo} 有誤!!!";
            return ca;
        }

        if (string.IsNullOrWhiteSpace(sNo))
        {
            ca.Message = "sNo 為空!!!";
            return ca;
        }

        var paddedSno = StoragePaths.PadSno(sNo);
        var details = scDb.DWorkProcessDetails.Where(d => d.Wpno == padded && d.Sno == paddedSno).ToList();
        if (details.Count != 1)
        {
            ca.Message = $"文件{padded}:{paddedSno} 不存在或個數不為1 !!!";
            return ca;
        }

        scDb.DWorkProcessDetails.Remove(details.First());
        scDb.SaveChanges();

        ca.IsSuccess = true;
        return ca;
    }

    // ------------------------------------------------------------------ 關鍵字主檔

    /// <summary>依 phraseType 取關鍵字（只回有效的）。</summary>
    [HttpGet]
    [RequirePermission(PermissionKeys.SalesIssue.ProcessMaintain, PermissionKeys.SalesIssue.KindMaintain)]
    public CustomApiViewModel GetKindList(string typeCode)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(GetKindList), $"typeCode:{typeCode}");

        var list = scDb.MWorkProcessPhrases
            .Where(p => p.PhraseType == typeCode && p.AStatus == ActiveStatus.Active)
            .OrderBy(p => p.PhraseCode)
            .ToList();

        if (list.Count == 0)
        {
            ca.Message = "查無工作流程項目類別資料!!!";
            return ca;
        }

        ca.IsSuccess = true;
        ca.Body = list;
        return ca;
    }

    /// <summary>
    /// 新增或更新關鍵字。
    /// 用 (PhraseType, PhraseCode) 判斷是新增還是更新 —— 撞號會蓋掉別人的資料，
    /// 呼叫端要自己確保編號不重複（前端 kind-maintain.vue 會先檢查）。
    /// </summary>
    [HttpGet]
    [RequirePermission(PermissionKeys.SalesIssue.KindMaintain)]
    public CustomApiViewModel SaveKindData([FromQuery] MWorkProcessPhrase mPhrase)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(SaveKindData), $"PhraseType:{mPhrase.PhraseType}, PhraseCode:{mPhrase.PhraseCode}");

        mPhrase.PubFlag ??= true;

        var existing = scDb.MWorkProcessPhrases
            .FirstOrDefault(p => p.PhraseType == mPhrase.PhraseType && p.PhraseCode == mPhrase.PhraseCode);

        if (existing is not null)
        {
            existing.PhraseName = mPhrase.PhraseName;
            existing.PubFlag = mPhrase.PubFlag;
            existing.Principal = mPhrase.Principal;
            existing.PotentialCustom = mPhrase.PotentialCustom;
            scDb.MWorkProcessPhrases.Update(existing);
        }
        else
        {
            // Directions 沿用 1.0：存放所屬分類的名稱，方便人工看 DB
            var type = scDb.MWorkProcessTypes.FirstOrDefault(t => t.TypeCode == mPhrase.PhraseType);

            scDb.MWorkProcessPhrases.Add(new MWorkProcessPhrase
            {
                PhraseType = mPhrase.PhraseType,
                PhraseCode = mPhrase.PhraseCode,
                PhraseName = mPhrase.PhraseName,
                PubFlag = mPhrase.PubFlag,
                Principal = mPhrase.Principal,
                PotentialCustom = mPhrase.PotentialCustom,
                Directions = type?.TypeName,
                AStatus = ActiveStatus.Active,
                Creator = GetAccountByToken(),
                CreateTime = DateTime.Now
            });
        }

        scDb.SaveChanges();
        ca.IsSuccess = true;
        return ca;
    }

    // ------------------------------------------------------------------ 議題的關鍵字 / 客戶

    /// <summary>這張議題掛了哪些關鍵字。</summary>
    [HttpGet]
    public CustomApiViewModel GetWPOrderPhrase(string wpno)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(GetWPOrderPhrase), $"wpno:{wpno}");

        var padded = StoragePaths.PadWpno(wpno);
        if (padded.Length == 0)
        {
            ca.Message = $"wpNo:{wpno} 有誤!!!";
            return ca;
        }

        var searches = scDb.DWorkProcessSearches
            .Where(s => s.AStatus == ActiveStatus.Active && s.Wpno == padded).ToList();
        var phrases = scDb.MWorkProcessPhrases
            .Where(p => p.AStatus == ActiveStatus.Active).ToList();

        var phraseByCode = phrases
            .GroupBy(p => (p.PhraseCode ?? "").Trim())
            .ToDictionary(g => g.Key, g => g.First());

        var result = searches
            .Where(s => phraseByCode.ContainsKey((s.PhraseCode ?? "").Trim()))
            .Select(s => new DWorkProcessSearchEx(s)
            {
                PhraseName = phraseByCode[(s.PhraseCode ?? "").Trim()].PhraseName
            })
            .GroupBy(s => (s.PhraseCode ?? "").Trim())
            .Select(g => g.First())
            .ToList();

        // 沒掛關鍵字不是錯誤
        ca.IsSuccess = true;
        ca.Body = result;
        if (result.Count == 0) ca.Message = $"查無關鍵字項目資料:{padded} !!!";
        return ca;
    }

    /// <summary>
    /// 整批覆寫議題的關鍵字。三個 list 用分號分隔且**必須同索引對齊**。
    /// 與 1.0 的差異：允許三個都是空字串，代表「清空這張議題的關鍵字」。
    /// 1.0 在這種情況直接回錯誤，導致取消最後一個類別後畫面與 DB 不一致。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel SetWPOrderPhrase(string wpno, string? strPhraseTypeList, string? strPhraseCodeList, string? strPhraseNameList)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(SetWPOrderPhrase), $"wpno:{wpno}, types:{strPhraseTypeList}, codes:{strPhraseCodeList}");

        var padded = StoragePaths.PadWpno(wpno);
        if (padded.Length == 0)
        {
            ca.Message = $"wpNo:{wpno} 有誤!!!";
            return ca;
        }

        var types = SplitList(strPhraseTypeList);
        var codes = SplitList(strPhraseCodeList);
        if (types.Count != codes.Count)
        {
            ca.Message = "strPhraseTypeList 與 strPhraseCodeList 個數不一致，兩者必須同索引對齊!!!";
            return ca;
        }

        var account = GetAccountByToken();
        var existing = scDb.DWorkProcessSearches
            .Where(s => s.Wpno == padded && s.AStatus == ActiveStatus.Active).ToList();

        // 不在新清單裡的移除
        foreach (var row in existing.Where(r => !codes.Contains((r.PhraseCode ?? "").Trim())))
        {
            scDb.DWorkProcessSearches.Remove(row);
        }

        // 新的加入，既有的沿用
        for (var i = 0; i < codes.Count; i++)
        {
            var match = existing.FirstOrDefault(r => (r.PhraseCode ?? "").Trim() == codes[i]);
            if (match is null)
            {
                scDb.DWorkProcessSearches.Add(new DWorkProcessSearch
                {
                    Wpno = padded,
                    PhraseType = types[i],
                    PhraseCode = codes[i],
                    AStatus = ActiveStatus.Active,
                    Creator = account,
                    CreateTime = DateTime.Now
                });
            }
            else
            {
                match.AStatus = ActiveStatus.Active;
                match.PhraseType = types[i];
                match.Modifier = account;
                match.ModiTime = DateTime.Now;
            }
        }

        scDb.SaveChanges();
        ca.IsSuccess = true;
        return ca;
    }

    /// <summary>這張議題掛了哪些客戶。</summary>
    [HttpGet]
    public CustomApiViewModel GetWPOrderCustom(string wpno)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(GetWPOrderCustom), $"wpno:{wpno}");

        var padded = StoragePaths.PadWpno(wpno);
        if (padded.Length == 0)
        {
            ca.Message = $"wpNo:{wpno} 有誤!!!";
            return ca;
        }

        var wpCustomers = scDb.DWorkProcessCustomers
            .Where(c => c.AStatus == ActiveStatus.Active && c.Wpno == padded).ToList();
        var crmByNo = scDb.CrmCustomers
            .Where(c => c.AStatus == ActiveStatus.Active).ToList()
            .GroupBy(c => (c.CustomerNo ?? "").Trim())
            .ToDictionary(g => g.Key, g => g.First());

        var result = wpCustomers.Select(c =>
        {
            crmByNo.TryGetValue((c.CustomerNo ?? "").Trim(), out var crm);
            return new DWorkProcessCustomerEx(c)
            {
                ShortName = crm?.ShortName ?? "",
                LongName = crm?.LongName ?? "",
                ContactName = crm?.ContactName ?? "",
                ContactTEL1 = crm?.ContactTel1 ?? ""
            };
        }).ToList();

        ca.IsSuccess = true;
        ca.Body = result;
        if (result.Count == 0) ca.Message = $"查無客戶項目資料:{padded} !!!";
        return ca;
    }

    /// <summary>
    /// 反過來查：這個客戶掛了哪些議題（客戶相關資訊頁的「議題」頁籤）。
    ///
    /// 參數是**內網**客戶代號。從 ERP 客戶清單點進客戶相關資訊、那個 ERP 客戶還沒建
    /// 內網客戶時傳不出內網客編，這裡會回空清單——1.0 同樣如此（它的簽章連
    /// erpCustomerNo 都沒收，前端有送也被忽略）。
    /// </summary>
    [HttpGet]
    // 客戶相關資訊（客戶檢索底下的頁面）也在查這個客戶的議題
    [RequirePermission(PermissionKeys.SalesIssue.ProcessMaintain, PermissionKeys.SalesSearch.CustomQuery)]
    public CustomApiViewModel GetWPOrderForCustom(string? customerNo)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(GetWPOrderForCustom), $"customerNo:{customerNo}");

        if (string.IsNullOrWhiteSpace(customerNo))
        {
            ca.IsSuccess = true;
            ca.Body = new List<DWorkProcessesEx>();
            return ca;
        }

        var target = customerNo.Trim();
        var wpnos = scDb.DWorkProcessCustomers
            .Where(c => c.AStatus == ActiveStatus.Active).ToList()
            .Where(c => (c.CustomerNo ?? "").Trim() == target)
            .ToList();

        var userNameByAccount = scDb.MUsers.Where(u => u.IsEnable).ToList()
            .GroupBy(u => (u.Account ?? "").Trim())
            .ToDictionary(g => g.Key, g => g.First().UserName ?? "");

        var wpByNo = scDb.DWorkProcesses
            .Where(w => w.AStatus == ActiveStatus.Active).ToList()
            .GroupBy(w => (w.Wpno ?? "").Trim())
            .ToDictionary(g => g.Key, g => g.First());

        // 作者取的是「客戶關聯那筆」的建立者，不是議題本身的建立者——1.0 join 的是
        // D_WorkProcessCustomer.Creator，照搬。
        var result = wpnos
            .Where(c => wpByNo.ContainsKey((c.Wpno ?? "").Trim()))
            .Select(c =>
            {
                userNameByAccount.TryGetValue((c.Creator ?? "").Trim(), out var userName);
                return new DWorkProcessesEx(wpByNo[(c.Wpno ?? "").Trim()]) { UserName = userName ?? "" };
            })
            .ToList();

        ca.IsSuccess = true;
        ca.Body = result;
        if (result.Count == 0) ca.Message = $"查無關鍵字客戶:{target} !!!";
        return ca;
    }

    /// <summary>
    /// 整批覆寫議題的客戶。
    /// 與 1.0 的差異：允許空字串，代表「清空客戶」。
    /// 1.0 在空字串時直接回錯，所以在畫面上把客戶改回「未指定」是存不進去的。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel SetWPOrderCustom(string wpno, string? strCustomNoList, string? strCustomNo2List)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(SetWPOrderCustom), $"wpno:{wpno}, customNos:{strCustomNoList}");

        var padded = StoragePaths.PadWpno(wpno);
        if (padded.Length == 0)
        {
            ca.Message = $"wpNo:{wpno} 有誤!!!";
            return ca;
        }

        var customNos = SplitList(strCustomNoList);
        var account = GetAccountByToken();
        var existing = scDb.DWorkProcessCustomers
            .Where(c => c.Wpno == padded && c.AStatus == ActiveStatus.Active).ToList();

        // 不在新清單裡的失效（客戶關聯是軟刪除，與關鍵字不同）
        foreach (var row in existing.Where(r => !customNos.Contains((r.CustomerNo ?? "").Trim())))
        {
            row.AStatus = ActiveStatus.Inactive;
            row.Modifier = account;
            row.ModiTime = DateTime.Now;
        }

        foreach (var customNo in customNos)
        {
            var match = existing.FirstOrDefault(r => (r.CustomerNo ?? "").Trim() == customNo);
            if (match is null)
            {
                scDb.DWorkProcessCustomers.Add(new DWorkProcessCustomer
                {
                    Wpno = padded,
                    CustomerNo = customNo,
                    CustomerType = CustomerTypeConst.Primary,
                    AStatus = ActiveStatus.Active,
                    Creator = account,
                    CreateTime = DateTime.Now
                });
            }
            else
            {
                match.AStatus = ActiveStatus.Active;
                match.Modifier = account;
                match.ModiTime = DateTime.Now;
            }
        }

        scDb.SaveChanges();
        ca.IsSuccess = true;
        return ca;
    }

    /// <summary>分號分隔字串轉清單，去空白與空值。</summary>
    private static List<string> SplitList(string? value)
        => (value ?? "").Split(';', StringSplitOptions.RemoveEmptyEntries)
            .Select(s => s.Trim())
            .Where(s => s.Length > 0)
            .ToList();
}
