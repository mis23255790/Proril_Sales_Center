using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Proril.SalesIssue.Api.Controllers.Shared;
using Proril.SalesIssue.Api.Data;
using Proril.SalesIssue.Api.Helpers;
using Proril.SalesIssue.Api.Models;

namespace Proril.SalesIssue.Api.Controllers.SalesIssue;

/// <summary>
/// 業務議題主 API。端點名稱與參數大小寫刻意與 1.0 的 WorkProcessApi 一字不差，
/// 前端把 NUXT_PUBLIC_API_BASE 指過來就能直接跑，不必改任何一行。
/// </summary>
[Authorize]
public partial class WorkProcessApiController : BaseApiController
{
    private const int SopTitleMaxLength = 80;

    private readonly StoragePaths _paths;

    public WorkProcessApiController(
        SalesIssueDbContext db,
        JwtHelper jwtHelper,
        StoragePaths paths,
        ILogger<WorkProcessApiController> logger) : base(db, jwtHelper, logger)
    {
        _paths = paths;
    }

    // ------------------------------------------------------------------ 議題列表

    /// <summary>
    /// 議題列表（編輯視角）。
    ///
    /// startDate / endDate 保留在簽章上是為了相容前端既有呼叫，**目前不做任何事** ——
    /// 1.0 在 2026-06-08 改成 order by 客戶別時就把這段過濾註解掉了。
    /// 前端已改成自己對「最後修改時間」過濾。要恢復請一併更新前端的說明文字。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel GetSOPList_Edit(
        string? type2_phrase_name, string? type3_phrase_name,
        string? caption_name, string? content_name,
        bool pub_only, string? startDate, string? endDate)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };
        try
        {
            WriteStepLog(nameof(GetSOPList_Edit),
                $"type2:{type2_phrase_name}, type3:{type3_phrase_name}, caption:{caption_name}, content:{content_name}, pub_only:{pub_only}");

            var account = GetAccountByToken();
            var isAdmin = IsAdmin(account);

            // 有「公開」層級的功能權限就看得到全部
            var isPublic = db.MPermissions.Any(p =>
                p.LinkNumber == account
                && p.FunctionNo == FunctionIds.ProcessMaintain
                && p.LinkType == (byte)EWorkProcessPermission.Public);

            ca = GetSopListCore(type2_phrase_name, type3_phrase_name, caption_name, content_name, pub_only);
            if (!ca.IsSuccess) return ca;

            if (isAdmin || isPublic) return ca;
            if (ca.Body is not List<DWorkProcessesEx> sopList)
            {
                ca.IsSuccess = true;
                return ca;
            }

            // 逐議題的權限過濾：本人或全體帳號，且為「編輯」或「公開」層級
            var permissions = db.DWorkProcessPermissions
                .Where(p => p.EnableType == (byte)EWorkProcessPermission.Edit
                         || p.EnableType == (byte)EWorkProcessPermission.Public)
                .ToList()
                .Where(p => (p.Account ?? "").Trim() == account
                         || (p.Account ?? "").Trim() == PermissionConst.AccountForAll)
                .Select(p => (p.Wpno ?? "").Trim())
                .ToHashSet();

            ca.Body = sopList
                .Where(wp => permissions.Contains((wp.Wpno ?? "").Trim()))
                .GroupBy(wp => wp.Wpno)
                .Select(g => g.First())
                .ToList();
            ca.IsSuccess = true;
            return ca;
        }
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            ca.Message = ex.InnerException?.Message ?? ex.Message;
        }
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
        try
        {
            var processes = db.DWorkProcesses.Where(o => o.AStatus == ActiveStatus.Active).ToList();

            // 內文很大，列表不需要，撈的時候就跳過（1.0 也是這樣）
            var details = db.DWorkProcessDetails
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

            var phrases = db.MWorkProcessPhrases.Where(o => o.AStatus == ActiveStatus.Active).ToList();
            var searches = db.DWorkProcessSearches.Where(o => o.AStatus == ActiveStatus.Active).ToList();
            var wpCustomers = db.DWorkProcessCustomers.Where(o => o.AStatus == ActiveStatus.Active).ToList();
            var crmCustomers = db.CrmCustomers.Where(o => o.AStatus == ActiveStatus.Active).ToList();
            var users = db.MUsers.ToList();

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
                var matched = db.DWorkProcessDetails
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
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            ca.Message = ex.InnerException?.Message ?? ex.Message;
        }
        return ca;
    }

    /// <summary>全部議題（含已失效）。前端只拿它算下一個編號。</summary>
    [HttpGet]
    public CustomApiViewModel GetSOPListAll()
    {
        var ca = new CustomApiViewModel { IsSuccess = false };
        try
        {
            var list = db.DWorkProcesses.OrderByDescending(wp => wp.CreateTime).ToList();
            if (list.Count == 0)
            {
                ca.Message = "查無工作流程項目類別資料!!!";
                return ca;
            }

            ca.IsSuccess = true;
            ca.Body = list;
            return ca;
        }
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            ca.Message = ex.InnerException?.Message ?? ex.Message;
        }
        return ca;
    }

    // ------------------------------------------------------------------ 議題表頭

    [HttpGet]
    public CustomApiViewModel GetSOPOrder(string wpno)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };
        try
        {
            WriteStepLog(nameof(GetSOPOrder), $"wpno:{wpno}");

            var padded = StoragePaths.PadWpno(wpno);
            if (padded.Length == 0)
            {
                ca.Message = $"wpno:{wpno} 有誤!!!";
                return ca;
            }

            var wp = db.DWorkProcesses.FirstOrDefault(o => o.AStatus == ActiveStatus.Active && o.Wpno == padded);
            if (wp is null)
            {
                ca.Message = $"查無工作流程項目資料:{padded}!!!";
                return ca;
            }

            var result = new DWorkProcessesEx(wp);

            var wpCustomer = db.DWorkProcessCustomers
                .FirstOrDefault(c => c.Wpno == padded && c.AStatus == ActiveStatus.Active);
            if (wpCustomer is not null)
            {
                var customerNo = (wpCustomer.CustomerNo ?? "").Trim();
                result.CustomerNo = customerNo;
                result.CustomerName = db.CrmCustomers
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
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            ca.Message = ex.InnerException?.Message ?? ex.Message;
        }
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
        try
        {
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
            var existing = db.DWorkProcesses.FirstOrDefault(wp => wp.Wpno == padded);

            if (existing is null)
            {
                wpOrder.PhraseList ??= "";
                wpOrder.FinFlag ??= false;
                wpOrder.AStatus = ActiveStatus.Active;
                wpOrder.Creator = account;
                wpOrder.CreateTime = DateTime.Now;
                wpOrder.Modifier = account;
                wpOrder.ModiTime = DateTime.Now;

                db.DWorkProcesses.Add(wpOrder);
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

                db.DWorkProcesses.Update(existing);
            }

            db.SaveChanges();
            ca.IsSuccess = true;
            return ca;
        }
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            ca.Message = ex.InnerException?.Message ?? ex.Message;
        }
        return ca;
    }

    /// <summary>軟刪除議題：aStatus 寫成 'N'，資料仍留在 DB。</summary>
    [HttpGet]
    public CustomApiViewModel DisableOrder(string wpNo)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };
        try
        {
            WriteStepLog(nameof(DisableOrder), $"wpNo:{wpNo}");

            var padded = StoragePaths.PadWpno(wpNo);
            if (padded.Length == 0)
            {
                ca.Message = $"wpNo:{wpNo} 有誤!!!";
                return ca;
            }

            var wp = db.DWorkProcesses.FirstOrDefault(o => o.Wpno == padded);
            if (wp is null)
            {
                ca.Message = $"查無工作流程單:{padded}!!!";
                return ca;
            }

            wp.AStatus = ActiveStatus.Inactive;
            wp.Modifier = GetAccountByToken();
            wp.ModiTime = DateTime.Now;
            db.DWorkProcesses.Update(wp);
            db.SaveChanges();

            ca.IsSuccess = true;
            return ca;
        }
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            ca.Message = ex.InnerException?.Message ?? ex.Message;
        }
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
        try
        {
            WriteStepLog(nameof(GetSOPDetail), $"wpNo:{wpNo}");

            var padded = StoragePaths.PadWpno(wpNo);
            if (padded.Length == 0)
            {
                ca.Message = $"wpno:{wpNo} 有誤!!!";
                return ca;
            }

            var details = db.DWorkProcessDetails
                .Where(d => d.Wpno == padded)
                .OrderBy(d => d.ProcessCaption)
                .ToList();

            if (details.Count == 0)
            {
                ca.Message = $"查無工作流程項目細項資料:{padded}!!!";
                ca.IsSuccess = true;
                return ca;
            }

            var userNameByAccount = db.MUsers.ToList()
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
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            ca.Message = ex.InnerException?.Message ?? ex.Message;
        }
        return ca;
    }

    /// <summary>單筆進度。</summary>
    [HttpGet]
    public CustomApiViewModel GetSOPDetailWSNo(string wpNo, string sNo)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };
        try
        {
            WriteStepLog(nameof(GetSOPDetailWSNo), $"wpNo:{wpNo}, sNo:{sNo}");

            var padded = StoragePaths.PadWpno(wpNo);
            if (padded.Length == 0)
            {
                ca.Message = $"wpno:{wpNo} 有誤!!!";
                return ca;
            }

            var paddedSno = StoragePaths.PadSno(sNo);
            var detail = db.DWorkProcessDetails.FirstOrDefault(d => d.Wpno == padded && d.Sno == paddedSno);

            // 新增中的進度還不存在，這不是錯誤
            ca.IsSuccess = true;
            ca.Body = detail;
            if (detail is null) ca.Message = $"{padded}:{paddedSno} 尚未建立";
            return ca;
        }
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            ca.Message = ex.InnerException?.Message ?? ex.Message;
        }
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
        try
        {
            WriteStepLog(nameof(GetEditorText), $"WPNo:{WPNo}, SNo:{SNo}");

            var padded = StoragePaths.PadWpno(WPNo);
            if (padded.Length == 0)
            {
                ca.Message = $"{WPNo} 有誤!!!";
                return ca;
            }

            var paddedSno = StoragePaths.PadSno(SNo);
            var detail = db.DWorkProcessDetails.FirstOrDefault(d => d.Wpno == padded && d.Sno == paddedSno);
            if (detail is null)
            {
                ca.Message = $"{padded}:{paddedSno} 查無資料!!!";
                return ca;
            }

            ca.IsSuccess = true;
            ca.Body = detail;
            return ca;
        }
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            ca.Message = ex.InnerException?.Message ?? ex.Message;
        }
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
        try
        {
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
            var existing = db.DWorkProcessDetails.FirstOrDefault(d => d.Wpno == wpDetail.Wpno && d.Sno == wpDetail.Sno);

            if (existing is null)
            {
                wpDetail.AStatus = ActiveStatus.Active;
                wpDetail.Creator = account;
                wpDetail.CreateTime = DateTime.Now;
                wpDetail.Modifier = account;
                wpDetail.ModiTime = DateTime.Now;
                db.DWorkProcessDetails.Add(wpDetail);
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
                db.DWorkProcessDetails.Update(existing);
            }

            db.SaveChanges();
            ca.IsSuccess = true;
            return ca;
        }
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            ca.Message = ex.InnerException?.Message ?? ex.Message;
        }
        return ca;
    }

    /// <summary>刪除一則進度（真刪除，不是軟刪除）。</summary>
    [HttpPost]
    public CustomApiViewModel DeleteSno(string wpNo, string sNo)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };
        try
        {
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
            var details = db.DWorkProcessDetails.Where(d => d.Wpno == padded && d.Sno == paddedSno).ToList();
            if (details.Count != 1)
            {
                ca.Message = $"文件{padded}:{paddedSno} 不存在或個數不為1 !!!";
                return ca;
            }

            db.DWorkProcessDetails.Remove(details.First());
            db.SaveChanges();

            ca.IsSuccess = true;
            return ca;
        }
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            ca.Message = ex.InnerException?.Message ?? ex.Message;
        }
        return ca;
    }

    // ------------------------------------------------------------------ 關鍵字主檔

    /// <summary>依 phraseType 取關鍵字（只回有效的）。</summary>
    [HttpGet]
    public CustomApiViewModel GetKindList(string typeCode)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };
        try
        {
            WriteStepLog(nameof(GetKindList), $"typeCode:{typeCode}");

            var list = db.MWorkProcessPhrases
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
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            ca.Message = ex.InnerException?.Message ?? ex.Message;
        }
        return ca;
    }

    /// <summary>
    /// 新增或更新關鍵字。
    /// 用 (PhraseType, PhraseCode) 判斷是新增還是更新 —— 撞號會蓋掉別人的資料，
    /// 呼叫端要自己確保編號不重複（前端 kind-maintain.vue 會先檢查）。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel SaveKindData([FromQuery] MWorkProcessPhrase mPhrase)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };
        try
        {
            WriteStepLog(nameof(SaveKindData), $"PhraseType:{mPhrase.PhraseType}, PhraseCode:{mPhrase.PhraseCode}");

            mPhrase.PubFlag ??= true;

            var existing = db.MWorkProcessPhrases
                .FirstOrDefault(p => p.PhraseType == mPhrase.PhraseType && p.PhraseCode == mPhrase.PhraseCode);

            if (existing is not null)
            {
                existing.PhraseName = mPhrase.PhraseName;
                existing.PubFlag = mPhrase.PubFlag;
                existing.Principal = mPhrase.Principal;
                existing.PotentialCustom = mPhrase.PotentialCustom;
                db.MWorkProcessPhrases.Update(existing);
            }
            else
            {
                // Directions 沿用 1.0：存放所屬分類的名稱，方便人工看 DB
                var type = db.MWorkProcessTypes.FirstOrDefault(t => t.TypeCode == mPhrase.PhraseType);

                db.MWorkProcessPhrases.Add(new MWorkProcessPhrase
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

            db.SaveChanges();
            ca.IsSuccess = true;
            return ca;
        }
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            ca.Message = ex.InnerException?.Message ?? ex.Message;
        }
        return ca;
    }

    // ------------------------------------------------------------------ 議題的關鍵字 / 客戶

    /// <summary>這張議題掛了哪些關鍵字。</summary>
    [HttpGet]
    public CustomApiViewModel GetWPOrderPhrase(string wpno)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };
        try
        {
            WriteStepLog(nameof(GetWPOrderPhrase), $"wpno:{wpno}");

            var padded = StoragePaths.PadWpno(wpno);
            if (padded.Length == 0)
            {
                ca.Message = $"wpNo:{wpno} 有誤!!!";
                return ca;
            }

            var searches = db.DWorkProcessSearches
                .Where(s => s.AStatus == ActiveStatus.Active && s.Wpno == padded).ToList();
            var phrases = db.MWorkProcessPhrases
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
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            ca.Message = ex.InnerException?.Message ?? ex.Message;
        }
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
        try
        {
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
            var existing = db.DWorkProcessSearches
                .Where(s => s.Wpno == padded && s.AStatus == ActiveStatus.Active).ToList();

            // 不在新清單裡的移除
            foreach (var row in existing.Where(r => !codes.Contains((r.PhraseCode ?? "").Trim())))
            {
                db.DWorkProcessSearches.Remove(row);
            }

            // 新的加入，既有的沿用
            for (var i = 0; i < codes.Count; i++)
            {
                var match = existing.FirstOrDefault(r => (r.PhraseCode ?? "").Trim() == codes[i]);
                if (match is null)
                {
                    db.DWorkProcessSearches.Add(new DWorkProcessSearch
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

            db.SaveChanges();
            ca.IsSuccess = true;
            return ca;
        }
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            ca.Message = ex.InnerException?.Message ?? ex.Message;
        }
        return ca;
    }

    /// <summary>這張議題掛了哪些客戶。</summary>
    [HttpGet]
    public CustomApiViewModel GetWPOrderCustom(string wpno)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };
        try
        {
            WriteStepLog(nameof(GetWPOrderCustom), $"wpno:{wpno}");

            var padded = StoragePaths.PadWpno(wpno);
            if (padded.Length == 0)
            {
                ca.Message = $"wpNo:{wpno} 有誤!!!";
                return ca;
            }

            var wpCustomers = db.DWorkProcessCustomers
                .Where(c => c.AStatus == ActiveStatus.Active && c.Wpno == padded).ToList();
            var crmByNo = db.CrmCustomers
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
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            ca.Message = ex.InnerException?.Message ?? ex.Message;
        }
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
        try
        {
            WriteStepLog(nameof(SetWPOrderCustom), $"wpno:{wpno}, customNos:{strCustomNoList}");

            var padded = StoragePaths.PadWpno(wpno);
            if (padded.Length == 0)
            {
                ca.Message = $"wpNo:{wpno} 有誤!!!";
                return ca;
            }

            var customNos = SplitList(strCustomNoList);
            var account = GetAccountByToken();
            var existing = db.DWorkProcessCustomers
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
                    db.DWorkProcessCustomers.Add(new DWorkProcessCustomer
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

            db.SaveChanges();
            ca.IsSuccess = true;
            return ca;
        }
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            ca.Message = ex.InnerException?.Message ?? ex.Message;
        }
        return ca;
    }

    /// <summary>分號分隔字串轉清單，去空白與空值。</summary>
    private static List<string> SplitList(string? value)
        => (value ?? "").Split(';', StringSplitOptions.RemoveEmptyEntries)
            .Select(s => s.Trim())
            .Where(s => s.Length > 0)
            .ToList();
}
