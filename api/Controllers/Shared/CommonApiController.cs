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
        SalesCenterDbContext scDb,
        JwtHelper jwtHelper,
        ILogger<CommonApiController> logger) : base(scDb, jwtHelper, logger)
    {
    }

    /// <summary>
    /// 某群組（部門）的預設功能清單，權限管理畫面的「群組預設功能編輯／套用」在用。
    ///
    /// M_PermissionGroup / M_Function / M_PermissionLinkType 都在 scDb。
    /// LinkType = 1 代表「這是功能本身」，沒有細項名稱可對照。
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
        var linkTypes = scDb.MPermissionLinkTypes.ToList();

        var body = groups.Select(g => new PermissionGroupViewModel
        {
            Id = g.Id,
            GroupNo = g.GroupNo,
            FunctionNo = g.FunctionNo,
            LinkType = g.LinkType,
            FunctionName = functions.FirstOrDefault(f => f.FunctionNo == g.FunctionNo)?.FunctionName ?? "",
            LinkTypeName = linkTypes.FirstOrDefault(
                t => t.FunctionNo == (g.FunctionNo ?? "") && t.LinkType == (g.LinkType ?? 0))?.LinkTypeName ?? ""
        }).ToList();

        return new CustomApiViewModel { IsSuccess = true, Body = body };
    }
}
