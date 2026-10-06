using System.Reflection;
using System.Runtime.InteropServices;

namespace Proril.SalesIssue.Api.Helpers;

/// <summary>
/// 從 1.0 PRORIL.Helpers.LogHelper 搬過來，行為一字不差：
/// 文字檔 log，一天一個檔（yyyyMMdd.txt），依用途分子目錄。
/// Docker(Linux) 下沒有 C:\ 磁碟，路徑判斷跟 1.0 保持一致。
/// </summary>
public class LogHelper
{
    public static readonly string DefaultRootLogPath =
        RuntimeInformation.IsOSPlatform(OSPlatform.Linux) ? "/app/Logs" : "C:\\Logs\\proril_log";

    /// <summary>
    /// Controller 例外專用目錄（{DefaultRootLogPath}/exceptionLog/yyyyMMdd.txt），
    /// 在 DefaultRootLogPath 底下，所以 LogTimedHostedService 的 30 天清理一併涵蓋。
    /// </summary>
    public static readonly string ExceptionLogPath = Path.Combine(DefaultRootLogPath, "exceptionLog");

    public string LogPath { get; set; } = DefaultRootLogPath;

    public void WriteLog(string logMsg) => WriteLogTo(LogPath, logMsg);

    /// <summary>
    /// 寫進 exceptionLog 目錄。LogHelper 是 singleton，不能靠改 LogPath 切目錄
    /// （會影響同時在寫的 RequestLoggingMiddleware），所以另開方法。
    /// </summary>
    public void WriteExceptionLog(string source, Exception ex)
        => WriteLogTo(ExceptionLogPath, $"{source}\n{ex}");

    private static void WriteLogTo(string logPath, string logMsg)
    {
        try
        {
            // 容器是 UTC，log 一律用台灣時間（檔名的日期也是），見 TaiwanTime。
            DateTime now = TaiwanTime.Now;
            string logFileName = now.ToString("yyyyMMdd") + ".txt";
            string nowTime = now.ToString("HH:mm:ss.fff");

            if (!Directory.Exists(logPath))
            {
                Directory.CreateDirectory(logPath);
            }

            string fullPathName = Path.Combine(logPath, logFileName);

            using var sw = File.AppendText(fullPathName);
            sw.WriteLine("--執行時間 " + nowTime + "--");
            sw.WriteLine(logMsg);
            sw.WriteLine();
        }
        catch
        {
            // 1.0 同樣的行為：log 寫失敗就吞掉，不能因為寫 log 反而讓原本的請求掛掉。
        }
    }

    public void WriteStepLog(string userName, MethodBase methodBase, string log)
    {
        string className = methodBase.DeclaringType?.Name ?? "";
        WriteLog($" {userName} --> {className}::{methodBase.Name}:: \n{log} ");
    }

    public void LogException(Exception ex)
    {
        WriteLog(ex.Message + "\n" + ex.StackTrace);
    }
}
