using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json;
using Proril.SalesIssue.Api.Data;
using Proril.SalesIssue.Api.Helpers;
using Proril.SalesIssue.Api.Models;

namespace Proril.SalesIssue.Api.Controllers.SalesIssue;

/*
 * 逐議題的權限。
 *
 * GetSOPList_Edit 會用 D_WorkProcessPermission 過濾非 admin 使用者看得到的議題：
 * 帳號是本人或 '000000'（全體），且 EnableType 是 10(編輯) 或 20(公開)。
 *
 * 所以**每次存檔都要補寫一次 '000000' 的編輯權限**，否則新建的議題只有
 * 建立者（其實連建立者都不一定）看得到。前端 saveIssue 之後就是呼叫 SetWPNoPermissionEdit。
 */
public partial class WorkProcessApiController
{
    /// <summary>
    /// 覆寫某張議題的「可編輯」帳號清單。
    /// strAccountList 是 **JSON 陣列字串**（例如 ["000000"]），不是逗號字串。
    /// </summary>
    [HttpGet]
    [Authorize]
    public CustomApiViewModel SetWPNoPermissionEdit(string wpNo, string strAccountList)
        => SetWPNoPermission(wpNo, strAccountList, EWorkProcessPermission.Edit);

    /// <summary>覆寫某張議題的「可檢視」帳號清單。</summary>
    [HttpGet]
    [Authorize]
    public CustomApiViewModel SetWPNoPermissionView(string wpNo, string strAccountList)
        => SetWPNoPermission(wpNo, strAccountList, EWorkProcessPermission.View);

    /// <summary>加單一帳號的編輯權限（不影響其他人）。</summary>
    [HttpGet]
    [Authorize]
    public CustomApiViewModel AddWPNoPermissionEdit(string wpNo, string account)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };
        try
        {
            var padded = StoragePaths.PadWpno(wpNo);
            if (padded.Length == 0)
            {
                ca.Message = $"wpno:{wpNo} 有誤!!!";
                return ca;
            }

            if (string.IsNullOrWhiteSpace(account))
            {
                ca.Message = "account 為空!!!";
                return ca;
            }

            var trimmed = account.Trim();
            var enableType = (byte)EWorkProcessPermission.Edit;

            var exists = db.DWorkProcessPermissions
                .Where(p => p.Wpno == padded && p.EnableType == enableType).ToList()
                .Any(p => (p.Account ?? "").Trim() == trimmed);

            if (!exists)
            {
                db.DWorkProcessPermissions.Add(new DWorkProcessPermission
                {
                    Wpno = padded,
                    EnableType = enableType,
                    Account = trimmed,
                    Creator = GetAccountByToken(),
                    CreateTime = DateTime.Now
                });
                db.SaveChanges();
            }

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

    /// <summary>這張議題目前的權限列。</summary>
    [HttpGet]
    [Authorize]
    public CustomApiViewModel GetWPNoPermission(string wpNo)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };
        try
        {
            var padded = StoragePaths.PadWpno(wpNo);
            if (padded.Length == 0)
            {
                ca.Message = $"wpno:{wpNo} 有誤!!!";
                return ca;
            }

            ca.IsSuccess = true;
            ca.Body = db.DWorkProcessPermissions.Where(p => p.Wpno == padded).ToList();
            return ca;
        }
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            ca.Message = ex.InnerException?.Message ?? ex.Message;
        }
        return ca;
    }

    private CustomApiViewModel SetWPNoPermission(string wpNo, string strAccountList, EWorkProcessPermission enableType)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };
        try
        {
            WriteStepLog(nameof(SetWPNoPermission), $"wpNo:{wpNo}, accounts:{strAccountList}, type:{enableType}");

            var padded = StoragePaths.PadWpno(wpNo);
            if (padded.Length == 0)
            {
                ca.Message = $"wpno:{wpNo} 有誤!!!";
                return ca;
            }

            List<string>? accountList;
            try
            {
                accountList = JsonConvert.DeserializeObject<List<string>>(strAccountList ?? "");
            }
            catch (JsonException)
            {
                ca.Message = $"strAccountList 需為 JSON 陣列字串（例如 [\"000000\"]），收到:{strAccountList}";
                return ca;
            }

            if (accountList is null)
            {
                ca.Message = "accountList為空!!!";
                return ca;
            }

            var accounts = accountList.Select(a => (a ?? "").Trim()).Where(a => a.Length > 0).ToList();
            var type = (byte)enableType;
            var current = db.DWorkProcessPermissions
                .Where(p => p.Wpno == padded && p.EnableType == type).ToList();

            foreach (var row in current.Where(r => !accounts.Contains((r.Account ?? "").Trim())))
            {
                db.DWorkProcessPermissions.Remove(row);
            }

            var existingAccounts = current.Select(r => (r.Account ?? "").Trim()).ToHashSet();
            foreach (var account in accounts.Where(a => !existingAccounts.Contains(a)))
            {
                db.DWorkProcessPermissions.Add(new DWorkProcessPermission
                {
                    Wpno = padded,
                    EnableType = type,
                    Account = account,
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
}
