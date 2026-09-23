using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Proril.SalesIssue.Api.Data;
using Proril.SalesIssue.Api.Data.SalesCenter;
using Proril.SalesIssue.Api.Helpers;
using Proril.SalesIssue.Api.Models;

namespace Proril.SalesIssue.Api.Controllers.Shared;

/// <summary>
/// 1.0 CommonApi 的搬移目的地。目前只有權限管理的「群組預設功能」在用，
/// 1.0 那支 controller 還有一堆別的模組在用的端點，等搬到那些模組再補。
/// </summary>
[Authorize]
public class CommonApiController : BaseApiController
{
    public CommonApiController(
        ProrilWebDbContext db,
        SalesCenterDbContext scDb,
        JwtHelper jwtHelper,
        ILogger<CommonApiController> logger) : base(db, scDb, jwtHelper, logger)
    {
    }

    /// <summary>
    /// 某群組（部門）的預設功能清單。群組權限頁（編輯）與權限管理頁（套用）在用，
    /// 所以這支刻意不擋功能權限，只要登入。
    ///
    /// M_PermissionGroup / M_Function / M_PermissionDef 都在 scDb。
    /// 前端用 PermissionKey 對樹；LinkType = 1 代表「這是功能本身」，細項名稱留空。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel GetDepFunction(string depCode)
    {
        WriteStepLog(nameof(GetDepFunction), $"depCode:{depCode}");

        var groupNo = (depCode ?? "").Trim();
        var groups = scDb.MPermissionGroups
            .Where(g => g.AStatus == ActiveStatus.Active
                     && g.GroupType == PermissionGroupType.Department
                     && g.GroupNo == groupNo)
            .ToList();

        var functions = scDb.MFunctions.Where(f => f.AStatus != ActiveStatus.Inactive).ToList();
        var actions = scDb.MPermissionDefs.ToList();

        var body = groups.Select(g => new PermissionGroupViewModel
        {
            Id = g.Id,
            GroupNo = g.GroupNo,
            FunctionNo = g.FunctionNo,
            LinkType = g.LinkType,
            PermissionKey = g.PermissionKey,
            FunctionName = functions.FirstOrDefault(f => f.FunctionNo == g.FunctionNo)?.FunctionName ?? "",
            LinkTypeName = (g.LinkType ?? 1) > 1
                ? actions.FirstOrDefault(a => a.PermissionKey == g.PermissionKey)?.ActionName ?? ""
                : ""
        }).ToList();

        return new CustomApiViewModel { IsSuccess = true, Body = body };
    }
}
