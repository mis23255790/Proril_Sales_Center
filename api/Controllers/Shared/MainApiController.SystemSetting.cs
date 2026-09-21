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
///     → M_Function（功能）
///       → M_PermissionLinkType（功能底下的細項，例如「顯示金額欄位」）
/// 勾選結果寫進 M_Permission（個人）或 M_PermissionGroup（群組預設功能）。
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
        => HasFunctionPermission(FunctionIds.PermissionManager)
            ? null
            : new CustomApiViewModel { IsSuccess = false, Message = "沒有權限管理權限" };

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
    /// 權限樹存檔。參數形狀沿用 1.0：兩個 JSON 字串，一個是勾到的 FunctionNo 陣列，
    /// 一個是勾到的細項（<see cref="RetLinkType"/>）陣列。
    ///
    /// 前端存檔前會把每個勾到的節點往上找 parent 一併加進 FunctionNo 陣列
    /// （細項有權限、功能本身卻沒開，等於進不去那個畫面）。
    ///
    /// **與 1.0 的差異**：1.0 是「先刪不在清單裡的、再補沒有的」，分四段條件寫，
    /// 條件有重疊也有漏（同一批 remove 被跑了兩次）。這裡改成算出目標集合後做差集，
    /// 最終狀態一樣，既有列的 Creator / CreateTime 同樣保留不動。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel SetPermissionTree(
        string account, string str_permission_functionNos, string str_permission_linkTypes)
    {
        var ca = DenyIfNoPermissionManagerPermission();
        if (ca is not null) return ca;

        if (string.IsNullOrWhiteSpace(account))
            return new CustomApiViewModel { IsSuccess = false, Message = "未輸入帳號!" };

        var functionNos = JsonConvert.DeserializeObject<List<string>>(str_permission_functionNos ?? "");
        if (functionNos is null)
            return new CustomApiViewModel { IsSuccess = false, Message = "permission_functionNos is null!" };

        var linkTypes = JsonConvert.DeserializeObject<List<RetLinkType>>(str_permission_linkTypes ?? "");
        if (linkTypes is null)
            return new CustomApiViewModel { IsSuccess = false, Message = "permission_linkTypes is null!" };

        var linkNumber = account.Trim();
        var existing = scDb.MPermissions.Where(p => p.LinkNumber == linkNumber).ToList();

        // 全部取消勾選 = 這個帳號一個權限都沒有
        if (functionNos.Count == 0)
        {
            scDb.MPermissions.RemoveRange(existing);
            scDb.SaveChanges();
            return new CustomApiViewModel { IsSuccess = true };
        }

        // 目標集合：(FunctionNo, LinkType, PermissionLinkTypeId)
        var wanted = new HashSet<(string FunctionNo, byte LinkType, int? LinkTypeId)>();
        foreach (var functionNo in functionNos) wanted.Add((functionNo, (byte)1, null));
        foreach (var linkType in linkTypes)
        {
            byte.TryParse(linkType.LinkType, out var value);
            wanted.Add((linkType.FunctionNo, value, linkType.PermissionLinkTypeID));
        }

        var removed = existing
            .Where(p => !wanted.Contains((p.FunctionNo, p.LinkType, p.PermissionLinkTypeId)))
            .ToList();
        scDb.MPermissions.RemoveRange(removed);

        var kept = existing
            .Select(p => (p.FunctionNo, p.LinkType, p.PermissionLinkTypeId))
            .ToHashSet();
        var creator = GetAccountByToken();
        foreach (var item in wanted.Where(w => !kept.Contains(w)))
        {
            scDb.MPermissions.Add(new MPermission
            {
                LinkNumber = linkNumber,
                FunctionNo = item.FunctionNo,
                LinkType = item.LinkType,
                PermissionLinkTypeId = item.LinkTypeId,
                Creator = creator,
                CreateTime = DateTime.Now
            });
        }

        scDb.SaveChanges();
        WriteStepLog(nameof(SetPermissionTree),
            $"account:{linkNumber}, functions:{functionNos.Count}, linkTypes:{linkTypes.Count}");
        return new CustomApiViewModel { IsSuccess = true };
    }

    // ------------------------------------------------------------------ 群組預設功能

    /// <summary>
    /// 群組（部門）預設功能存檔，寫 M_PermissionGroup。
    /// 這只是一份「套用範本」，存了不會改到任何人的實際權限 —— 要等有人在權限管理畫面
    /// 按「群組預設功能套用」把它套進樹裡、再按儲存，才會寫進 M_Permission。
    ///
    /// M_PermissionGroup 沒有 PermissionLinkTypeID 欄位，細項只靠 (FunctionNo, LinkType)
    /// 認人，跟 M_Permission 不同。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel SaveDepFunction(
        string depCode, string str_permission_functionNos, string str_permission_linkTypes)
    {
        var ca = DenyIfNoPermissionManagerPermission();
        if (ca is not null) return ca;

        if (string.IsNullOrWhiteSpace(depCode))
            return new CustomApiViewModel { IsSuccess = false, Message = "未輸入部門!" };

        var functionNos = JsonConvert.DeserializeObject<List<string>>(str_permission_functionNos ?? "");
        if (functionNos is null)
            return new CustomApiViewModel { IsSuccess = false, Message = "permission_functionNos is null!" };

        var linkTypes = JsonConvert.DeserializeObject<List<RetLinkType>>(str_permission_linkTypes ?? "");
        if (linkTypes is null)
            return new CustomApiViewModel { IsSuccess = false, Message = "permission_linkTypes is null!" };

        var groupNo = depCode.Trim();
        var existing = scDb.MPermissionGroups
            .Where(g => g.GroupType == PermissionGroupType.Department && g.GroupNo == groupNo)
            .ToList();

        if (functionNos.Count == 0)
        {
            scDb.MPermissionGroups.RemoveRange(existing);
            scDb.SaveChanges();
            return new CustomApiViewModel { IsSuccess = true };
        }

        var wanted = new HashSet<(string FunctionNo, byte LinkType)>();
        foreach (var functionNo in functionNos) wanted.Add((functionNo, (byte)1));
        foreach (var linkType in linkTypes)
        {
            byte.TryParse(linkType.LinkType, out var value);
            wanted.Add((linkType.FunctionNo, value));
        }

        var removed = existing
            .Where(g => !wanted.Contains((g.FunctionNo ?? "", g.LinkType ?? 0)))
            .ToList();
        scDb.MPermissionGroups.RemoveRange(removed);

        var kept = existing.Select(g => (g.FunctionNo ?? "", g.LinkType ?? 0)).ToHashSet();
        var creator = GetAccountByToken();
        foreach (var item in wanted.Where(w => !kept.Contains(w)))
        {
            scDb.MPermissionGroups.Add(new MPermissionGroup
            {
                GroupType = PermissionGroupType.Department,
                GroupNo = groupNo,
                FunctionNo = item.FunctionNo,
                LinkType = item.LinkType,
                AStatus = ActiveStatus.Active,
                Creator = creator,
                CreateTime = DateTime.Now
            });
        }

        scDb.SaveChanges();
        WriteStepLog(nameof(SaveDepFunction), $"depCode:{groupNo}, functions:{functionNos.Count}");
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
