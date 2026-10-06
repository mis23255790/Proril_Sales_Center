namespace Proril.SalesIssue.Api.Helpers;

/// <summary>
/// 台灣時間（UTC+8，台灣沒有日光節約時間，固定位移即可）。
///
/// 容器時區是 UTC，<see cref="DateTime.Now"/> 會比台灣慢 8 小時。寫進資料庫的時間刻意維持
/// <c>DateTime.Now</c>（容器裡就是 UTC），只有給人看的地方（log 檔名與時間）才用這裡。
/// 用 UtcNow 固定位移而不是 TimeZoneInfo，本機（Windows）與容器結果一致，也不依賴 tzdata。
/// </summary>
public static class TaiwanTime
{
    private static readonly TimeSpan Offset = TimeSpan.FromHours(8);

    public static DateTime Now => DateTime.UtcNow + Offset;
}
