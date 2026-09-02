using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.IdentityModel.Tokens;

namespace Proril.SalesIssue.Api.Helpers;

/// <summary>
/// JWT 產生與驗證。
///
/// **必須跟 1.0 用同一組 JwtSettings（Issuer + SignKey）**，
/// 這樣使用者在 1.0 站台登入拿到的 token 才能直接打這支 API，反之亦然。
/// 兩邊不一致的話所有請求都會 401，而且訊息不會告訴你是金鑰不同。
/// 設定在 appsettings.json 的 JwtSettings 區塊。
/// </summary>
public class JwtHelper
{
    private readonly string _issuer;
    private readonly string _signKey;

    public JwtHelper(IConfiguration configuration)
    {
        _issuer = configuration.GetValue<string>("JwtSettings:Issuer") ?? "";
        _signKey = configuration.GetValue<string>("JwtSettings:SignKey") ?? "";

        if (string.IsNullOrWhiteSpace(_signKey))
        {
            throw new InvalidOperationException(
                "JwtSettings:SignKey 未設定。必須與 1.0 PRORIL 的 appsettings 相同，否則 token 不互通。");
        }
    }

    /// <summary>產生 token。帳號放在 sub claim，預設 24 小時，與 1.0 一致。</summary>
    public string GenerateToken(string account, int expireMinutes = 1440)
    {
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, account),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };

        var securityKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_signKey));
        var signingCredentials = new SigningCredentials(securityKey, SecurityAlgorithms.HmacSha256Signature);

        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Issuer = _issuer,
            Subject = new ClaimsIdentity(claims),
            Expires = DateTime.Now.AddMinutes(expireMinutes),
            SigningCredentials = signingCredentials
        };

        var handler = new JwtSecurityTokenHandler();
        return handler.WriteToken(handler.CreateToken(tokenDescriptor));
    }

    public bool TryValidateToken(string token, out ClaimsPrincipal? principal)
    {
        principal = null;
        if (string.IsNullOrWhiteSpace(token)) return false;

        try
        {
            var handler = new JwtSecurityTokenHandler();

            // 預設會把 sub 映射成 ClaimTypes.NameIdentifier（一長串 schemas.xmlsoap.org 的 URI），
            // 之後就找不到名為 "sub" 的 claim，GetAccountByToken 會一路回空字串 ——
            // 症狀是 API 都通、但 Creator/Modifier 全部存成空的。
            // 1.0 是在 Program.cs 清全域的 DefaultInboundClaimTypeMap；
            // 這裡改成只清這個 handler 的，不動全域狀態。
            handler.InboundClaimTypeMap.Clear();

            var validationParameters = new TokenValidationParameters
            {
                RequireExpirationTime = true,
                ValidateIssuer = true,
                ValidIssuer = _issuer,
                ValidateAudience = false,
                ValidateLifetime = true,
                IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_signKey)),
                // 與 1.0 一致：只驗簽章與有效期，不驗 key id
                ValidateIssuerSigningKey = false
            };

            principal = handler.ValidateToken(token, validationParameters, out _);
            return true;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[JwtHelper.TryValidateToken] {ex.Message}");
            return false;
        }
    }

    /// <summary>從 token 取帳號（sub claim）。驗不過回空字串。</summary>
    public string GetAccountByToken(string token)
    {
        try
        {
            if (!TryValidateToken(token, out var principal) || principal is null) return "";

            // 保險：即使哪天 claim map 又被打開，也還找得到帳號
            return principal.Claims.FirstOrDefault(p => p.Type == "sub")?.Value
                ?? principal.Claims.FirstOrDefault(p => p.Type == ClaimTypes.NameIdentifier)?.Value
                ?? "";
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[JwtHelper.GetAccountByToken] {ex.Message}");
            return "";
        }
    }
}
