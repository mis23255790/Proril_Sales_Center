using Microsoft.EntityFrameworkCore;
using Proril.SalesIssue.Api.Data.SalesCenter;

namespace Proril.SalesIssue.Api.Services;

/// <summary>
/// 銘版序號（NPS_D_Order.SerialNosJson）的取得來源。
///
/// 回傳 <c>Dictionary&lt;"{OrderType}-{RTRIM(OrderNo)}{OrderSno}", SerialNosJson&gt;</c>，
/// key 組法與原本 SQL 跨庫 JOIN 的比對規則一致。呼叫端（ManufacturingApi／SalesOrderUnFinishApi／
/// SerialNoSyncHostedService）只認這個介面，來源換成 API 時呼叫端不用改。
///
/// 用哪個實作由 <c>Services:ManufacturingCenter:SerialNoSource</c> 決定（見 <see cref="SerialNoSourceMode"/>）：
///   - <c>View</c>（預設）：<see cref="ViewSerialNoSource"/>，讀 Proril_Sales_Center 的 V_NPS_SerialNo 直連 View。
///   - <c>Api</c>：<see cref="ManufacturingSerialNoLookupService"/>，呼叫 Proril_Manufacturing_Center（目前是空殼）。
/// </summary>
public interface ISerialNoSource
{
    Dictionary<string, string> GetSerialNos();
}

public enum SerialNoSourceMode
{
    View,
    Api
}

public static class SerialNoSourceConfig
{
    public const string ConfigKey = "Services:ManufacturingCenter:SerialNoSource";

    /// <summary>沒設定時是 View；設了但不認得直接丟例外，不要靜默退回某一邊。</summary>
    public static SerialNoSourceMode GetMode(IConfiguration configuration)
    {
        var value = configuration[ConfigKey];
        if (string.IsNullOrWhiteSpace(value)) return SerialNoSourceMode.View;

        return Enum.TryParse<SerialNoSourceMode>(value, ignoreCase: true, out var mode)
            ? mode
            : throw new InvalidOperationException($"{ConfigKey} 只能是 View 或 Api，目前是「{value}」。");
    }
}

/// <summary>
/// 讀 V_NPS_SerialNo（database/NpsSerialNoObjectsMigration.sql）。
/// View 是跨庫讀 PRORIL_WEB.dbo.NPS_D_Order，執行帳號沒有那張表的 SELECT 權限時會直接丟例外，
/// 不在這裡吞掉——序號查不到跟序號查詢失敗是不同語意。
/// </summary>
public class ViewSerialNoSource(SalesCenterDbContext scDb) : ISerialNoSource
{
    public Dictionary<string, string> GetSerialNos()
        => scDb.Set<Data.VNpsSerialNo>()
            .AsNoTracking()
            .AsEnumerable()
            // NPS_D_Order 沒有保證 key 唯一，同 key 取第一筆（原本 SQL JOIN 遇到重複也是不確定取哪筆）
            .GroupBy(x => x.SerialKey)
            .ToDictionary(g => g.Key, g => g.First().SerialNosJson);
}
