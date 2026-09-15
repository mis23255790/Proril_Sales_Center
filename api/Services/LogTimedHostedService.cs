using System.Globalization;
using Proril.SalesIssue.Api.Helpers;

namespace Proril.SalesIssue.Api.Services;

/// <summary>
/// 從 1.0 PRORIL.Service.LogTimedHostedService 搬過來：
/// 每天凌晨清理 LogHelper 寫出來的 log 檔案，保留 30 天。
/// </summary>
public class LogTimedHostedService(ILogger<LogTimedHostedService> logger) : IHostedService, IDisposable
{
    private Timer? _timer;

    private const int CleanupHour = 1;
    private static readonly TimeSpan CleanupInterval = TimeSpan.FromDays(1);
    private const int KeepDays = 30;

    public Task StartAsync(CancellationToken stoppingToken)
    {
        try
        {
            logger.LogInformation("LogTimedHostedService running.");

            _timer = new Timer(DoWork, null, GetDelayToNextRun(), CleanupInterval);

            _ = Task.Run(() => DoWork(null), stoppingToken);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "LogTimedHostedService.StartAsync failed.");
        }

        return Task.CompletedTask;
    }

    private static TimeSpan GetDelayToNextRun()
    {
        DateTime now = DateTime.Now;
        DateTime nextRun = now.Date.AddHours(CleanupHour);
        if (nextRun <= now)
        {
            nextRun = nextRun.AddDays(1);
        }

        return nextRun - now;
    }

    private void DoWork(object? state)
    {
        try
        {
            string logPath = LogHelper.DefaultRootLogPath;

            if (Directory.Exists(logPath))
            {
                Cleanup(logPath);
                logger.LogInformation("已清理目錄(含子目錄): {LogPath}", logPath);
            }
            else
            {
                logger.LogDebug("目錄不存在，跳過清理: {LogPath}", logPath);
            }
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "LogTimedHostedService.DoWork failed.");
        }
    }

    private void Cleanup(string path)
    {
        try
        {
            DateTime today = DateTime.Now.Date;

            var txtFiles = Directory.EnumerateFiles(path, "*.txt", SearchOption.AllDirectories);
            foreach (string txtFile in txtFiles)
            {
                string filename = Path.GetFileNameWithoutExtension(txtFile);

                if (!DateTime.TryParseExact(filename, "yyyyMMdd", CultureInfo.InvariantCulture,
                        DateTimeStyles.None, out DateTime fileDate))
                {
                    continue;
                }

                if ((today - fileDate.Date).TotalDays <= KeepDays)
                    continue;

                File.Delete(txtFile);
            }
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "LogTimedHostedService.Cleanup failed.");
        }
    }

    public Task StopAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation("LogTimedHostedService is stopping.");

        _timer?.Change(Timeout.Infinite, 0);

        return Task.CompletedTask;
    }

    public void Dispose()
    {
        _timer?.Dispose();
    }
}
