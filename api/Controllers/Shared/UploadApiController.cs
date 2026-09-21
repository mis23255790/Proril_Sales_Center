using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Proril.SalesIssue.Api.Data.SalesCenter;
using Proril.SalesIssue.Api.Helpers;
using Proril.SalesIssue.Api.Models;

namespace Proril.SalesIssue.Api.Controllers.Shared;

/// <summary>
/// 檔案上傳。只搬業務議題會用到的 SaveByFileName（單檔存到指定路徑）。
///
/// 1.0 還有 SaveZipFile / SaveByPath 等，那些是別的模組在用，等搬到那些模組再補。
/// H_FileLink 打 <see cref="scDb"/>（Proril_Sales_Center，已確認單一擁有者，
/// 只有這支的 AddFileLog 在寫）。
/// </summary>
[Authorize]
public class UploadApiController : BaseApiController
{
    private const int MaxMb = 10;
    private const long MaxUploadSize = MaxMb * 1024L * 1024L;

    private readonly StoragePaths _paths;

    public UploadApiController(
        SalesCenterDbContext scDb,
        JwtHelper jwtHelper,
        StoragePaths paths,
        ILogger<UploadApiController> logger) : base(scDb, jwtHelper, logger)
    {
        _paths = paths;
    }

    /// <summary>
    /// 上傳單一檔案到 share root 底下的指定相對路徑。
    ///
    /// saveByFileName 是**相對於 Storage:ShareRoot 的完整路徑（含檔名）**，
    /// 例如 /Temp/112012/Doc_SOP/00000/3/報價單.pdf。
    /// </summary>
    /// <remarks>
    /// saveByFileName/linkFuncNo/linkNo 一定要 <c>[FromForm]</c>：有 <c>List&lt;IFormFile&gt;</c>
    /// 參數時，<c>[ApiController]</c> 對一般 string 參數的來源推斷預設是 FromQuery，不會退回
    /// 去找 multipart form 裡的欄位。前端是用 FormData 把這三個欄位跟檔案包在同一個
    /// multipart body 送出，沒有這個標註會直接被模型驗證擋下來噴 400（ModelState 顯示
    /// 三個欄位都是 required），連 action 本體都進不去，跟後面的 CheckFiles 等邏輯無關。
    /// </remarks>
    [HttpPost]
    public CustomApiViewModel SaveByFileName(
        List<IFormFile> files, [FromForm] string saveByFileName, [FromForm] string linkFuncNo, [FromForm] string linkNo)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(SaveByFileName), $"saveByFileName:{saveByFileName}, linkFuncNo:{linkFuncNo}, linkNo:{linkNo}");

        var check = CheckFiles(files);
        if (check.Length > 0)
        {
            ca.Message = check;
            return ca;
        }

        var fullPath = ResolveInsideShareRoot(saveByFileName);
        if (fullPath is null)
        {
            ca.Message = $"儲存路徑不合法:{saveByFileName}";
            return ca;
        }

        var dir = Path.GetDirectoryName(fullPath);
        if (string.IsNullOrWhiteSpace(dir))
        {
            ca.Message = $"{saveByFileName} 無法解析出目錄";
            return ca;
        }

        Directory.CreateDirectory(dir);

        using (var source = files[0].OpenReadStream())
        using (var writer = new FileStream(fullPath, FileMode.Create))
        {
            source.CopyTo(writer);
        }

        var logError = AddFileLog(saveByFileName, linkFuncNo, linkNo);
        if (logError.Length > 0)
        {
            ca.Message = $"{files[0].FileName} 上傳成功，但 H_FileLink 記錄失敗-->{logError}";
            return ca;
        }

        ca.IsSuccess = true;
        ca.Message = $"{files[0].FileName}上傳成功!";
        return ca;
    }

    private static string CheckFiles(List<IFormFile>? files)
    {
        if (files is null || files.Count == 0) return "未選擇任何檔案";

        var tooBig = files.Where(f => f.Length > MaxUploadSize).Select(f => f.FileName).ToList();
        if (tooBig.Count > 0) return $"{string.Join(", ", tooBig)} 超過 {MaxMb} Mb";

        var empty = files.Where(f => f.Length <= 0).Select(f => f.FileName).ToList();
        if (empty.Count > 0) return $"{string.Join(", ", empty)} 大小為 0";

        return "";
    }

    /// <summary>
    /// 把相對路徑接到 share root 底下，並確認結果沒有跑出 share root。
    /// 少了這一步，saveByFileName 傳 "../../" 就能寫到伺服器任意位置。
    /// 1.0 沒有做這個檢查。
    /// </summary>
    private string? ResolveInsideShareRoot(string relativePath)
    {
        if (string.IsNullOrWhiteSpace(relativePath)) return null;

        var root = Path.GetFullPath(_paths.ShareRoot);
        var combined = Path.GetFullPath(Path.Combine(root, relativePath.TrimStart('/', '\\')));

        var rootWithSep = root.EndsWith(Path.DirectorySeparatorChar)
            ? root
            : root + Path.DirectorySeparatorChar;

        return combined.StartsWith(rootWithSep, StringComparison.OrdinalIgnoreCase) ? combined : null;
    }

    private string AddFileLog(string destSaveFile, string linkFuncNo, string linkNo)
    {
        try
        {
            var ext = Path.GetExtension(destSaveFile);
            scDb.HFileLinks.Add(new HFileLink
            {
                FilePath = destSaveFile[..^ext.Length],
                FileType = ext,
                LinkFunctionNo = linkFuncNo,
                LinkNo = linkNo,
                UpdateTime = DateTime.Now,
                UpdateUser = GetAccountByToken()
            });
            scDb.SaveChanges();
            return "";
        }
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            return ex.InnerException?.Message ?? ex.Message;
        }
    }
}
