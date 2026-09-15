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

    public string LogPath { get; set; } = DefaultRootLogPath;

    public void WriteLog(string logMsg)
    {
        try
        {
            string logFileName = DateTime.Now.ToString("yyyyMMdd") + ".txt";
            string nowTime = DateTime.Now.ToString("HH:mm:ss.fff");

            if (!Directory.Exists(LogPath))
            {
                Directory.CreateDirectory(LogPath);
            }

            string fullPathName = Path.Combine(LogPath, logFileName);

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
