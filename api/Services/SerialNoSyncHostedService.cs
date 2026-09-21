using Microsoft.EntityFrameworkCore;
using Proril.SalesIssue.Api.Data;

namespace Proril.SalesIssue.Api.Services;

/// <summary>
/// COP_SalesOrder.SerialNosJson 原本由 prc_ImportSalesOrder 用 PRORIL_WEB.dbo.NPS_D_Order
/// 的跨庫 LEFT JOIN 即時補上；51002 執行這段 JOIN 時，執行帳號對 PRORIL_WEB 不一定有
/// SELECT 權限（見 database/prod-migration-2026-09-21/README.md），已把 SP 裡那段 JOIN
/// 註解掉，改由這支排程另外補寫。
///
/// NPS_D_Order 業務上屬於 Proril_Manufacturing_Center（銘版系統），但那邊還沒有獨立 API
/// （見 ManufacturingApiController 的說明），資料現在還是躺在 PRORIL_WEB，跟 COP_SalesOrder
/// 現階段是同一個資料庫（CopSalesOrder 還沒切到 SalesCenterDbContext），所以直接用
/// ProrilWebDbContext 下一個 UPDATE...FROM 補資料，不用等 API、不用額外的 HttpClient。
/// 哪天 Manufacturing_Center 真的有 API 了，或 CopSalesOrder 真的切連線了，把 DoWork
/// 換成「查 API + 用 SalesCenterDbContext 寫回」，排程本身的架構不用動。
/// </summary>
public class SerialNoSyncHostedService(
    IServiceScopeFactory scopeFactory,
    ILogger<SerialNoSyncHostedService> logger) : IHostedService, IDisposable
{
    private Timer? _timer;

    private static readonly TimeSpan SyncInterval = TimeSpan.FromMinutes(10);

    // NPS_D_Order 的 OrderType+OrderNo+OrderSno 组合鍵對應 COP_SalesOrder 的 TH014+TH015+TH016，
    // 跟 prc_ImportSalesOrder 原本那段 JOIN 的比對邏輯一致。
    private const string SyncSql = """
        UPDATE CSO
        SET CSO.SerialNosJson = TB.SerialNosJson
        FROM dbo.COP_SalesOrder CSO
        INNER JOIN dbo.NPS_D_Order TB
            ON TB.OrderType + '-' + RTRIM(TB.OrderNo) + TB.OrderSno
             = CSO.TH014 + '-' + RTRIM(CSO.TH015) + CSO.TH016
        WHERE CSO.SerialNosJson IS NULL
          AND TB.SerialNosJson IS NOT NULL
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
            var db = scope.ServiceProvider.GetRequiredService<ProrilWebDbContext>();

            int updated = db.Database.ExecuteSqlRaw(SyncSql);
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
