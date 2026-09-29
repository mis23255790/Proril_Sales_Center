using Microsoft.EntityFrameworkCore;
using Proril.SalesIssue.Api.Data.SalesCenter;

namespace Proril.SalesIssue.Api.Services;

/// <summary>
/// 每 10 分鐘補寫 Proril_Sales_Center 的 COP_SalesOrder.SerialNosJson（銘版序號）。
///
/// 原本由 prc_ImportSalesOrder 用 PRORIL_WEB.dbo.NPS_D_Order 的跨庫 LEFT JOIN 即時補上；
/// 51002 執行帳號對 PRORIL_WEB 不一定有 SELECT 權限（見 database/prod-migration-2026-09-21/README.md），
/// 已把 SP 裡那段 JOIN 註解掉，改由這支排程另外補寫。
///
/// 序號來源跟著 <see cref="SerialNoSourceConfig"/> 走：
///   - View（預設）：一句 UPDATE...FROM 直接 JOIN 本地的 V_NPS_SerialNo，資料不經過應用層。
///   - Api：透過 <see cref="ISerialNoSource"/> 取回整份 key→SerialNosJson，在應用層比對後寫回。
///     Manufacturing_Center 有 API 之後只要改設定，這支不用動。
///
/// 2026-09-29 以前這支是用 ProrilWebDbContext 更新**舊庫**的 COP_SalesOrder，
/// 但銷貨檢索早已改讀新庫，那段期間新庫的 SerialNosJson 都沒有被補過。
/// </summary>
public class SerialNoSyncHostedService(
    IServiceScopeFactory scopeFactory,
    IConfiguration configuration,
    ILogger<SerialNoSyncHostedService> logger) : IHostedService, IDisposable
{
    private Timer? _timer;

    private static readonly TimeSpan SyncInterval = TimeSpan.FromMinutes(10);

    // V_NPS_SerialNo.SerialKey 已經是 OrderType-RTRIM(OrderNo)+OrderSno，
    // 對應 COP_SalesOrder 的 TH014+TH015+TH016，跟 prc_ImportSalesOrder 原本那段 JOIN 的比對邏輯一致。
    private const string SyncFromViewSql = """
        UPDATE CSO
        SET CSO.SerialNosJson = V.SerialNosJson
        FROM dbo.COP_SalesOrder CSO
        INNER JOIN dbo.V_NPS_SerialNo V
            ON V.SerialKey = CSO.TH014 + '-' + RTRIM(CSO.TH015) + CSO.TH016
        WHERE CSO.SerialNosJson IS NULL
        """;

    public Task StartAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation("SerialNoSyncHostedService running.");

        _timer = new Timer(DoWork, null, TimeSpan.Zero, SyncInterval);

        return Task.CompletedTask;
    }

    private void DoWork(object? state)
    {
        try
        {
            using var scope = scopeFactory.CreateScope();
            var scDb = scope.ServiceProvider.GetRequiredService<SalesCenterDbContext>();

            int updated = SerialNoSourceConfig.GetMode(configuration) == SerialNoSourceMode.View
                ? scDb.Database.ExecuteSqlRaw(SyncFromViewSql)
                : SyncFromSource(scDb, scope.ServiceProvider.GetRequiredService<ISerialNoSource>());

            if (updated > 0)
            {
                logger.LogInformation("SerialNoSyncHostedService 補寫 {Count} 筆 SerialNosJson。", updated);
            }
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "SerialNoSyncHostedService.DoWork failed.");
        }
    }

    /// <summary>來源不在同一個資料庫（API）時：取回整份序號，應用層比對後只更新 SerialNosJson 一欄。</summary>
    private static int SyncFromSource(SalesCenterDbContext scDb, ISerialNoSource source)
    {
        var serialNos = source.GetSerialNos();
        if (serialNos.Count == 0) return 0;

        var candidates = scDb.CopSalesOrders.AsNoTracking()
            .Where(x => x.SerialNosJson == null && x.Th015 != null)
            .Select(x => new { x.Id, x.Th014, x.Th015, x.Th016 })
            .ToList();

        int count = 0;
        foreach (var row in candidates)
        {
            if (!serialNos.TryGetValue($"{row.Th014}-{row.Th015!.TrimEnd(' ')}{row.Th016}", out var json)) continue;

            // 只帶主鍵的 stub，EF 只會 UPDATE 有改到的 SerialNosJson，SaveChanges 會自動分批
            var stub = new CopSalesOrder { Id = row.Id };
            scDb.CopSalesOrders.Attach(stub);
            stub.SerialNosJson = json;
            count++;
        }

        return count == 0 ? 0 : scDb.SaveChanges();
    }

    public Task StopAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation("SerialNoSyncHostedService is stopping.");

        _timer?.Change(Timeout.Infinite, 0);

        return Task.CompletedTask;
    }

    public void Dispose()
    {
        _timer?.Dispose();
    }
}
