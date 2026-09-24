using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Proril.SalesIssue.Api.Data;
using Proril.SalesIssue.Api.Data.SalesCenter;
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
public partial class MainApiController : BaseApiController
{
    // M_Department 仍唯讀打 PRORIL_WEB（1.0 OrgApiController 還在寫，見 CLAUDE.md），
    // BaseApiController 不再帶 ProrilWebDbContext，這支自己單獨注入一份，只給這個用途。
    private readonly ProrilWebDbContext db;
    private readonly AesHelper _aes;
    private readonly string _ssoInternalSecret;

    public MainApiController(
        ProrilWebDbContext db,
        SalesCenterDbContext scDb,
        JwtHelper jwtHelper,
        AesHelper aes,
        IConfiguration configuration,
        ILogger<MainApiController> logger) : base(db, scDb, jwtHelper, logger)
    {
        this.db = db;
        _aes = aes;
        _ssoInternalSecret = configuration.GetValue<string>("Sso:InternalSecret") ?? "";
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

        if (model is null || string.IsNullOrWhiteSpace(model.Account))
        {
            result.Message = "請輸入帳號密碼";
            return result;
        }

        var account = model.Account.Trim();
        var encrypted = _aes.Encrypt(model.Password ?? "");

        var user = scDb.MUsers.ToList()
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

    /// <summary>
    /// SSO 登入。
    ///
    /// 呼叫端是 Nuxt 的 server/api/auth/sso.post.ts —— 它已經拿授權碼跟
    /// PRORIL 通行證換過 token，這支只負責「帳號存在且啟用」的檢查後直接發內部 JWT，
    /// 不再驗一次密碼（通行證已經驗過身分）。
    ///
    /// 因為不驗密碼，一定要用 X-Internal-Secret 擋，否則等於公開的免密碼登入後門。
    /// 密鑰放 Sso:InternalSecret，只有 Nuxt server 端知道，瀏覽器拿不到。
    /// </summary>
    [AllowAnonymous]
    [HttpPost]
    public LoginModel LoginSso([FromBody] SsoLoginViewModel model)
    {
        var result = new LoginModel { Status = false };

        var providedSecret = Request?.Headers["X-Internal-Secret"].ToString() ?? "";
        if (string.IsNullOrWhiteSpace(_ssoInternalSecret) || providedSecret != _ssoInternalSecret)
        {
            result.Message = "未授權的呼叫來源";
            return result;
        }

        var account = (model?.Account ?? "").Trim();
        if (string.IsNullOrWhiteSpace(account))
        {
            result.Message = "SSO 回傳的帳號為空";
            return result;
        }

        var user = scDb.MUsers.ToList().FirstOrDefault(u => (u.Account ?? "").Trim() == account);
        if (user is null)
        {
            result.Message = $"查無帳號 {account}，請洽系統管理員確認 PRORIL 通行證帳號是否已建立對應資料";
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

    /// <summary>目前登入者。前端可以用它顯示右上角的使用者名稱。</summary>
    [HttpGet]
    public CustomApiViewModel GetCurrentUser()
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        var account = GetAccountByToken();
        if (string.IsNullOrWhiteSpace(account))
        {
            ca.Message = "token 無效";
            return ca;
        }

        var user = scDb.MUsers.ToList()
            .FirstOrDefault(u => (u.Account ?? "").Trim() == account && u.IsEnable);
        if (user is null)
        {
            ca.Message = $"查無帳號 {account}";
            return ca;
        }

        ca.IsSuccess = true;
        ca.Body = new { account = user.Account, username = user.UserName, isAdmin = IsAdmin(account) };
        return ca;
    }

    /// <summary>使用者姓名。舊前端的 APIGetUserInfo 就是打這支。</summary>
    [HttpGet]
    public CustomApiViewModel GetUserInfo(string account)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        var trimmed = (account ?? "").Trim();
        var user = scDb.MUsers.ToList().FirstOrDefault(u => (u.Account ?? "").Trim() == trimmed);
        if (user is null)
        {
            ca.Message = $"查無帳號 {account}";
            return ca;
        }

        ca.IsSuccess = true;
        ca.Body = user.UserName ?? "";
        return ca;
    }

    /// <summary>
    /// 字串權限檢查（<see cref="PermissionKeys"/>），金額欄位這類需要逐帳號授權的畫面元素在用。
    ///
    /// 回傳裸 <c>bool</c>，不是 <see cref="CustomApiViewModel"/> 信封——這支是刻意跟其他
    /// API 不同形狀，前端 usePermission.ts 也是照這個預期寫的。
    ///
    /// 取代 1.0 的 <c>CheckUserPermissionLinkType(functionNo, linkType)</c>（已移除）。
    /// 跟舊端點的差異：舊的只看本人的列，這支同 <see cref="BaseApiController.HasPermission(string)"/>
    /// 看所屬角色 ∪ everyone。前端一般改用 <c>GetMyPermissions</c> 一次載入，這支保留給單點查詢。
    /// </summary>
    [HttpGet]
    public bool CheckPermission(string permissionKey)
        => !string.IsNullOrWhiteSpace(permissionKey) && HasPermission(permissionKey.Trim());

    /// <summary>
    /// 系統別資料（含 topbar 用來顯示正式區/測試區環境圖示的 ImagePath）。
    ///
    /// 沿用 1.0 MainApiController_SystemSetting.GetMSystemWNo：ImagePath 在正式區/測試區
    /// 各自的 DB 存了不同圖檔路徑，靠資料本身區分環境，這支不判斷任何環境變數。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel GetMSystemWNo(int systemNo)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        var msystemList = scDb.MSystems.Where(o => o.SystemNo == systemNo).ToList();
        ca.Body = msystemList;
        ca.IsSuccess = true;
        return ca;
    }

    /// <summary>啟用中的使用者清單，指派負責人時用。</summary>
    [HttpGet]
    public CustomApiViewModel GetUserList()
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        ca.IsSuccess = true;
        ca.Body = scDb.MUsers
            .Where(u => u.IsEnable)
            .OrderBy(u => u.Account)
            .Select(u => new { u.Account, u.UserName })
            .ToList();
        return ca;
    }
}
