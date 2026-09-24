using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Proril.SalesIssue.Api.Data.SalesCenter;
using Proril.SalesIssue.Api.Models;

namespace Proril.SalesIssue.Api.Controllers.Shared;

/// <summary>
/// 人員管理（1.0 系統設定 / 人員管理，Views/System/UserManager.cshtml）。
///
/// 端點名稱沿用 1.0 的 <c>MainApi/AddUser</c> 等，參數也一字不差。
///
/// **與 1.0 的三個差異**（都是刻意的，不是漏搬）：
/// 1. 回傳型別從裸 <c>bool</c> 改成 <see cref="CustomApiViewModel"/>。1.0 失敗時只回 false，
///    畫面永遠只能說「帳號新增失敗」；改成信封才有訊息可顯示，也才吃得到全域的
///    <c>ApiExceptionFilter</c>（它靠 reflection 塞 Message，塞不進 bool）。
/// 2. 後端加上功能權限檢查（<see cref="PermissionKeys.SystemSetting.UserManager"/>）。1.0 只靠前端擋。
/// 3. 多一支 <see cref="UnlockUser"/>。1.0 的 IsLocked 只有登入失敗時會被設成 true，
///    畫面上沒有任何地方解得開，只能進 DB 改；2.0 接手帳號管理後不該還要人去動 DB。
/// 4. 「管理人員」不再是 M_User.IsAdmin 開關，改成指派 superAdmin 角色
///    （<see cref="SetUserRoles"/>），而且只有 superAdmin 自己能指派。
///    1.0 任何能進人員管理的人都能把自己或別人設成管理員。
///
/// M_User 已切到 <c>scDb</c>（Proril_Sales_Center）。**1.0 站台的人員管理必須停用**，
/// 否則兩邊帳號狀態會分岔，見 database/PortingNotes.md「權限控管搬遷」。
/// </summary>
public partial class MainApiController
{
    /// <summary>初始密碼與重置後的密碼都等於帳號本身，沿用 1.0 的規則。</summary>
    private string InitialPassword(string account) => _aes.Encrypt(account);

    private CustomApiViewModel? DenyIfNoUserManagerPermission()
        => HasPermission(PermissionKeys.SystemSetting.UserManager)
            ? null
            : new CustomApiViewModel { IsSuccess = false, Message = "沒有人員管理權限" };

    /// <summary>
    /// 帳號設定。查無帳號時回 <c>IsSuccess = true</c> + <c>Body = null</c>，
    /// 讓畫面切到「新增帳號」模式——這跟 1.0 靠 <c>res == undefined</c> 判斷是同一件事。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel GetUserSetting(string account)
    {
        var ca = DenyIfNoUserManagerPermission();
        if (ca is not null) return ca;

        var trimmed = (account ?? "").Trim();
        var user = scDb.MUsers.ToList().FirstOrDefault(u => (u.Account ?? "").Trim() == trimmed);
        var roleIds = user is null ? [] : scDb.RBACRoleUsers
            .Where(ur => ur.Account == trimmed && ur.AStatus == ActiveStatus.Active)
            .Select(ur => ur.RoleId).ToList();

        return new CustomApiViewModel
        {
            IsSuccess = true,
            Body = user is null ? null : new UserSettingViewModel
            {
                Account = (user.Account ?? "").Trim(),
                UserName = user.UserName ?? "",
                IsEnable = user.IsEnable,
                IsAdmin = IsAdmin(trimmed),
                IsLocked = user.IsLocked,
                IsFirstLogin = user.IsFirstLogin,
                LastChangePwd = user.LastChangePwd,
                RoleIds = roleIds
            }
        };
    }

    /// <summary>新增帳號。初始密碼 = 帳號，並強制首次登入改密碼。角色另外用 <see cref="SetUserRoles"/> 設。</summary>
    [HttpGet]
    public CustomApiViewModel AddUser(string account, string name, bool isEnable)
    {
        var ca = DenyIfNoUserManagerPermission();
        if (ca is not null) return ca;

        var trimmed = (account ?? "").Trim();
        if (string.IsNullOrWhiteSpace(trimmed))
            return new CustomApiViewModel { IsSuccess = false, Message = "請輸入帳號" };

        if (scDb.MUsers.ToList().Any(u => (u.Account ?? "").Trim() == trimmed))
            return new CustomApiViewModel { IsSuccess = false, Message = $"帳號 {trimmed} 已存在" };

        scDb.MUsers.Add(new MUser
        {
            Account = trimmed,
            Password = InitialPassword(trimmed),
            UserName = name ?? "",
            IsEnable = isEnable,
            IsAdmin = false,  // 角色制之後不再讀這欄，一律寫 false
            IsFirstLogin = true,
            IsLocked = false
        });
        scDb.SaveChanges();

        WriteStepLog(nameof(AddUser), $"account:{trimmed}, isEnable:{isEnable}");
        return new CustomApiViewModel { IsSuccess = true };
    }

    /// <summary>變更帳號的姓名／啟用。不會動到密碼；角色另外用 <see cref="SetUserRoles"/> 設。</summary>
    [HttpGet]
    public CustomApiViewModel UpdateUser(string account, string name, bool isEnable)
    {
        var ca = DenyIfNoUserManagerPermission();
        if (ca is not null) return ca;

        var trimmed = (account ?? "").Trim();
        var user = scDb.MUsers.ToList().FirstOrDefault(u => (u.Account ?? "").Trim() == trimmed);
        if (user is null)
            return new CustomApiViewModel { IsSuccess = false, Message = $"查無帳號 {account}" };

        user.UserName = name ?? "";
        user.IsEnable = isEnable;
        scDb.SaveChanges();

        WriteStepLog(nameof(UpdateUser), $"account:{trimmed}, isEnable:{isEnable}");
        return new CustomApiViewModel { IsSuccess = true };
    }

    /// <summary>
    /// 刪除帳號。同一個交易連同他的角色（RBAC_RoleUser）一起刪——1.0 只刪 M_User，權限列會變成孤兒，
    /// 之後同工號重建帳號時會直接繼承到舊權限。
    /// 系統管理員只能由系統管理員刪。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel DeleteUser(string account)
    {
        var ca = DenyIfNoUserManagerPermission();
        if (ca is not null) return ca;

        var trimmed = (account ?? "").Trim();
        if (string.IsNullOrWhiteSpace(trimmed))
            return new CustomApiViewModel { IsSuccess = false, Message = "請輸入帳號" };

        if (trimmed == GetAccountByToken())
            return new CustomApiViewModel { IsSuccess = false, Message = "不能刪除自己的帳號" };

        if (IsAdmin(trimmed) && !IsAdmin(GetAccountByToken()))
            return new CustomApiViewModel { IsSuccess = false, Message = "只有系統管理員能刪除系統管理員帳號" };

        using var tx = scDb.Database.BeginTransaction();
        var deleted = scDb.MUsers.Where(u => u.Account == trimmed).ExecuteDelete();
        if (deleted <= 0)
            return new CustomApiViewModel { IsSuccess = false, Message = $"查無帳號 {account}" };

        scDb.RBACRoleUsers.Where(ur => ur.Account == trimmed).ExecuteDelete();
        tx.Commit();

        WriteStepLog(nameof(DeleteUser), $"account:{trimmed}");
        return new CustomApiViewModel { IsSuccess = true };
    }

    /// <summary>密碼重置：密碼改回帳號本身，並強制下次登入改密碼。</summary>
    [HttpGet]
    public CustomApiViewModel ResetPassword(string Account)
    {
        var ca = DenyIfNoUserManagerPermission();
        if (ca is not null) return ca;

        var trimmed = (Account ?? "").Trim();
        var user = scDb.MUsers.ToList().FirstOrDefault(u => (u.Account ?? "").Trim() == trimmed);
        if (user is null)
            return new CustomApiViewModel { IsSuccess = false, Message = $"查無帳號 {Account}" };

        user.Password = InitialPassword(trimmed);
        user.IsFirstLogin = true;
        user.LastChangePwd = DateTime.Now;
        scDb.SaveChanges();

        WriteStepLog(nameof(ResetPassword), $"account:{trimmed}");
        return new CustomApiViewModel { IsSuccess = true };
    }

    /// <summary>
    /// 解除鎖定。1.0 沒有這支——IsLocked 被登入失敗次數設成 true 之後只能進 DB 手動改，
    /// 2.0 既然接手帳號管理，就把它補上。順手把錯誤次數歸零，否則解完馬上又被鎖。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel UnlockUser(string account)
    {
        var ca = DenyIfNoUserManagerPermission();
        if (ca is not null) return ca;

        var trimmed = (account ?? "").Trim();
        var user = scDb.MUsers.ToList().FirstOrDefault(u => (u.Account ?? "").Trim() == trimmed);
        if (user is null)
            return new CustomApiViewModel { IsSuccess = false, Message = $"查無帳號 {account}" };

        user.IsLocked = false;
        user.PwdWrongTime = 0;
        scDb.SaveChanges();

        WriteStepLog(nameof(UnlockUser), $"account:{trimmed}");
        return new CustomApiViewModel { IsSuccess = true };
    }

    /// <summary>
    /// 全部帳號（含停用），人員管理／權限管理的工號下拉用。
    /// 跟 <c>GetUserList</c> 的差別是後者只回啟用中的帳號，那支是指派負責人在用的。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel GetAllUserList()
    {
        // IsAdmin 改由 superAdmin 角色推導，欄位名不變
        var superAdmins = (from ur in scDb.RBACRoleUsers
                           join r in scDb.RBACRoles on ur.RoleId equals r.Id
                           where r.IsSuperAdmin && r.AStatus == ActiveStatus.Active
                                 && ur.AStatus == ActiveStatus.Active
                           select ur.Account)
            .ToList()
            .Select(a => a.Trim())
            .ToHashSet(StringComparer.OrdinalIgnoreCase);

        return new CustomApiViewModel
        {
            IsSuccess = true,
            Body = scDb.MUsers
                .OrderBy(u => u.Account)
                .Select(u => new { u.Account, u.UserName, u.IsEnable, u.IsLocked })
                .ToList()
                .Select(u => new
                {
                    u.Account,
                    u.UserName,
                    u.IsEnable,
                    IsAdmin = superAdmins.Contains((u.Account ?? "").Trim()),
                    u.IsLocked
                })
                .ToList()
        };
    }
}
