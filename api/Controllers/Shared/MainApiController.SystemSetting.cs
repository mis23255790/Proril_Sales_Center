using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json;
using Proril.SalesIssue.Api.Data.SalesCenter;
using Proril.SalesIssue.Api.Models;

namespace Proril.SalesIssue.Api.Controllers.Shared;

/// <summary>
/// 權限管理（1.0 系統設定 / 權限管理，Controllers/System/MainApiController_SystemSetting.cs）。
///
/// 權限樹是三層：
///   M_System（系統別，再依 SystemType 分「行政／現場／…」一層）
///     → M_Function（功能，對應 M_PermissionDef 裡 LinkType = 1 的 <c>.view</c>）
///       → M_PermissionDef 的細項（LinkType > 1，例如 <c>.viewAmount</c> 顯示金額欄位）
/// 勾選結果以 PermissionKey 寫進 M_Permission（個人，權限管理）或
/// M_PermissionGroup（群組預設功能，群組權限）。FunctionNo / LinkType 過渡期照樣一併寫，
/// 側欄（<see cref="GetUserFunctions"/>）還靠 FunctionNo。
///
/// 讀寫分兩邊，**不要弄混**：
///   - M_Permission / M_PermissionGroup / M_User / M_System / M_Function /
///     M_PermissionLinkType → scDb（Proril_Sales_Center，已切連線）
///   - M_Department → db（PRORIL_WEB，唯讀；1.0 的組織維護還在寫它）
///
/// M_System / M_Function 在新庫**只有 2.0 真的有頁面的那幾列**（3 個系統別 + 8 個功能），
/// 不是整份複製 —— 權限樹因此只會長出 2.0 管得到的功能，勾不到 1.0 還沒搬的模組。
/// 見 database/PortingNotes.md「功能主檔（M_System / M_Function）只搬 2.0 用得到的列」。
///
/// 跨庫的併表都得先各自 ToList() 再用 LINQ to Objects 併，不能寫成單一 SQL。
///
/// 1.0 那幾支已經沒有畫面在呼叫的舊端點（SetPermission / SetPermissionLinkType /
/// GetPermissionTree / GetFunctionPermissions…）沒有搬，畫面實際打的只有這裡這幾支。
/// </summary>
public partial class MainApiController
{
    private CustomApiViewModel? DenyIfNoPermissionManagerPermission()
        => HasPermission(PermissionKeys.SystemSetting.PermissionManagerView)
            ? null
            : new CustomApiViewModel { IsSuccess = false, Message = "沒有權限管理權限" };

    private CustomApiViewModel? DenyIfNoGroupPermissionPermission()
        => HasPermission(PermissionKeys.SystemSetting.GroupPermissionView)
            ? null
            : new CustomApiViewModel { IsSuccess = false, Message = "沒有群組權限權限" };

    /// <summary>
    /// 把前端勾到的 PermissionKey 換成主檔列，並補上隱含的權限：
    /// 細項一定連帶它的上層細項（ParentPermissionKey）與同功能的 <c>.view</c>——
    /// 有細項卻沒有 view 等於進不去那個畫面（1.0 processNode 的用意，原本只在前端補）。
    ///
    /// 主檔裡找不到的 key 一律擋下來回錯，不默默略過，避免前後端 key 對不上時存了一半。
    /// </summary>
    private (List<MPermissionDef> Wanted, string? Error) ResolvePermissionKeys(string? json)
    {
        var keys = JsonConvert.DeserializeObject<List<string>>(json ?? "");
        if (keys is null) return ([], "permission_keys is null!");

        var actions = scDb.MPermissionDefs
            .Where(a => a.AStatus == ActiveStatus.Active)
            .ToList();
        var byKey = actions.ToDictionary(a => a.PermissionKey);
        var viewByFunction = actions
            .Where(a => a.LinkType == 1)
            .ToDictionary(a => a.FunctionNo);

        var unknown = keys.Select(k => k.Trim()).Where(k => !byKey.ContainsKey(k)).ToList();
        if (unknown.Count > 0)
            return ([], $"未定義的權限：{string.Join(", ", unknown)}");

        var wanted = new Dictionary<string, MPermissionDef>();
        foreach (var key in keys.Select(k => k.Trim()))
        {
            var cursor = byKey[key];
            while (true)
            {
                wanted.TryAdd(cursor.PermissionKey, cursor);
                if (cursor.ParentPermissionKey is { } parent && byKey.TryGetValue(parent, out var next))
                {
                    cursor = next;
                    continue;
                }
                break;
            }
            if (viewByFunction.TryGetValue(byKey[key].FunctionNo, out var view))
                wanted.TryAdd(view.PermissionKey, view);
        }

        return ([.. wanted.Values], null);
    }

    // ------------------------------------------------------------------ 權限樹的三層主檔

    /// <summary>系統別主檔，權限樹第一層。</summary>
    [HttpGet]
    public CustomApiViewModel GetMSystem()
        => new() { IsSuccess = true, Body = scDb.MSystems.OrderBy(o => o.SystemType).ToList() };

    /// <summary>功能主檔，權限樹第二層。</summary>
    [HttpGet]
    public CustomApiViewModel GetMFunction()
        => new()
        {
            IsSuccess = true,
            Body = scDb.MFunctions
                .OrderBy(o => o.SystemNo).ThenBy(o => o.GroupNo).ThenBy(o => o.FunctionNo)
                .ToList()
        };

    /// <summary>
    /// 功能底下的細項權限，權限樹第三層以後。
    /// FunctionNo 改成 AAABBCC 之後這張表也搬進 Proril_Sales_Center 了（舊庫還是 int，
    /// 跨庫對不起來），只收 2.0 這 8 個功能的細項。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel GetMPermissionLinkType()
        => new() { IsSuccess = true, Body = scDb.MPermissionLinkTypes.OrderBy(o => o.FunctionNo).ToList() };

    /// <summary>
    /// 字串權限主檔（M_PermissionDef），2.0 權限樹的功能節點與細項節點都從這裡長。
    /// LinkType = 1 是功能本身（<c>.view</c>），其餘是細項。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel GetMPermissionDef()
        => new()
        {
            IsSuccess = true,
            Body = scDb.MPermissionDefs
                .Where(a => a.AStatus == ActiveStatus.Active)
                .OrderBy(a => a.FunctionNo).ThenBy(a => a.Sort).ThenBy(a => a.LinkType)
                .ToList()
        };

    /// <summary>
    /// 某帳號目前已有的權限列（M_Permission）。前端拿它去把樹上的 checkbox 打勾。
    /// 一併帶入保留帳號 000000（全體使用者）的列，所以「全體都有的功能」也會是勾起來的。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel GetPermissionLinkType(string account)
    {
        if (string.IsNullOrWhiteSpace(account))
            return new CustomApiViewModel { IsSuccess = true, Body = new List<MPermission>() };

        var trimmed = account.Trim();
        var permissions = scDb.MPermissions
            .Where(p => p.LinkNumber == trimmed || p.LinkNumber == PermissionConst.AccountForAll)
            .ToList();

        return new CustomApiViewModel { IsSuccess = true, Body = permissions };
    }

    // ------------------------------------------------------------------ 個人權限存檔

    /// <summary>
    /// 權限樹存檔（權限管理）。<paramref name="str_permission_keys"/> 是勾到的 PermissionKey
    /// 陣列的 JSON 字串（例如 <c>["salesSearch.mixSalesShipping.view", "salesSearch.mixSalesShipping.viewAmount"]</c>），
    /// 後端會自己補隱含的 <c>.view</c>，見 <see cref="ResolvePermissionKeys"/>。
    ///
    /// 取代 1.0 的 <c>SetPermissionTree(account, functionNos, linkTypes)</c>（已移除——
    /// 它不會寫 PermissionKey，留著會存出權限檢查認不得的列）。
    /// 做法同舊版：算出目標集合後做差集，既有列的 Creator / CreateTime 保留不動。
    /// PermissionKey 是 NULL 的列（2.0 沒有頁面的 1.0 功能，FunctionNo 還是舊數字）
    /// 不在權限樹上，存檔**不會動到它們**——FunctionNo 改格式時就是刻意保留的。
    /// （1.0 版的 SetPermissionTree 會把它們一起刪掉，這裡順便修正。）
    /// </summary>
    [HttpGet]
    public CustomApiViewModel SetPermissionKeys(string account, string str_permission_keys)
    {
        var ca = DenyIfNoPermissionManagerPermission();
        if (ca is not null) return ca;

        if (string.IsNullOrWhiteSpace(account))
            return new CustomApiViewModel { IsSuccess = false, Message = "未輸入帳號!" };

        var (wanted, error) = ResolvePermissionKeys(str_permission_keys);
        if (error is not null) return new CustomApiViewModel { IsSuccess = false, Message = error };

        var linkNumber = account.Trim();
        var wantedKeys = wanted.Select(a => a.PermissionKey).ToHashSet();
        var existing = scDb.MPermissions.Where(p => p.LinkNumber == linkNumber).ToList();

        // PermissionKey 是 NULL 的是 2.0 沒有頁面的 1.0 功能（舊數字 FunctionNo），刻意保留，不碰
        scDb.MPermissions.RemoveRange(
            existing.Where(p => p.PermissionKey is not null && !wantedKeys.Contains(p.PermissionKey)));

        var kept = existing.Where(p => p.PermissionKey is not null).Select(p => p.PermissionKey!).ToHashSet();
        var creator = GetAccountByToken();
        foreach (var action in wanted.Where(a => !kept.Contains(a.PermissionKey)))
        {
            scDb.MPermissions.Add(new MPermission
            {
                LinkNumber = linkNumber,
                PermissionKey = action.PermissionKey,
                FunctionNo = action.FunctionNo,
                LinkType = action.LinkType,
                PermissionLinkTypeId = action.PermissionLinkTypeId,
                Creator = creator,
                CreateTime = DateTime.Now
            });
        }

        scDb.SaveChanges();
        WriteStepLog(nameof(SetPermissionKeys), $"account:{linkNumber}, keys:{wanted.Count}");
        return new CustomApiViewModel { IsSuccess = true };
    }

    // ------------------------------------------------------------------ 群組預設功能

    /// <summary>
    /// 群組（部門）預設功能存檔（群組權限頁），寫 M_PermissionGroup。參數形狀同
    /// <see cref="SetPermissionKeys"/>。
    ///
    /// 這只是一份「套用範本」，存了不會改到任何人的實際權限 —— 要等有人在權限管理畫面
    /// 按「群組預設功能套用」把它套進樹裡、再按儲存，才會寫進 M_Permission。
    ///
    /// 權限要的是 <see cref="PermissionKeys.SystemSetting.GroupPermissionView"/>，
    /// 不是權限管理——群組範本從權限管理獨立出來就是為了能分開授權。
    /// 取代 1.0 的 <c>SaveDepFunction</c>（已移除，理由同 <see cref="SetPermissionKeys"/>）。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel SaveDepPermissionKeys(string depCode, string str_permission_keys)
    {
        var ca = DenyIfNoGroupPermissionPermission();
        if (ca is not null) return ca;

        if (string.IsNullOrWhiteSpace(depCode))
            return new CustomApiViewModel { IsSuccess = false, Message = "未輸入部門!" };

        var (wanted, error) = ResolvePermissionKeys(str_permission_keys);
        if (error is not null) return new CustomApiViewModel { IsSuccess = false, Message = error };

        var groupNo = depCode.Trim();
        var wantedKeys = wanted.Select(a => a.PermissionKey).ToHashSet();
        var existing = scDb.MPermissionGroups
            .Where(g => g.GroupType == PermissionGroupType.Department && g.GroupNo == groupNo)
            .ToList();

        // 同 SetPermissionKeys：PermissionKey 是 NULL 的舊功能列保留不碰
        scDb.MPermissionGroups.RemoveRange(
            existing.Where(g => g.PermissionKey is not null && !wantedKeys.Contains(g.PermissionKey)));

        var kept = existing.Where(g => g.PermissionKey is not null).Select(g => g.PermissionKey!).ToHashSet();
        var creator = GetAccountByToken();
        foreach (var action in wanted.Where(a => !kept.Contains(a.PermissionKey)))
        {
            scDb.MPermissionGroups.Add(new MPermissionGroup
            {
                GroupType = PermissionGroupType.Department,
                GroupNo = groupNo,
                PermissionKey = action.PermissionKey,
                FunctionNo = action.FunctionNo,
                LinkType = action.LinkType,
                AStatus = ActiveStatus.Active,
                Creator = creator,
                CreateTime = DateTime.Now
            });
        }

        scDb.SaveChanges();
        WriteStepLog(nameof(SaveDepPermissionKeys), $"depCode:{groupNo}, keys:{wanted.Count}");
        return new CustomApiViewModel { IsSuccess = true };
    }

    /// <summary>群組（部門）下拉。1.0 是 Razor 直接把 M_Department 渲染進 select，2.0 改成 API。</summary>
    [HttpGet]
    public CustomApiViewModel GetDepartmentList()
        => new()
        {
            IsSuccess = true,
            Body = scDb.MDepartments
                .Where(d => d.IsEnable)
                .OrderBy(d => d.DepCode)
                .Select(d => new { d.DepCode, d.DepName })
                .ToList()
        };

    // ------------------------------------------------------------------ 側欄

    /// <summary>
    /// 目前登入者可以進入的功能清單，2.0 側欄用它決定看得到哪些模組／功能
    /// （1.0 是在 _AuthLayout.cshtml 用同一組資料長選單）。
    ///
    /// admin 全開；其他人看 M_Permission 裡 LinkNumber = 自己 或 000000（全體）的列。
    /// 只回 aStatus != 'N' 的功能 —— 'N' 代表功能已停用，但權限列可能還留著。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel GetUserFunctions()
    {
        var account = GetAccountByToken();
        if (string.IsNullOrWhiteSpace(account))
            return new CustomApiViewModel { IsSuccess = false, Message = "token 無效" };

        var functions = scDb.MFunctions.Where(f => f.AStatus != ActiveStatus.Inactive).ToList();
        var systems = scDb.MSystems.ToList();

        if (!IsAdmin(account))
        {
            var allowed = scDb.MPermissions
                .Where(p => p.LinkNumber == account || p.LinkNumber == PermissionConst.AccountForAll)
                .Select(p => p.FunctionNo)
                .Distinct()
                .ToList();
            functions = functions.Where(f => allowed.Contains(f.FunctionNo)).ToList();
        }

        var body = (from f in functions
                    join s in systems on f.SystemNo equals s.SystemNo
                    orderby s.Sort, s.SystemNo, f.GroupNo, f.FunctionNo
                    select new UserFunctionViewModel
                    {
                        SystemNo = s.SystemNo,
                        SystemName = s.SystemName,
                        SystemType = s.SystemType,
                        TypeName = s.TypeName,
                        SystemSort = s.Sort,
                        FunctionNo = f.FunctionNo,
                        FunctionName = f.FunctionName ?? "",
                        GroupNo = f.GroupNo,
                        GroupName = f.GroupName
                    }).ToList();

        return new CustomApiViewModel { IsSuccess = true, Body = body };
    }
}
