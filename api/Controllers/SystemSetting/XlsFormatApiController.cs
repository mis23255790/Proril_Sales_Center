using ClosedXML.Excel;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Proril.SalesIssue.Api.Controllers.Shared;
using Proril.SalesIssue.Api.Data.SalesCenter;
using Proril.SalesIssue.Api.Filters;
using Proril.SalesIssue.Api.Helpers;
using Proril.SalesIssue.Api.Models;
using Proril.SalesIssue.Api.Services.XlsFormat;

namespace Proril.SalesIssue.Api.Controllers.SystemSetting;

/// <summary>
/// 格式匯入（1.0 系統設定 / 格式匯入，<c>CommonApiController.ImportXlsFormat</c> /
/// <c>ImportCmnXlsFormat</c>）：上傳 Excel 範本，寫進 CMN_XlsFileFormat，
/// 銷貨檢索／未完成訂單／訂單資料檢核的匯出有版型就套版型（見 <see cref="XlsFormatTemplate"/>）。
///
/// **與 1.0 的差異**（都是刻意的，理由見 docs/modules/SystemSetting/logic.md「格式匯入」）：
///   1. 端點不同：1.0 是先走 UploadApi 把檔案存到 ShareRoot，再用 GET 帶路徑呼叫匯入；
///      2.0 直接 multipart POST 檔案，只解析不落地，也不寫 H_FileLink。
///   2. 只寫一張 CMN_XlsFileFormat（1.0 兩個按鈕分別寫 PUR／CMN），解析邏輯用 PUR 版。
///   3. key 是頁面權限 key，不是 FunctionNo；可選的功能只有 <see cref="XlsFormatTargets"/> 列的那幾支。
///   4. 多了版型清單、刪除（退回預設版面）、下載目前版型三支。
///   5. 1.0 畫面上的「Y起始值／Y結束值」從來沒送到後端，2.0 拿掉。
///   6. 後端補功能權限檢查（1.0 這幾支沒有任何權限檢查，連 [Authorize] 都沒掛）。
/// </summary>
[Authorize]
[RequirePermission(PermissionKeys.SystemSetting.ImportXlsFormat)]
public class XlsFormatApiController : BaseApiController
{
    private const int MaxMb = 5;
    private const long MaxUploadSize = MaxMb * 1024L * 1024L;

    private readonly StoragePaths _paths;

    public XlsFormatApiController(
        SalesCenterDbContext scDb,
        JwtHelper jwtHelper,
        StoragePaths paths,
        ILogger<XlsFormatApiController> logger) : base(scDb, jwtHelper, logger)
    {
        _paths = paths;
    }

    /// <summary>可以設定版型的匯出功能（Body）與版型別（Body2：0 = 有金額權限、1 = 無金額權限）。</summary>
    [HttpGet]
    public CustomApiViewModel GetXlsFormatTargets()
    {
        return new CustomApiViewModel
        {
            IsSuccess = true,
            Body = XlsFormatTargets.All.Select(t => new
            {
                t.PermissionKey,
                t.Label,
                t.SheetNames,
                t.Note
            }).ToList(),
            Body2 = XlsFormatTargets.SubNos.Select(s => new { s.Value, s.Label }).ToList()
        };
    }

    /// <summary>
    /// 目前有哪些版型：一列 = 一個功能 + 版型別，附各分頁的格數與最後匯入的人／時間。
    /// 沒有任何版型時回 isSuccess = true + 空清單（不是查無資料的 false，畫面要能正常顯示空表）。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel GetXlsFormatList()
    {
        var rows = scDb.CmnXlsFileFormats
            .AsNoTracking()
            .GroupBy(f => new { f.PermissionKey, f.FunctionSubNo, f.Wsname })
            .Select(g => new
            {
                g.Key.PermissionKey,
                g.Key.FunctionSubNo,
                g.Key.Wsname,
                Count = g.Count(),
                CreateTime = g.Max(f => f.CreateTime),
                MinId = g.Min(f => f.Id)
            })
            .ToList();

        // 同一次匯入的 Creator 都一樣，取每組最早那列的就好（不用在 GroupBy 裡做子查詢）
        var creatorIds = rows.Select(r => r.MinId).ToList();
        var creators = scDb.CmnXlsFileFormats
            .AsNoTracking()
            .Where(f => creatorIds.Contains(f.Id))
            .ToDictionary(f => f.Id, f => f.Creator);

        var list = rows
            .GroupBy(r => new { r.PermissionKey, r.FunctionSubNo })
            .Select(g =>
            {
                var target = XlsFormatTargets.Find(g.Key.PermissionKey);
                var latest = g.OrderByDescending(r => r.CreateTime).First();
                return new
                {
                    g.Key.PermissionKey,
                    Label = target?.Label ?? g.Key.PermissionKey,
                    g.Key.FunctionSubNo,
                    SubNoLabel = XlsFormatTargets.SubNos.FirstOrDefault(s => s.Value == g.Key.FunctionSubNo).Label
                                 ?? g.Key.FunctionSubNo,
                    // 清單外的 key（功能拿掉版型支援、或手動改 DB）還是列出來，讓人刪得掉
                    IsKnownTarget = target is not null,
                    Sheets = g
                        .OrderBy(r => target is null ? int.MaxValue : IndexOf(target.SheetNames, r.Wsname))
                        .ThenBy(r => r.Wsname)
                        .Select(r => new { WsName = r.Wsname, r.Count })
                        .ToList(),
                    latest.CreateTime,
                    Creator = creators.GetValueOrDefault(latest.MinId)
                };
            })
            .OrderBy(r => IndexOf(XlsFormatTargets.All.Select(t => t.PermissionKey).ToList(), r.PermissionKey))
            .ThenBy(r => r.FunctionSubNo)
            .ToList();

        return new CustomApiViewModel { IsSuccess = true, Body = list };
    }

    /// <summary>
    /// 匯入範本：同一個功能 + 版型別的舊版型整份刪掉，換成這份（1.0 也是先刪後寫）。
    /// 刪除與寫入在同一個交易，解析失敗或寫入失敗都不會把舊版型弄丟。
    ///
    /// <c>permissionKey</c>/<c>functionSubNo</c> 一定要 <c>[FromForm]</c>，理由同
    /// <see cref="UploadApiController.SaveByFileName"/>。
    /// </summary>
    [HttpPost]
    public CustomApiViewModel ImportXlsFormat(IFormFile? file, [FromForm] string? permissionKey, [FromForm] string? functionSubNo)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(ImportXlsFormat), $"permissionKey:{permissionKey}, functionSubNo:{functionSubNo}, file:{file?.FileName}");

        var target = XlsFormatTargets.Find(permissionKey);
        if (target is null)
        {
            ca.Message = $"「{permissionKey}」不是可以設定版型的功能";
            return ca;
        }

        var subNo = functionSubNo?.Trim() ?? "";
        if (!XlsFormatTargets.IsValidSubNo(subNo))
        {
            ca.Message = $"版型別「{functionSubNo}」不正確";
            return ca;
        }

        if (file is null || file.Length <= 0)
        {
            ca.Message = "未選擇檔案";
            return ca;
        }
        if (file.Length > MaxUploadSize)
        {
            ca.Message = $"{file.FileName} 超過 {MaxMb} MB";
            return ca;
        }
        if (!string.Equals(Path.GetExtension(file.FileName), ".xlsx", StringComparison.OrdinalIgnoreCase))
        {
            ca.Message = "只接受 .xlsx 檔（舊版 .xls 請先用 Excel 另存新檔）";
            return ca;
        }

        using var buffer = new MemoryStream();
        file.CopyTo(buffer);
        buffer.Position = 0;

        XLWorkbook workbook;
        try
        {
            workbook = new XLWorkbook(buffer);
        }
        catch (Exception ex)
        {
            // 檔案壞掉／不是 Excel 是使用者操作錯誤，要回可讀的訊息，不是交給全域 filter 回 500 訊息
            WriteExceptionLog(ex);
            ca.Message = $"{file.FileName} 無法讀取，請確認是有效的 .xlsx 檔";
            return ca;
        }

        using (workbook)
        {
            var result = XlsFormatImporter.Parse(workbook, target, subNo, GetAccountByToken());
            if (result.Error is not null)
            {
                ca.Message = result.Error;
                return ca;
            }

            using var tx = scDb.Database.BeginTransaction();
            scDb.CmnXlsFileFormats
                .Where(f => f.PermissionKey == target.PermissionKey && f.FunctionSubNo == subNo)
                .ExecuteDelete();
            scDb.CmnXlsFileFormats.AddRange(result.Formats);
            scDb.SaveChanges();
            tx.Commit();

            var skipped = result.Sheets.Where(s => !s.Recognized).Select(s => s.WsName).ToList();
            var missing = target.SheetNames.Where(n => result.Sheets.All(s => s.WsName != n || s.Rows == 0)).ToList();

            ca.IsSuccess = true;
            ca.Body = result.Sheets;
            ca.Message = string.Join(" ", new[]
            {
                skipped.Count > 0 ? $"已略過名稱對不上的分頁：{string.Join("、", skipped)}。" : null,
                missing.Count > 0 ? $"以下分頁沒有版型，匯出時沿用預設版面：{string.Join("、", missing)}。" : null
            }.Where(s => s is not null));
            return ca;
        }
    }

    /// <summary>刪除某個功能 + 版型別的版型，之後匯出退回預設版面。</summary>
    [HttpPost]
    public CustomApiViewModel DeleteXlsFormat(string? permissionKey, string? functionSubNo)
    {
        WriteStepLog(nameof(DeleteXlsFormat), $"permissionKey:{permissionKey}, functionSubNo:{functionSubNo}");

        var key = permissionKey?.Trim() ?? "";
        var subNo = functionSubNo?.Trim() ?? "";
        var deleted = scDb.CmnXlsFileFormats
            .Where(f => f.PermissionKey == key && f.FunctionSubNo == subNo)
            .ExecuteDelete();

        return deleted > 0
            ? new CustomApiViewModel { IsSuccess = true, Message = $"已刪除 {deleted} 筆版型設定" }
            : new CustomApiViewModel { IsSuccess = false, Message = "查無這個版型" };
    }

    /// <summary>
    /// 下載目前版型：把 DB 裡的版型套到空白活頁簿上存成 .xlsx，可以拿來改完再匯入。
    /// 回傳 <c>Body</c> 與各匯出相同，是相對於 ShareRoot 的路徑。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel ExportXlsFormat(string? permissionKey, string? functionSubNo)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        var key = permissionKey?.Trim() ?? "";
        var subNo = functionSubNo?.Trim() ?? "";
        var template = XlsFormatTemplate.Load(scDb, key, subNo);
        if (template.SheetNames.Count == 0)
        {
            ca.Message = "查無這個版型";
            return ca;
        }

        var target = XlsFormatTargets.Find(key);
        var sheetNames = template.SheetNames
            .OrderBy(n => target is null ? int.MaxValue : IndexOf(target.SheetNames, n))
            .ThenBy(n => n)
            .ToList();

        using var workbook = new XLWorkbook();
        foreach (var name in sheetNames)
        {
            template.Apply(workbook.AddWorksheet(name), name);
        }

        var account = GetAccountByToken();
        var dir = _paths.ExportDir(account);
        Directory.CreateDirectory(dir);
        var fileName = $"XlsFormat_{(target?.Label ?? "unknown")}_{subNo}_{DateTime.Now:yyyyMMdd_HHmm}.xlsx";
        workbook.SaveAs(Path.Combine(dir, fileName));

        ca.IsSuccess = true;
        ca.Body = $"Temp/{account}/Export/{fileName}";
        return ca;
    }

    private static int IndexOf(IReadOnlyList<string> list, string value)
    {
        for (var i = 0; i < list.Count; i++)
        {
            if (list[i] == value) return i;
        }
        return int.MaxValue;
    }
}
