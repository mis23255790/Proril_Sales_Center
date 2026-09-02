using System.IO.Compression;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json;
using Proril.SalesIssue.Api.Data;
using Proril.SalesIssue.Api.Helpers;
using Proril.SalesIssue.Api.Models;

namespace Proril.SalesIssue.Api.Controllers.SalesIssue;

/*
 * 附件。
 *
 * 一則進度的所有附件壓成一個 zip 存在 share root，要改就得先解出來。固定流程：
 *
 *   1. ClearSOPTempPath     清掉自己的 temp 目錄
 *   2. UnzipAttachFileList  zip 解到 temp（檔名還原成原始檔名）
 *   3. UploadApi/SaveByFileName  新選的檔案上傳到同一個 temp 目錄
 *   4. UpdateDBAttachFile   最終檔名清單寫回 D_WorkProcessDetail
 *   5. ZipAttachFileList    temp 目錄重新壓成 zip
 *
 * 4 與 5 的順序看這則進度存不存在（見前端 useIssueAttachments.commit）。
 * 兩條路都必須用同一份、同順序的檔名清單 —— RenameFile 是依序重編的（1.pdf、2.docx…），
 * 順序一亂就對不回原始檔名。
 *
 * 所有目錄的中間層一律用 wpNo 算（見 StoragePaths 的說明）。
 */
public partial class WorkProcessApiController
{
    /// <summary>步驟 1：清掉自己這次要用的 temp 目錄。</summary>
    [HttpGet]
    [Authorize]
    public CustomApiViewModel ClearSOPTempPath(string wpNo, string? edit_path)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };
        try
        {
            WriteStepLog(nameof(ClearSOPTempPath), $"wpNo:{wpNo}, edit_path:{edit_path}");

            var padded = StoragePaths.PadWpno(wpNo);
            if (padded.Length == 0)
            {
                ca.Message = $"wpNo:{wpNo} 有誤!!!";
                return ca;
            }

            var account = GetAccountByToken();

            var orgDir = _paths.UserOrgDir(account, padded, edit_path ?? "");
            if (Directory.Exists(orgDir)) Directory.Delete(orgDir, true);

            var zipRoot = _paths.UserZipRoot(account);
            if (Directory.Exists(zipRoot)) Directory.Delete(zipRoot, true);

            ca.IsSuccess = true;
            return ca;
        }
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            ca.Message = ex.InnerException?.Message ?? ex.Message;
        }
        return ca;
    }

    /// <summary>
    /// 步驟 2：把 zip 解到 temp，並把檔名從 RenameFile 還原成 UploadFile。
    /// extSubPath 慣例上要傳 sNo，這樣解出來的位置才跟 EnumTempUploadAttach /
    /// ZipAttachFileList 找的位置一致。
    /// </summary>
    [HttpGet]
    [Authorize]
    public CustomApiViewModel UnzipAttachFileList(string wpNo, string sNo, string verNo, string? extSubPath)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };
        try
        {
            WriteStepLog(nameof(UnzipAttachFileList), $"wpNo:{wpNo}, sNo:{sNo}, verNo:{verNo}, extSubPath:{extSubPath}");

            var padded = StoragePaths.PadWpno(wpNo);
            if (padded.Length == 0)
            {
                ca.Message = $"wpNo:{wpNo} 有誤!!!";
                return ca;
            }

            var paddedSno = StoragePaths.PadSno(sNo);
            var detail = db.DWorkProcessDetails.FirstOrDefault(d => d.Wpno == padded && d.Sno == paddedSno);
            if (detail is null)
            {
                // 新建的進度還沒有 zip，這不是錯誤
                ca.IsSuccess = true;
                ca.Message = $"{padded}: {paddedSno} 不存在!!!";
                return ca;
            }

            var zipFile = Path.Combine(_paths.DocSopDir(padded),
                StoragePaths.ZipFileName(StoragePaths.ZipNameWithoutVer(padded, detail.Id), verNo));
            if (!System.IO.File.Exists(zipFile))
            {
                ca.IsSuccess = true;
                ca.Message = $"{zipFile} 檔案不存在!";
                return ca;
            }

            var account = GetAccountByToken();
            var unzipPath = Path.Combine(_paths.UserZipDir(account, padded), paddedSno);
            if (Directory.Exists(unzipPath)) Directory.Delete(unzipPath, true);
            Directory.CreateDirectory(unzipPath);

            ZipFile.ExtractToDirectory(zipFile, unzipPath, false);

            var extracted = Directory.GetFiles(unzipPath);
            if (extracted.Length == 0)
            {
                ca.Message = $"{zipFile} 不含任何檔案!";
                return ca;
            }

            var copyBackDir = _paths.UserOrgDir(account, padded, extSubPath ?? "");
            Directory.CreateDirectory(copyBackDir);

            var lostFiles = new List<string>();
            var renameFiles = (detail.RenameFile ?? "").Split(';', StringSplitOptions.RemoveEmptyEntries);
            var uploadFiles = (detail.UploadFile ?? "").Split(';', StringSplitOptions.RemoveEmptyEntries);

            if (renameFiles.Length != uploadFiles.Length)
            {
                ca.Message = $"UploadFile 與 RenameFile 個數不一致（{uploadFiles.Length} vs {renameFiles.Length}），無法還原原始檔名!";
                return ca;
            }

            for (var i = 0; i < renameFiles.Length; i++)
            {
                var source = Path.Combine(unzipPath, renameFiles[i].Trim());
                var dest = Path.Combine(copyBackDir, uploadFiles[i].Trim());

                if (!System.IO.File.Exists(source))
                {
                    lostFiles.Add(uploadFiles[i].Trim());
                    continue;
                }

                if (System.IO.File.Exists(dest)) continue;
                System.IO.File.Copy(source, dest, false);
            }

            Directory.Delete(unzipPath, true);

            if (lostFiles.Count > 0)
            {
                ca.Message = $"{string.Join(";", lostFiles)} 不存在!";
                return ca;
            }

            ca.IsSuccess = true;
            return ca;
        }
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            ca.Message = ex.InnerException?.Message ?? ex.Message;
        }
        return ca;
    }

    /// <summary>列出 temp 目錄裡目前有哪些檔案。</summary>
    [HttpGet]
    [Authorize]
    public CustomApiViewModel EnumTempUploadAttach(string wpNo, string? sNo, string? edit_path)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };
        try
        {
            WriteStepLog(nameof(EnumTempUploadAttach), $"wpNo:{wpNo}, sNo:{sNo}, edit_path:{edit_path}");

            var padded = StoragePaths.PadWpno(wpNo);
            if (padded.Length == 0)
            {
                ca.Message = $"wpNo:{wpNo} 有誤!!!";
                return ca;
            }

            var dir = _paths.UserOrgDir(GetAccountByToken(), padded, edit_path ?? "");
            if (!Directory.Exists(dir))
            {
                ca.Message = $"{dir} 為空!!!";
                return ca;
            }

            ca.Body = Directory.EnumerateFiles(dir).Select(f => new FileInfo(f).Name).ToList();
            ca.IsSuccess = true;
            return ca;
        }
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            ca.Message = ex.InnerException?.Message ?? ex.Message;
        }
        return ca;
    }

    /// <summary>從 temp 目錄刪掉一個檔案（尚未重壓前）。</summary>
    [HttpGet]
    [Authorize]
    public CustomApiViewModel DelDetailAttach(string wpNo, string? sNo, string? edit_path, string uploadFile)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };
        try
        {
            WriteStepLog(nameof(DelDetailAttach), $"wpNo:{wpNo}, sNo:{sNo}, edit_path:{edit_path}, uploadFile:{uploadFile}");

            var padded = StoragePaths.PadWpno(wpNo);
            if (padded.Length == 0)
            {
                ca.Message = $"wpNo:{wpNo} 有誤!!!";
                return ca;
            }

            if (string.IsNullOrWhiteSpace(uploadFile))
            {
                ca.Message = "uploadFile 為空!!!";
                return ca;
            }

            var file = Path.Combine(_paths.UserOrgDir(GetAccountByToken(), padded, edit_path ?? ""), SafeFileName(uploadFile));
            if (!System.IO.File.Exists(file))
            {
                ca.Message = $"{file} 不存在!!!";
                return ca;
            }

            System.IO.File.Delete(file);
            ca.IsSuccess = true;
            return ca;
        }
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            ca.Message = ex.InnerException?.Message ?? ex.Message;
        }
        return ca;
    }

    /// <summary>
    /// 步驟 4：把最終檔名清單寫回 D_WorkProcessDetail。
    /// RenameFile 在這裡依序重編成 1.ext、2.ext…，順序必須與 ZipAttachFileList 一致。
    /// </summary>
    [HttpGet]
    [Authorize]
    public CustomApiViewModel UpdateDBAttachFile(string wpNo, string sNo, string verNo, string? edit_path, string strUploadFiles)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };
        try
        {
            WriteStepLog(nameof(UpdateDBAttachFile), $"wpNo:{wpNo}, sNo:{sNo}, strUploadFiles:{strUploadFiles}");

            var uploadFiles = JsonConvert.DeserializeObject<List<string>>(strUploadFiles ?? "");
            if (uploadFiles is null)
            {
                ca.Message = "strUploadFiles 解析失敗（需為 JSON 陣列字串）!!!";
                return ca;
            }

            var padded = StoragePaths.PadWpno(wpNo);
            if (padded.Length == 0)
            {
                ca.Message = $"wpNo:{wpNo} 有誤!!!";
                return ca;
            }

            var paddedSno = StoragePaths.PadSno(sNo);
            var account = GetAccountByToken();

            var detail = db.DWorkProcessDetails.FirstOrDefault(d => d.Wpno == padded && d.Sno == paddedSno);
            var isNew = detail is null;
            detail ??= new DWorkProcessDetail
            {
                Wpno = padded,
                Sno = paddedSno,
                AStatus = ActiveStatus.Active,
                Creator = account,
                CreateTime = DateTime.Now
            };

            var orgDir = _paths.UserOrgDir(account, padded, edit_path ?? "");
            var uploadNames = new List<string>();
            var renameNames = new List<string>();
            var lostFiles = new List<string>();
            var renameId = 1;

            foreach (var uploadFile in uploadFiles)
            {
                var name = SafeFileName(uploadFile);
                var orgFile = Path.Combine(orgDir, name);
                if (name.Length == 0 || !System.IO.File.Exists(orgFile))
                {
                    lostFiles.Add(uploadFile);
                    continue;
                }

                uploadNames.Add(name);
                renameNames.Add($"{renameId}{new FileInfo(orgFile).Extension}");
                renameId++;
            }

            detail.UploadFile = string.Join(";", uploadNames);
            detail.RenameFile = string.Join(";", renameNames);
            detail.Modifier = account;
            detail.ModiTime = DateTime.Now;

            if (isNew) db.DWorkProcessDetails.Add(detail);
            else db.DWorkProcessDetails.Update(detail);

            db.SaveChanges();

            ca.IsSuccess = true;
            ca.Body = detail;
            if (lostFiles.Count > 0) ca.Message = $"下列檔案在暫存目錄找不到，已略過:{string.Join(";", lostFiles)}";
            return ca;
        }
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            ca.Message = ex.InnerException?.Message ?? ex.Message;
        }
        return ca;
    }

    /// <summary>
    /// 步驟 5：把 temp 目錄的檔案改名後重新壓成 zip。
    /// zip_file_name_woV 是 {wpNo}.{detailId}，呼叫端要先確定 detailId 已存在。
    /// </summary>
    [HttpGet]
    [Authorize]
    public CustomApiViewModel ZipAttachFileList(string wpNo, string sNo, string verNo, string? edit_path, string strUploadFiles, string zip_file_name_woV)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };
        try
        {
            WriteStepLog(nameof(ZipAttachFileList), $"wpNo:{wpNo}, sNo:{sNo}, verNo:{verNo}, zipName:{zip_file_name_woV}");

            var uploadFiles = JsonConvert.DeserializeObject<List<string>>(strUploadFiles ?? "");
            if (uploadFiles is null)
            {
                ca.Message = "strUploadFiles 解析失敗（需為 JSON 陣列字串）!!!";
                return ca;
            }

            var padded = StoragePaths.PadWpno(wpNo);
            if (padded.Length == 0)
            {
                ca.Message = $"wpNo:{wpNo} 有誤!!!";
                return ca;
            }

            var account = GetAccountByToken();
            var orgDir = _paths.UserOrgDir(account, padded, edit_path ?? "");
            if (!Directory.Exists(orgDir))
            {
                ca.Message = $"暫存目錄:{orgDir} 不存在!!!";
                return ca;
            }

            var docSopDir = _paths.DocSopDir(padded);
            Directory.CreateDirectory(docSopDir);
            var zipFullName = Path.Combine(docSopDir, StoragePaths.ZipFileName(zip_file_name_woV, verNo));

            // 改名暫存區：整個重建，避免混到上一次的殘留
            var stageDir = _paths.UserZipDir(account, padded);
            if (Directory.Exists(stageDir)) Directory.Delete(stageDir, true);
            Directory.CreateDirectory(stageDir);

            var lostFiles = new List<string>();
            var renameId = 1;
            foreach (var uploadFile in uploadFiles)
            {
                var name = SafeFileName(uploadFile);
                var orgFile = Path.Combine(orgDir, name);
                if (name.Length == 0 || !System.IO.File.Exists(orgFile))
                {
                    lostFiles.Add(uploadFile);
                    continue;
                }

                var ext = new FileInfo(orgFile).Extension;
                System.IO.File.Copy(orgFile, Path.Combine(stageDir, $"{renameId}{ext}"), true);
                renameId++;
            }

            if (lostFiles.Count > 0)
            {
                ca.Message = $"原始檔案:{string.Join(";", lostFiles)} 不存在!!!";
                return ca;
            }

            // 先把舊 zip 備份成 .bak，壓成功才刪掉，壓失敗至少還救得回來
            var backup = zipFullName + ".bak";
            if (System.IO.File.Exists(zipFullName))
            {
                if (System.IO.File.Exists(backup)) System.IO.File.Delete(backup);
                System.IO.File.Move(zipFullName, backup);
            }

            if (Directory.GetFiles(stageDir).Length > 0)
            {
                ZipFile.CreateFromDirectory(stageDir, zipFullName);
                if (System.IO.File.Exists(zipFullName) && System.IO.File.Exists(backup))
                {
                    System.IO.File.Delete(backup);
                }
            }

            Directory.Delete(stageDir, true);

            ca.IsSuccess = true;
            return ca;
        }
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            ca.Message = ex.InnerException?.Message ?? ex.Message;
        }
        return ca;
    }

    /// <summary>
    /// 取得單一附件的下載網址。
    /// 會先把 zip 解到使用者的 temp 目錄，再回傳 /ShareRoot/... 的相對路徑
    /// （對應 Program.cs 掛在 /ShareRoot 的靜態檔目錄）。
    /// </summary>
    [HttpGet]
    [Authorize]
    public CustomApiViewModel GetDownloadUrl(string wpNo, string sNo, string uploadFile)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };
        try
        {
            WriteStepLog(nameof(GetDownloadUrl), $"wpNo:{wpNo}, sNo:{sNo}, uploadFile:{uploadFile}");

            var padded = StoragePaths.PadWpno(wpNo);
            if (padded.Length == 0)
            {
                ca.Message = $"wpNo:{wpNo} 有誤!!!";
                return ca;
            }

            var paddedSno = StoragePaths.PadSno(sNo);
            var detail = db.DWorkProcessDetails.FirstOrDefault(d => d.Wpno == padded && d.Sno == paddedSno);
            if (detail is null)
            {
                ca.Message = $"查無工作流程單:{padded} / {paddedSno} !!!";
                return ca;
            }

            var wp = db.DWorkProcesses.FirstOrDefault(o => o.Wpno == padded);
            var verNo = wp?.VerNo ?? "1.0";

            // 解到 temp/{dcu}/{sNo}，與編輯流程同一個位置
            var unzip = UnzipAttachFileList(padded, paddedSno, verNo, paddedSno);
            if (!unzip.IsSuccess)
            {
                ca.Message = unzip.Message;
                return ca;
            }

            var name = SafeFileName(uploadFile);
            var localFile = Path.Combine(_paths.UserOrgDir(GetAccountByToken(), padded, paddedSno), name);
            if (!System.IO.File.Exists(localFile))
            {
                ca.Message = $"{uploadFile} 解壓後仍不存在，可能 zip 內容與 DB 記錄不一致!";
                return ca;
            }

            ca.IsSuccess = true;
            ca.Body = StoragePaths.DownloadUrl(GetAccountByToken(), padded, paddedSno, name);
            return ca;
        }
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            ca.Message = ex.InnerException?.Message ?? ex.Message;
        }
        return ca;
    }

    /// <summary>
    /// 只取檔名，擋掉路徑穿越。
    /// 這些參數來自前端，直接串進路徑會讓 "../../" 之類的值跑出 share root。
    /// </summary>
    private static string SafeFileName(string? value)
    {
        var name = Path.GetFileName((value ?? "").Trim());
        if (name is "." or "..") return "";
        return name;
    }
}
