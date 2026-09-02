using System.Security.Cryptography;
using System.Text;

namespace Proril.SalesIssue.Api.Helpers;

/// <summary>
/// M_User.Password 的加解密。
///
/// **金鑰必須與 1.0 相同**，否則登入永遠比對不過（DB 裡的密碼是用 1.0 的金鑰加密的）。
/// 1.0 是把金鑰硬編在程式裡，這裡改成從設定讀（Security:AesKey），
/// 預設值就是 1.0 的那一組，維持相容。
/// </summary>
public class AesHelper
{
    private readonly byte[] _key = new byte[16];
    private readonly byte[] _iv = new byte[16];

    public AesHelper(IConfiguration configuration)
    {
        var privateKey = configuration.GetValue<string>("Security:AesKey") ?? "";
        if (string.IsNullOrWhiteSpace(privateKey))
        {
            throw new InvalidOperationException(
                "Security:AesKey 未設定。必須與 1.0 PRORIL 的 AesHelper 相同，否則登入無法驗證密碼。");
        }

        // 與 1.0 相同：SHA256(key) 的前 16 bytes 當 Key，後 16 bytes 當 IV
        var hash = SHA256.HashData(Encoding.ASCII.GetBytes(privateKey));
        Array.Copy(hash, 0, _key, 0, 16);
        Array.Copy(hash, 16, _iv, 0, 16);
    }

    public string Encrypt(string input)
    {
        using var aes = Aes.Create();
        aes.Key = _key;
        aes.IV = _iv;

        var rawData = Encoding.UTF8.GetBytes(input);
        using var ms = new MemoryStream();
        using (var cs = new CryptoStream(ms, aes.CreateEncryptor(aes.Key, aes.IV), CryptoStreamMode.Write))
        {
            cs.Write(rawData, 0, rawData.Length);
            cs.FlushFinalBlock();
        }
        return Convert.ToBase64String(ms.ToArray());
    }

    public string Decrypt(string input)
    {
        using var aes = Aes.Create();
        aes.Key = _key;
        aes.IV = _iv;

        var encData = Convert.FromBase64String(input);
        using var ms = new MemoryStream(encData);
        using var cs = new CryptoStream(ms, aes.CreateDecryptor(aes.Key, aes.IV), CryptoStreamMode.Read);
        using var dec = new MemoryStream();
        cs.CopyTo(dec);
        return Encoding.UTF8.GetString(dec.ToArray());
    }
}
