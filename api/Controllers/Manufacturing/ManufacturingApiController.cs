using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Proril.SalesIssue.Api.Controllers.Shared;
using Proril.SalesIssue.Api.Data;
using Proril.SalesIssue.Api.Data.SalesCenter;
using Proril.SalesIssue.Api.Helpers;
using Proril.SalesIssue.Api.Models;
using Proril.SalesIssue.Api.Services;

namespace Proril.SalesIssue.Api.Controllers.Manufacturing;

/// <summary>
/// 製造模組骨架。
///
/// 查詢：api/ 已不連 PRORIL_WEB，要讀製造端的表一律在 Proril_Sales_Center 建直連 View
/// 再用 <c>scDb</c> 讀（例如 V_NPS_SerialNo）；之後如果真的有獨立的 Manufacturing_Center，
/// 再換成呼叫它的 API。
/// 寫入：不要在這裡對其他模組/系統的表加寫入邏輯，一律呼叫那張表原本所屬系統的 API
/// （現階段是 1.0 PRORIL），理由跟 CLAUDE.md 對 M_User/M_Permission 的處理一致——
/// 業務規則只封裝在原本的 Controller 裡，繞過去直接寫會漏掉驗證、造成雙寫分歧。
///
/// <see cref="GetSerialNos"/> 是這個模組的第一個端點：銘版序號（NPS_D_Order）查詢，
/// 原本是 V_UnfinOrder／prc_ImportSalesOrder 裡的跨庫 LEFT JOIN，51002 執行帳號對
/// PRORIL_WEB 沒有 SELECT 權限會直接失敗，已拿掉那些 JOIN，改成這裡集中查、
/// 呼叫端在應用層 left join 回去（見 <see cref="ISerialNoSource"/>，目前預設讀 V_NPS_SerialNo 直連 View）。
/// 哪天 Proril_Manufacturing_Center 真的獨立成有自己 API 的服務，只要把這支端點的
/// 實作換成呼叫該服務，呼叫端（Controller 們）完全不用改。
/// </summary>
[Authorize]
public class ManufacturingApiController : BaseApiController
{
    private readonly ISerialNoSource _serialNoLookup;

    public ManufacturingApiController(
        SalesCenterDbContext scDb,
        JwtHelper jwtHelper,
        ISerialNoSource serialNoLookup,
        ILogger<ManufacturingApiController> logger) : base(scDb, jwtHelper, logger)
    {
        _serialNoLookup = serialNoLookup;
    }

    /// <summary>
    /// 銘版序號查詢，key 是 <c>"{OrderType}-{RTRIM(OrderNo)}{OrderSno}"</c>，
    /// value 是 SerialNosJson。目前資料來源是 PRORIL_WEB.dbo.NPS_D_Order（經 V_NPS_SerialNo），
    /// 不接受參數、回傳全部有序號的列——NPS_D_Order 目前的規模跟原本的跨庫 JOIN
    /// 一樣是整張表下去比對，沒有比原本更差。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel GetSerialNos()
    {
        var ca = new CustomApiViewModel { IsSuccess = true };
        ca.Body = _serialNoLookup.GetSerialNos();
        return ca;
    }
}
