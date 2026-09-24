using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Newtonsoft.Json;
using Proril.SalesIssue.Api.Data.SalesCenter;
using Proril.SalesIssue.Api.Models;
using Proril.SalesIssue.Api.Services;

namespace Proril.SalesIssue.Api.Controllers.Shared;

/// <summary>
/// 權限管理（角色制，RBAC）。
///
/// 角色（RBAC_Role）綁一組 PermissionKey（RBAC_RolePermission），帳號掛多個角色（RBAC_RoleUser）。
/// 有效權限 = 所屬角色 ∪ IsDefault 角色（everyone），IsSuperAdmin 角色（superAdmin）全放行，
/// 解析集中在 <see cref="PermissionService"/>。不做個人例外授權。
///
/// 權限樹是 RBAC_Permission 單一表自我參照（MODULE → GROUP → PAGE → ACTION，ParentKey 指父節點），
/// 側欄與權限管理的樹都從它長；勾選結果寫進角色。M_System 不再用來組樹，M_Function 已不對映，
/// M_Permission / M_PermissionGroup 是備份表，應用層不讀不寫，見 database/RbacObjectsMigration.sql。
/// 節點停用（自己或祖先 aStatus = 'N'）：側欄與權限判斷當作失效；權限管理的樹照樣列出但 disabled，
/// 角色原本勾的權限列保留（SaveRole 不會刪），節點重新啟用就恢復。
///
/// 三張表都有 aStatus：手動改成 'N' 即視為失效，這裡的讀取一律只認 'Y'。
/// 畫面上取消勾選／移除成員是直接刪列；已失效（'N'）的列在畫面上重新勾回來時改回 'Y'
/// （有唯一鍵，不能另外新增一列）。
///
/// 全部在 scDb（Proril_Sales_Center）。
/// </summary>
public partial class MainApiController
{
    private static readonly Regex RoleCodePattern = new("^[A-Za-z][A-Za-z0-9_-]{0,49}$", RegexOptions.Compiled);

    private CustomApiViewModel? DenyIfNoPermissionManagerPermission()
        => HasPermission(PermissionKeys.SystemSetting.PermissionManager)
            ? null
            : new CustomApiViewModel { IsSuccess = false, Message = "沒有權限管理權限" };

    private PermissionService Permissions => HttpContext.RequestServices.GetRequiredService<PermissionService>();

    /// <summary>
    /// 把前端勾到的 PermissionKey 換成主檔列，並沿 ParentKey 補上**所有祖先**：
    /// 勾細項 = 連帶擁有所屬頁面、分組、模組——細項有權限但頁面沒有等於進不去，
    /// 側欄也要有模組／分組才長得出來。
    ///
    /// 主檔裡找不到（或已停用）的 key 一律擋下來回錯，不默默略過，避免前後端 key 對不上時存了一半。
    /// </summary>
    private (List<RBACPermission> Wanted, string? Error) ResolvePermissionKeys(string? json)
    {
        var keys = JsonConvert.DeserializeObject<List<string>>(json ?? "");
        if (keys is null) return ([], "permission_keys is null!");

        var byKey = Permissions.ActiveNodes().ToDictionary(n => n.PermissionKey);

        var unknown = keys.Select(k => k.Trim()).Where(k => !byKey.ContainsKey(k)).ToList();
        if (unknown.Count > 0)
            return ([], $"未定義的權限：{string.Join(", ", unknown)}");

        var wanted = new Dictionary<string, RBACPermission>();
        foreach (var key in keys.Select(k => k.Trim()))
        {
            // ActiveNodes 保證祖先鏈接得到最上層、沒有迴圈
            for (var cursor = byKey[key]; ; cursor = byKey[cursor.ParentKey])
            {
                wanted.TryAdd(cursor.PermissionKey, cursor);
                if (cursor.ParentKey is null) break;
            }
        }

        return ([.. wanted.Values], null);
    }

    /// <summary>
    /// 角色清單「權限」欄要算的 key：只算有效的 PAGE / ACTION（畫面上勾得到的那些）。
    /// MODULE / GROUP 是存檔時 <see cref="ResolvePermissionKeys"/> 自動補的祖先，
    /// 算進去的話勾 5 個會顯示成 11 個；已停用的節點也不算。
    /// </summary>
    private HashSet<string> CountablePermissionKeys()
        => Permissions.ActiveNodes()
            .Where(n => n.NodeType is PermissionNodeType.Page or PermissionNodeType.Action)
            .Select(n => n.PermissionKey)
            .ToHashSet();

    // ------------------------------------------------------------------ 權限樹

    /// <summary>
    /// 權限樹節點（RBAC_Permission），依 Sort 排序。
    /// 預設只回有效節點（節點與祖先都是 'Y'）：側欄、模組首頁、麵包屑用，所以只要登入就能讀；
    /// 「這個人看得到哪些」另外用 <see cref="GetMyPermissions"/> 過濾。
    ///
    /// <paramref name="includeDisabled"/> = true 時連停用節點一起回（<c>isActive = false</c>），
    /// 給權限管理的樹顯示成 disabled——停用的功能照樣看得到、看得出哪些角色原本勾過，但不能勾。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel GetRBACPermission(bool includeDisabled = false)
        => new()
        {
            IsSuccess = true,
            Body = Permissions.TreeNodes()
                .Where(t => includeDisabled || t.IsActive)
                .Select(t => new
                {
                    t.Node.PermissionKey,
                    t.Node.NodeType,
                    t.Node.ParentKey,
                    t.Node.Label,
                    t.Node.LabelEn,
                    t.Node.Path,
                    t.Node.Icon,
                    t.Node.Description,
                    t.Node.Sort,
                    t.IsActive
                }).ToList()
        };

    // ------------------------------------------------------------------ 角色

    /// <summary>
    /// 角色清單。角色管理與人員管理（指派角色的下拉）都在用，兩個權限任一個就能讀。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel GetRoleList()
    {
        if (!HasPermission(PermissionKeys.SystemSetting.PermissionManager)
            && !HasPermission(PermissionKeys.SystemSetting.UserManager))
            return new CustomApiViewModel { IsSuccess = false, Message = "沒有權限管理權限" };

        var countable = CountablePermissionKeys();
        var permissionCounts = scDb.RBACRolePermissions
            .Where(rp => rp.AStatus == ActiveStatus.Active)
            .Select(rp => new { rp.RoleId, rp.PermissionKey })
            .ToList()
            .Where(rp => countable.Contains(rp.PermissionKey))
            .GroupBy(rp => rp.RoleId)
            .ToDictionary(g => g.Key, g => g.Count());
        var memberCounts = scDb.RBACRoleUsers
            .Where(ur => ur.AStatus == ActiveStatus.Active)
            .GroupBy(ur => ur.RoleId)
            .Select(g => new { RoleId = g.Key, Cnt = g.Count() })
            .ToDictionary(x => x.RoleId, x => x.Cnt);

        var body = scDb.RBACRoles
            .Where(r => r.AStatus == ActiveStatus.Active)
            .OrderBy(r => r.Sort).ThenBy(r => r.Id)
            .ToList()
            .Select(r => ToListItem(r, permissionCounts.GetValueOrDefault(r.Id), memberCounts.GetValueOrDefault(r.Id)))
            .ToList();

        return new CustomApiViewModel { IsSuccess = true, Body = body };
    }

    /// <summary>單一角色：基本資料 + 權限 + 成員。</summary>
    [HttpGet]
    public CustomApiViewModel GetRole(int roleId)
    {
        var ca = DenyIfNoPermissionManagerPermission();
        if (ca is not null) return ca;

        var role = scDb.RBACRoles.FirstOrDefault(r => r.Id == roleId && r.AStatus == ActiveStatus.Active);
        if (role is null) return new CustomApiViewModel { IsSuccess = false, Message = "查無角色" };

        var keys = scDb.RBACRolePermissions.Where(rp => rp.RoleId == roleId && rp.AStatus == ActiveStatus.Active)
            .Select(rp => rp.PermissionKey).OrderBy(k => k).ToList();
        var members = scDb.RBACRoleUsers.Where(ur => ur.RoleId == roleId && ur.AStatus == ActiveStatus.Active)
            .Select(ur => ur.Account).OrderBy(a => a).ToList();

        var body = new RoleDetailViewModel
        {
            Id = role.Id,
            RoleCode = role.RoleCode,
            RoleName = role.RoleName,
            Description = role.Description,
            IsSystem = role.IsSystem,
            IsSuperAdmin = role.IsSuperAdmin,
            IsDefault = role.IsDefault,
            Sort = role.Sort,
            PermissionCount = keys.Count(CountablePermissionKeys().Contains),
            MemberCount = members.Count,
            PermissionKeys = keys,
            Members = members
        };
        return new CustomApiViewModel { IsSuccess = true, Body = body };
    }

    /// <summary>
    /// 新增（<paramref name="roleId"/> = 0）或修改角色。<paramref name="str_permission_keys"/> 是
    /// PermissionKey 陣列的 JSON 字串，後端會自己補隱含的 <c>.view</c>（<see cref="ResolvePermissionKeys"/>）。
    ///
    /// 系統角色可以改名稱／說明，不能改代碼；superAdmin 全放行，權限清單忽略不存。
    /// 回傳 Body = 角色 ID。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel SaveRole(int roleId, string roleCode, string roleName, string? description,
        string str_permission_keys)
    {
        var ca = DenyIfNoPermissionManagerPermission();
        if (ca is not null) return ca;

        var code = (roleCode ?? "").Trim();
        var name = (roleName ?? "").Trim();
        if (name.Length == 0) return new CustomApiViewModel { IsSuccess = false, Message = "請輸入角色名稱" };
        if (name.Length > 50) return new CustomApiViewModel { IsSuccess = false, Message = "角色名稱最多 50 字" };
        if ((description?.Length ?? 0) > 200)
            return new CustomApiViewModel { IsSuccess = false, Message = "說明最多 200 字" };

        var (wanted, error) = ResolvePermissionKeys(str_permission_keys);
        if (error is not null) return new CustomApiViewModel { IsSuccess = false, Message = error };

        var operatorAccount = GetAccountByToken();
        RBACRole role;
        if (roleId == 0)
        {
            if (!RoleCodePattern.IsMatch(code))
                return new CustomApiViewModel { IsSuccess = false, Message = "角色代碼須為英文字母開頭，只能用英數字、底線、連字號，最多 50 字" };
            if (scDb.RBACRoles.Any(r => r.RoleCode == code))
                return new CustomApiViewModel { IsSuccess = false, Message = $"角色代碼 {code} 已存在" };

            role = new RBACRole
            {
                RoleCode = code,
                RoleName = name,
                Description = description,
                Sort = (scDb.RBACRoles.Max(r => (int?)r.Sort) ?? 0) + 1,
                AStatus = ActiveStatus.Active,
                Creator = operatorAccount,
                CreateTime = DateTime.Now
            };
            scDb.RBACRoles.Add(role);
        }
        else
        {
            var found = scDb.RBACRoles.FirstOrDefault(r => r.Id == roleId && r.AStatus == ActiveStatus.Active);
            if (found is null) return new CustomApiViewModel { IsSuccess = false, Message = "查無角色" };
            role = found;

            if (!role.IsSystem && code != role.RoleCode)
            {
                if (!RoleCodePattern.IsMatch(code))
                    return new CustomApiViewModel { IsSuccess = false, Message = "角色代碼須為英文字母開頭，只能用英數字、底線、連字號，最多 50 字" };
                if (scDb.RBACRoles.Any(r => r.RoleCode == code && r.Id != role.Id))
                    return new CustomApiViewModel { IsSuccess = false, Message = $"角色代碼 {code} 已存在" };
                role.RoleCode = code;
            }
            role.RoleName = name;
            role.Description = description;
            role.Modifier = operatorAccount;
            role.ModiTime = DateTime.Now;
        }

        using var tx = scDb.Database.BeginTransaction();
        scDb.SaveChanges();

        if (!role.IsSuperAdmin)
        {
            var wantedKeys = wanted.Select(a => a.PermissionKey).ToHashSet();
            var existing = scDb.RBACRolePermissions.Where(rp => rp.RoleId == role.Id).ToList();
            // 停用節點（自己或祖先 aStatus = 'N'）的權限列不動：畫面上是 disabled、前端也不會送，
            // 照「沒勾就刪」會把它們清掉，節點重新啟用時角色的權限就回不來了。
            var activeKeys = Permissions.ActiveNodes().Select(n => n.PermissionKey).ToHashSet();
            scDb.RBACRolePermissions.RemoveRange(existing.Where(rp =>
                rp.AStatus == ActiveStatus.Active
                && activeKeys.Contains(rp.PermissionKey)
                && !wantedKeys.Contains(rp.PermissionKey)));

            var byKey = existing.ToDictionary(rp => rp.PermissionKey);
            foreach (var key in wantedKeys)
            {
                if (byKey.TryGetValue(key, out var row))
                {
                    if (row.AStatus == ActiveStatus.Active) continue;
                    row.AStatus = ActiveStatus.Active;
                    row.Modifier = operatorAccount;
                    row.ModiTime = DateTime.Now;
                    continue;
                }
                scDb.RBACRolePermissions.Add(new RBACRolePermission
                {
                    RoleId = role.Id,
                    PermissionKey = key,
                    AStatus = ActiveStatus.Active,
                    Creator = operatorAccount,
                    CreateTime = DateTime.Now
                });
            }
            scDb.SaveChanges();
        }

        tx.Commit();
        Permissions.Invalidate();

        WriteStepLog(nameof(SaveRole), $"roleId:{role.Id}, code:{role.RoleCode}, keys:{wanted.Count}");
        return new CustomApiViewModel { IsSuccess = true, Body = role.Id };
    }

    /// <summary>刪除角色，連同它的權限與成員。系統角色不能刪。</summary>
    [HttpGet]
    public CustomApiViewModel DeleteRole(int roleId)
    {
        var ca = DenyIfNoPermissionManagerPermission();
        if (ca is not null) return ca;

        var role = scDb.RBACRoles.FirstOrDefault(r => r.Id == roleId);
        if (role is null) return new CustomApiViewModel { IsSuccess = false, Message = "查無角色" };
        if (role.IsSystem) return new CustomApiViewModel { IsSuccess = false, Message = "系統角色不能刪除" };

        using var tx = scDb.Database.BeginTransaction();
        scDb.RBACRoleUsers.Where(ur => ur.RoleId == roleId).ExecuteDelete();
        scDb.RBACRolePermissions.Where(rp => rp.RoleId == roleId).ExecuteDelete();
        scDb.RBACRoles.Where(r => r.Id == roleId).ExecuteDelete();
        tx.Commit();
        Permissions.Invalidate();

        WriteStepLog(nameof(DeleteRole), $"roleId:{roleId}, code:{role.RoleCode}");
        return new CustomApiViewModel { IsSuccess = true };
    }

    /// <summary>
    /// 設定角色成員（整批取代）。<paramref name="str_accounts"/> 是帳號陣列的 JSON 字串。
    ///
    /// - everyone 是所有人自動擁有，不能設成員。
    /// - superAdmin 只有 superAdmin 自己能改成員，而且不能把自己移出（避免沒有人能管）。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel SetRoleMembers(int roleId, string str_accounts)
    {
        var ca = DenyIfNoPermissionManagerPermission();
        if (ca is not null) return ca;

        var accounts = JsonConvert.DeserializeObject<List<string>>(str_accounts ?? "");
        if (accounts is null) return new CustomApiViewModel { IsSuccess = false, Message = "accounts is null!" };

        var role = scDb.RBACRoles.FirstOrDefault(r => r.Id == roleId && r.AStatus == ActiveStatus.Active);
        if (role is null) return new CustomApiViewModel { IsSuccess = false, Message = "查無角色" };
        if (role.IsDefault)
            return new CustomApiViewModel { IsSuccess = false, Message = "全體使用者角色不需要設定成員" };

        var operatorAccount = GetAccountByToken();
        var wanted = accounts.Select(a => a.Trim()).Where(a => a.Length > 0).ToHashSet(StringComparer.OrdinalIgnoreCase);

        if (role.IsSuperAdmin)
        {
            if (!IsAdmin(operatorAccount))
                return new CustomApiViewModel { IsSuccess = false, Message = "只有系統管理員能變更系統管理員成員" };
            if (!wanted.Contains(operatorAccount))
                return new CustomApiViewModel { IsSuccess = false, Message = "不能把自己移出系統管理員" };
        }

        var knownAccounts = scDb.MUsers.Select(u => u.Account).ToList()
            .Select(a => (a ?? "").Trim()).ToHashSet(StringComparer.OrdinalIgnoreCase);
        var unknown = wanted.Where(a => !knownAccounts.Contains(a)).ToList();
        if (unknown.Count > 0)
            return new CustomApiViewModel { IsSuccess = false, Message = $"查無帳號：{string.Join(", ", unknown)}" };

        var existing = scDb.RBACRoleUsers.Where(ur => ur.RoleId == roleId).ToList();
        scDb.RBACRoleUsers.RemoveRange(existing.Where(ur =>
            ur.AStatus == ActiveStatus.Active && !wanted.Contains(ur.Account.Trim())));
        var byAccount = existing.ToDictionary(ur => ur.Account.Trim(), StringComparer.OrdinalIgnoreCase);
        foreach (var account in wanted)
        {
            if (byAccount.TryGetValue(account, out var row))
            {
                if (row.AStatus == ActiveStatus.Active) continue;
                row.AStatus = ActiveStatus.Active;
                row.Modifier = operatorAccount;
                row.ModiTime = DateTime.Now;
                continue;
            }
            scDb.RBACRoleUsers.Add(new RBACRoleUser
            {
                Account = account,
                RoleId = roleId,
                AStatus = ActiveStatus.Active,
                Creator = operatorAccount,
                CreateTime = DateTime.Now
            });
        }
        scDb.SaveChanges();
        Permissions.Invalidate();

        WriteStepLog(nameof(SetRoleMembers), $"roleId:{roleId}, members:{wanted.Count}");
        return new CustomApiViewModel { IsSuccess = true };
    }

    /// <summary>
    /// 設定某帳號的角色（整批取代，人員管理用）。<paramref name="str_role_ids"/> 是角色 ID 陣列的 JSON 字串。
    /// IsDefault 角色（everyone）自動擁有，傳進來也會略過。superAdmin 的增減規則同 <see cref="SetRoleMembers"/>。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel SetUserRoles(string account, string str_role_ids)
    {
        var ca = DenyIfNoUserManagerPermission();
        if (ca is not null) return ca;

        var trimmed = (account ?? "").Trim();
        if (trimmed.Length == 0) return new CustomApiViewModel { IsSuccess = false, Message = "請輸入帳號" };
        if (!scDb.MUsers.ToList().Any(u => (u.Account ?? "").Trim() == trimmed))
            return new CustomApiViewModel { IsSuccess = false, Message = $"查無帳號 {trimmed}" };

        var roleIds = JsonConvert.DeserializeObject<List<int>>(str_role_ids ?? "");
        if (roleIds is null) return new CustomApiViewModel { IsSuccess = false, Message = "role_ids is null!" };

        var roles = scDb.RBACRoles.Where(r => r.AStatus == ActiveStatus.Active).ToList();
        var byId = roles.ToDictionary(r => r.Id);
        var unknown = roleIds.Where(id => !byId.ContainsKey(id)).ToList();
        if (unknown.Count > 0)
            return new CustomApiViewModel { IsSuccess = false, Message = $"查無角色：{string.Join(", ", unknown)}" };

        var wanted = roleIds.Where(id => !byId[id].IsDefault).ToHashSet();
        var existing = scDb.RBACRoleUsers.Where(ur => ur.Account == trimmed).ToList();
        var current = existing.Where(ur => ur.AStatus == ActiveStatus.Active).Select(ur => ur.RoleId).ToHashSet();

        var operatorAccount = GetAccountByToken();
        var superAdminIds = roles.Where(r => r.IsSuperAdmin).Select(r => r.Id).ToHashSet();
        var superAdminChanged = superAdminIds.Any(id => wanted.Contains(id) != current.Contains(id));
        if (superAdminChanged)
        {
            if (!IsAdmin(operatorAccount))
                return new CustomApiViewModel { IsSuccess = false, Message = "只有系統管理員能指派或移除系統管理員角色" };
            if (string.Equals(trimmed, operatorAccount, StringComparison.OrdinalIgnoreCase)
                && !superAdminIds.Any(wanted.Contains))
                return new CustomApiViewModel { IsSuccess = false, Message = "不能把自己移出系統管理員" };
        }

        scDb.RBACRoleUsers.RemoveRange(existing.Where(ur =>
            ur.AStatus == ActiveStatus.Active && !wanted.Contains(ur.RoleId)));
        var byRole = existing.ToDictionary(ur => ur.RoleId);
        foreach (var id in wanted.Where(id => !current.Contains(id)))
        {
            if (byRole.TryGetValue(id, out var row))
            {
                row.AStatus = ActiveStatus.Active;
                row.Modifier = operatorAccount;
                row.ModiTime = DateTime.Now;
                continue;
            }
            scDb.RBACRoleUsers.Add(new RBACRoleUser
            {
                Account = trimmed,
                RoleId = id,
                AStatus = ActiveStatus.Active,
                Creator = operatorAccount,
                CreateTime = DateTime.Now
            });
        }
        scDb.SaveChanges();
        Permissions.Invalidate();

        WriteStepLog(nameof(SetUserRoles), $"account:{trimmed}, roles:{string.Join(",", wanted)}");
        return new CustomApiViewModel { IsSuccess = true };
    }

    private static RoleListItemViewModel ToListItem(RBACRole r, int permissionCount, int memberCount) => new()
    {
        Id = r.Id,
        RoleCode = r.RoleCode,
        RoleName = r.RoleName,
        Description = r.Description,
        IsSystem = r.IsSystem,
        IsSuperAdmin = r.IsSuperAdmin,
        IsDefault = r.IsDefault,
        Sort = r.Sort,
        PermissionCount = permissionCount,
        MemberCount = memberCount
    };

    // ------------------------------------------------------------------ 目前登入者

    /// <summary>
    /// 目前登入者的有效權限，前端（usePermission）登入後載入一次快取，
    /// 畫面上的細項判斷（例如金額欄位）直接查這份，不用每個 key 打一次 <see cref="CheckPermission"/>。
    /// superAdmin 回 <c>isSuperAdmin = true</c>、keys 為空，前端自己當全放行。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel GetMyPermissions()
    {
        var account = GetAccountByToken();
        if (string.IsNullOrWhiteSpace(account))
            return new CustomApiViewModel { IsSuccess = false, Message = "token 無效" };

        var permissions = GetPermissions(account);
        return new CustomApiViewModel
        {
            IsSuccess = true,
            Body = new MyPermissionsViewModel
            {
                IsSuperAdmin = permissions.IsSuperAdmin,
                Keys = [.. permissions.Keys.OrderBy(k => k)]
            }
        };
    }
}
