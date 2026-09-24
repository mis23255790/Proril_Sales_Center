using Microsoft.EntityFrameworkCore;
using Proril.SalesIssue.Api.Data.SalesCenter;
using Proril.SalesIssue.Api.Models;

namespace Proril.SalesIssue.Api.Services;

/// <summary>某帳號的有效權限：superAdmin 全放行，否則看 <see cref="Keys"/>。</summary>
public sealed record EffectivePermissions(bool IsSuperAdmin, IReadOnlySet<string> Keys)
{
    public static readonly EffectivePermissions None = new(false, new HashSet<string>());

    public bool Has(string permissionKey) => IsSuperAdmin || Keys.Contains(permissionKey);
}

/// <summary>
/// 角色制（RBAC）的權限解析，BaseApiController.HasPermission 與 RequirePermissionAttribute 共用。
///
/// 有效權限 = 帳號自己掛的角色（RBAC_RoleUser）∪ IsDefault 角色（everyone），
/// 角色、角色的權限列、帳號的角色列都只算 aStatus = 'Y'（手動改成 'N' = 失效），
/// key 也只收 RBAC_Permission 裡仍啟用的節點——節點本身與**所有祖先**都要是 'Y'
/// （把整個模組設成 'N'，底下頁面與細項一起失效，見 <see cref="ActiveNodes"/>）。
/// 帳號不存在、停用或鎖定一律沒有任何權限——token 是 24 小時有效、不帶權限，
/// 不在這裡擋的話停用帳號手上的舊 token 還能繼續用。
///
/// Scoped：同一個 request 內同一帳號只查一次 DB（匯出 Excel 那幾支一個 request 會問好幾次）。
/// 資料見 database/RbacObjectsMigration.sql、docs/modules/SystemSetting/logic.md。
/// </summary>
public class PermissionService(SalesCenterDbContext scDb)
{
    private readonly Dictionary<string, EffectivePermissions> _cache = new(StringComparer.OrdinalIgnoreCase);

    public EffectivePermissions Resolve(string? account)
    {
        var trimmed = account?.Trim() ?? "";
        if (trimmed.Length == 0) return EffectivePermissions.None;
        if (_cache.TryGetValue(trimmed, out var cached)) return cached;

        var result = Load(trimmed);
        _cache[trimmed] = result;
        return result;
    }

    /// <summary>角色有異動時（存角色、改成員）清掉本 request 的快取。</summary>
    public void Invalidate() => _cache.Clear();

    private List<TreeNode>? _treeNodes;
    private List<RBACPermission>? _activeNodes;

    /// <summary>權限樹上的一個節點，<see cref="IsActive"/> = 自己與所有祖先都是 aStatus = 'Y'。</summary>
    public sealed record TreeNode(RBACPermission Node, bool IsActive);

    /// <summary>
    /// 掛得上權限樹的全部節點（含停用的），依 Sort 排序。祖先鏈要接得到最上層——
    /// ParentKey 指到不存在或形成迴圈的節點放不進樹，直接不收。
    /// 權限管理的樹用它（停用節點顯示成 disabled）；判斷權限、側欄一律用 <see cref="ActiveNodes"/>。
    /// 整張表很小，一次載入後在記憶體算。
    /// </summary>
    public IReadOnlyList<TreeNode> TreeNodes()
    {
        if (_treeNodes is not null) return _treeNodes;

        var all = scDb.RBACPermissions.AsNoTracking().ToList();
        var byKey = all.ToDictionary(n => n.PermissionKey);
        // null = 祖先鏈斷掉或有迴圈，放不進樹
        var memo = new Dictionary<string, bool?>();

        bool? Resolve(RBACPermission node, HashSet<string> visiting)
        {
            if (memo.TryGetValue(node.PermissionKey, out var known)) return known;
            bool? result;
            if (!visiting.Add(node.PermissionKey)) result = null;
            else if (node.ParentKey is not { } parentKey) result = node.AStatus == ActiveStatus.Active;
            else if (!byKey.TryGetValue(parentKey, out var parent)) result = null;
            else
            {
                var parentActive = Resolve(parent, visiting);
                result = parentActive is null ? null : parentActive.Value && node.AStatus == ActiveStatus.Active;
            }
            memo[node.PermissionKey] = result;
            return result;
        }

        _treeNodes = all
            .Select(n => (Node: n, Active: Resolve(n, [])))
            .Where(x => x.Active is not null)
            .OrderBy(x => x.Node.Sort).ThenBy(x => x.Node.PermissionKey)
            .Select(x => new TreeNode(x.Node, x.Active!.Value))
            .ToList();
        return _treeNodes;
    }

    /// <summary>
    /// 有效的權限樹節點：自己與往上每一層祖先都是 aStatus = 'Y'，而且祖先鏈接得到最上層
    /// （ParentKey 指到不存在或形成迴圈的節點不算）。
    /// </summary>
    public IReadOnlyList<RBACPermission> ActiveNodes()
        => _activeNodes ??= TreeNodes().Where(t => t.IsActive).Select(t => t.Node).ToList();

    private EffectivePermissions Load(string account)
    {
        var user = scDb.MUsers.AsNoTracking()
            .Where(u => u.Account == account)
            .Select(u => new { u.IsEnable, u.IsLocked })
            .FirstOrDefault();
        if (user is null || !user.IsEnable || user.IsLocked) return EffectivePermissions.None;

        var roleIds = scDb.RBACRoleUsers
            .Where(ur => ur.Account == account && ur.AStatus == ActiveStatus.Active)
            .Select(ur => ur.RoleId);
        var roles = scDb.RBACRoles.AsNoTracking()
            .Where(r => r.AStatus == ActiveStatus.Active && (r.IsDefault || roleIds.Contains(r.Id)))
            .Select(r => new { r.Id, r.IsSuperAdmin })
            .ToList();

        if (roles.Any(r => r.IsSuperAdmin)) return new EffectivePermissions(true, new HashSet<string>());

        var ids = roles.Select(r => r.Id).ToList();
        var granted = scDb.RBACRolePermissions
            .Where(rp => ids.Contains(rp.RoleId) && rp.AStatus == ActiveStatus.Active)
            .Select(rp => rp.PermissionKey)
            .Distinct()
            .ToList();
        var active = ActiveNodes().Select(n => n.PermissionKey).ToHashSet();

        return new EffectivePermissions(false, granted.Where(active.Contains).ToHashSet());
    }
}
