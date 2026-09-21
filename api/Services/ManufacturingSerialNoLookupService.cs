using System.Text.Json;
using Proril.SalesIssue.Api.Models;

namespace Proril.SalesIssue.Api.Services;

/// <summary>
/// 銘版序號（NPS_D_Order）查詢——業務上屬於 Proril_Manufacturing_Center。
///
/// 這是 API 空殼：Proril_Manufacturing_Center 那邊還沒有對應端點，
/// <c>Services:ManufacturingCenter:BaseUrl</c> 也還沒填值，現在呼叫一定會丟例外。
/// 等對方端點確定後，把 <see cref="EndpointPath"/> 換成真正的路由、appsettings 填上
/// 網址即可，呼叫端（ManufacturingApiController／SalesOrderUnFinishApiController）
/// 完全不用改——回傳形狀維持 <c>Dictionary&lt;OrderType-RTRIM(OrderNo)+OrderSno, SerialNosJson&gt;</c>，
/// key 組法跟原本 SQL 比對邏輯一致。
///
/// 預期對方回傳格式沿用專案既有的 <see cref="CustomApiViewModel"/> 信封
/// （isSuccess/message/body/body2，camelCase），Body 是上述 Dictionary——這是照專案慣例猜的，
/// 對方端點真正確定時要回頭核對，格式不同就要調整這裡的解析。
///
/// 失敗（網址未設定／連不上／isSuccess=false／格式對不上）一律丟例外，讓全域
/// ApiExceptionFilter 接住，不在這裡吞掉或回空清單——序號查不到跟序號查詢失敗是
/// 不同的語意，不該被當成「沒有序號」。
/// </summary>
public class ManufacturingSerialNoLookupService(IHttpClientFactory httpClientFactory, IConfiguration configuration)
{
    // TODO: Proril_Manufacturing_Center 的端點路由確定後換成實際值。
    private const string EndpointPath = "/api/SerialNo/GetSerialNos";

    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public Dictionary<string, string> GetSerialNos()
    {
        var baseUrl = configuration["Services:ManufacturingCenter:BaseUrl"];
        if (string.IsNullOrWhiteSpace(baseUrl))
        {
            throw new InvalidOperationException(
                "Services:ManufacturingCenter:BaseUrl 未設定。ManufactureCenter API 尚未上線，"
                + "或尚未在 appsettings.Development.json（本機）／環境變數 Services__ManufacturingCenter__BaseUrl"
                + "（部署）填入網址。");
        }

        using var client = httpClientFactory.CreateClient("ManufacturingCenter");
        using var request = new HttpRequestMessage(HttpMethod.Get, $"{baseUrl.TrimEnd('/')}{EndpointPath}");
        using var response = client.Send(request);

        if (!response.IsSuccessStatusCode)
        {
            throw new InvalidOperationException(
                $"ManufactureCenter GetSerialNos 回傳非成功狀態碼：{(int)response.StatusCode} {response.StatusCode}。");
        }

        using var stream = response.Content.ReadAsStream();
        var envelope = JsonSerializer.Deserialize<CustomApiViewModel>(stream, JsonOptions)
            ?? throw new InvalidOperationException("ManufactureCenter GetSerialNos 回傳空內容。");

        if (!envelope.IsSuccess)
        {
            throw new InvalidOperationException($"ManufactureCenter GetSerialNos 失敗：{envelope.Message}");
        }

        if (envelope.Body is not JsonElement body)
        {
            throw new InvalidOperationException("ManufactureCenter GetSerialNos 的 Body 格式不是預期的物件。");
        }

        return JsonSerializer.Deserialize<Dictionary<string, string>>(body.GetRawText(), JsonOptions)
            ?? [];
    }
}
