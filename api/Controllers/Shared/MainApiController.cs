using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Proril.SalesIssue.Api.Data;
using Proril.SalesIssue.Api.Helpers;
using Proril.SalesIssue.Api.Models;

namespace Proril.SalesIssue.Api.Controllers.Shared;

/// <summary>
/// 登入與使用者查詢。
///
/// 端點名稱沿用 1.0 的 MainApi，token 也用同一組 JwtSettings 簽，
/// 所以 1.0 與 2.0 的 token 互通，可以漸進切換不必強迫使用者重登。
/// </summary>
[Authorize]
public class MainApiController : BaseApiController
{
    private readonly AesHelper _aes;

    public MainApiController(
        SalesIssueDbContext db,
        JwtHelper jwtHelper,
        AesHelper aes,
        ILogger<MainApiController> logger) : base(db, jwtHelper, logger)
    {
        _aes = aes;
    }

    /// <summary>
    /// 登入。
    ///
    /// 沒有搬 1.0 的 reCAPTCHA：那是給對外官網用的，這支 API 只在內網開放。
    /// 若之後要對外，記得補回來。
    /// 也沒有搬「首登強制改密碼」與登入失敗鎖定的流程 —— 那些屬於帳號管理，
    /// 仍然在 1.0 站台處理。
    /// </summary>
    [AllowAnonymous]
    [HttpPost]
    public LoginModel Login([FromBody] LoginViewModel model)
    {
        var result = new LoginModel { Status = false };
        try
        {
            if (model is null || string.IsNullOrWhiteSpace(model.Account))
            {
                result.Message = "請輸入帳號密碼";
                return result;
            }

            var account = model.Account.Trim();
            var encrypted = _aes.Encrypt(model.Password ?? "");

            var user = db.MUsers.ToList()
                .FirstOrDefault(u => (u.Account ?? "").Trim() == account && u.Password == encrypted);

            if (user is null)
            {
                // 不區分「帳號不存在」與「密碼錯誤」，避免被用來列舉帳號
                result.Message = "帳號或密碼錯誤";
                return result;
            }

            if (!user.IsEnable || user.IsLocked)
            {
                result.Message = "此帳號已停用或已鎖定，請洽系統管理員";
                return result;
            }

            result.Status = true;
            result.Token = jwtHelper.GenerateToken(account);
            result.Username = user.UserName ?? "";
            return result;
        }
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            result.Message = ex.InnerException?.Message ?? ex.Message;
        }
        return result;
    }

    /// <summary>目前登入者。前端可以用它顯示右上角的使用者名稱。</summary>
    [HttpGet]
    public CustomApiViewModel GetCurrentUser()
    {
        var ca = new CustomApiViewModel { IsSuccess = false };
        try
        {
            var account = GetAccountByToken();
            if (string.IsNullOrWhiteSpace(account))
            {
                ca.Message = "token 無效";
                return ca;
            }

            var user = db.MUsers.ToList()
                .FirstOrDefault(u => (u.Account ?? "").Trim() == account && u.IsEnable);
            if (user is null)
            {
                ca.Message = $"查無帳號 {account}";
                return ca;
            }

            ca.IsSuccess = true;
            ca.Body = new { account = user.Account, username = user.UserName, isAdmin = user.IsAdmin };
            return ca;
        }
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            ca.Message = ex.InnerException?.Message ?? ex.Message;
        }
        return ca;
    }

    /// <summary>使用者姓名。舊前端的 APIGetUserInfo 就是打這支。</summary>
    [HttpGet]
    public CustomApiViewModel GetUserInfo(string account)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };
        try
        {
            var trimmed = (account ?? "").Trim();
            var user = db.MUsers.ToList().FirstOrDefault(u => (u.Account ?? "").Trim() == trimmed);
            if (user is null)
            {
                ca.Message = $"查無帳號 {account}";
                return ca;
            }

            ca.IsSuccess = true;
            ca.Body = user.UserName ?? "";
            return ca;
        }
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            ca.Message = ex.InnerException?.Message ?? ex.Message;
        }
        return ca;
    }

    /// <summary>啟用中的使用者清單，指派負責人時用。</summary>
    [HttpGet]
    public CustomApiViewModel GetUserList()
    {
        var ca = new CustomApiViewModel { IsSuccess = false };
        try
        {
            ca.IsSuccess = true;
            ca.Body = db.MUsers
                .Where(u => u.IsEnable)
                .OrderBy(u => u.Account)
                .Select(u => new { u.Account, u.UserName })
                .ToList();
            return ca;
        }
        catch (Exception ex)
        {
            WriteExceptionLog(ex);
            ca.Message = ex.InnerException?.Message ?? ex.Message;
        }
        return ca;
    }
}
