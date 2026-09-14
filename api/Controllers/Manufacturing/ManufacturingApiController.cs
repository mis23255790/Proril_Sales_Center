using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Proril.SalesIssue.Api.Controllers.Shared;
using Proril.SalesIssue.Api.Data;
using Proril.SalesIssue.Api.Data.SalesCenter;
using Proril.SalesIssue.Api.Helpers;

namespace Proril.SalesIssue.Api.Controllers.Manufacturing;

/// <summary>
/// 製造模組骨架，目前還沒有任何端點。
///
/// 查詢：不屬於業務議題的表，直接用 EF 讀（現階段掛在 <see cref="ProrilWebDbContext"/>；
/// 之後如果真的有獨立的 Manufacturing_Center，再換成對應的 DbContext）。
/// 寫入：不要在這裡對其他模組/系統的表加寫入邏輯，一律呼叫那張表原本所屬系統的 API
/// （現階段是 1.0 PRORIL），理由跟 CLAUDE.md 對 M_User/M_Permission 的處理一致——
/// 業務規則只封裝在原本的 Controller 裡，繞過去直接寫會漏掉驗證、造成雙寫分歧。
/// </summary>
[Authorize]
public class ManufacturingApiController : BaseApiController
{
    public ManufacturingApiController(
        ProrilWebDbContext db,
        SalesCenterDbContext scDb,
        JwtHelper jwtHelper,
        ILogger<ManufacturingApiController> logger) : base(db, scDb, jwtHelper, logger)
    {
    }
}
