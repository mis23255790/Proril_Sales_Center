namespace Proril.SalesIssue.Api.Helpers;

/// <summary>
/// 附件在檔案系統上的位置。
///
/// 一則進度的所有附件壓成一個 zip 放在 share root，要編輯就得先解到使用者的
/// temp 目錄，改完再壓回去。目錄結構（相對於 Storage:ShareRoot）：
///
///   Doc_SOP/{dcu}/{wpNo}.{detailId}.V{verNo}.zip     正本
///   Temp/{account}/Doc_SOP/{dcu}/{sNo}/              解出來的原始檔名
///   Temp/{account}/Doc_SOP_Zip/{dcu}/                重壓前的改名暫存
///
/// **dcu 中間層一律用 wpNo 算。**
/// 1.0 在這裡是不一致的：ZipAttachFileList / UpdateDBAttachFile / EnumTempUploadAttach
/// 用 wpNo，但 UnzipAttachFileList / UnzipAttachFile 用 sNo。兩者在 wpNo 與 sNo
/// 都小於 500 時剛好都是 0，所以現有資料看不出來；一旦超過就會「壓在 A 目錄、
/// 去 B 目錄找」，附件憑空消失。這裡統一成 wpNo（前端 useIssueAttachments.ts 也是）。
/// </summary>
public class StoragePaths
{
    public string ShareRoot { get; }

    public StoragePaths(IConfiguration configuration)
    {
        var configured = configuration.GetValue<string>("Storage:ShareRoot");
        if (string.IsNullOrWhiteSpace(configured))
        {
            throw new InvalidOperationException(
                "Storage:ShareRoot 未設定。必須指向與 1.0 PRORIL 相同的共享目錄，否則讀不到既有附件。");
        }

        ShareRoot = configured.TrimEnd('/', '\\');
    }

    /// <summary>議題編號補到 6 碼。非數字或 &lt;= 0 回空字串，呼叫端要當作參數有誤。</summary>
    public static string PadWpno(string? wpNo)
    {
        if (!int.TryParse((wpNo ?? "").Trim(), out var n) || n <= 0) return "";
        return n.ToString("D6");
    }

    /// <summary>進度編號補到 4 碼。</summary>
    public static string PadSno(string? sNo)
    {
        int.TryParse((sNo ?? "").Trim(), out var n);
        return n.ToString("D4");
    }

    /// <summary>中間層目錄，避免單一資料夾塞太多檔。1.0 的 FormatHelper.getDcuMiddleLayer。</summary>
    public static string DcuLayer(string wpNo)
    {
        int.TryParse((wpNo ?? "").Trim(), out var n);
        return ((int)Math.Floor(1.0 * n * 2 / 1000)).ToString("D5");
    }

    /// <summary>zip 正本所在目錄。</summary>
    public string DocSopDir(string wpNo) => $"{ShareRoot}/Doc_SOP/{DcuLayer(wpNo)}";

    /// <summary>zip 檔名（不含版號），格式為 {wpNo}.{detailId}。</summary>
    public static string ZipNameWithoutVer(string wpNo, int detailId) => $"{PadWpno(wpNo)}.{detailId}";

    /// <summary>完整 zip 檔名。</summary>
    public static string ZipFileName(string zipNameWithoutVer, string verNo) => $"{zipNameWithoutVer}.V{verNo}.zip";

    /// <summary>使用者的解壓暫存根目錄（原始檔名）。</summary>
    public string UserOrgRoot(string account) => $"{ShareRoot}/Temp/{account}/Doc_SOP";

    /// <summary>某一則進度的解壓暫存目錄。editPath 慣例上就是 sNo。</summary>
    public string UserOrgDir(string account, string wpNo, string editPath)
        => $"{UserOrgRoot(account)}/{DcuLayer(wpNo)}/{editPath}";

    /// <summary>重壓前的改名暫存根目錄。</summary>
    public string UserZipRoot(string account) => $"{ShareRoot}/Temp/{account}/Doc_SOP_Zip";

    /// <summary>重壓前的改名暫存目錄。</summary>
    public string UserZipDir(string account, string wpNo)
        => $"{UserZipRoot(account)}/{DcuLayer(wpNo)}";

    /// <summary>
    /// 下載用的相對網址，對應 Program.cs 掛在 /ShareRoot 的靜態檔目錄。
    /// 前端不會直接開這個網址（跨網域），會經 Nuxt 的 /api/download 轉一手。
    /// </summary>
    public static string DownloadUrl(string account, string wpNo, string editPath, string uploadFile)
        => $"/ShareRoot/Temp/{account}/Doc_SOP/{DcuLayer(wpNo)}/{editPath}/{uploadFile}";
}
