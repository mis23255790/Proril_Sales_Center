using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.FileProviders;
using Microsoft.IdentityModel.Tokens;
using Proril.SalesIssue.Api.Data;
using Proril.SalesIssue.Api.Filters;
using Proril.SalesIssue.Api.Helpers;
using Proril.SalesIssue.Api.Middleware;

var builder = WebApplication.CreateBuilder(args);

// ---------------------------------------------------------------- 設定檢查

var connectionString = builder.Configuration.GetConnectionString("ProrilWeb");
if (string.IsNullOrWhiteSpace(connectionString))
{
    // 早點爆比之後每支 API 都回 500 好追
    throw new InvalidOperationException(
        "ConnectionStrings:ProrilWeb 未設定。請在 appsettings.Development.json（本機）"
        + "或環境變數 ConnectionStrings__ProrilWeb（部署）填入 PRORIL_WEB 的連線字串。");
}

// ---------------------------------------------------------------- 服務

builder.Services.AddDbContext<SalesIssueDbContext>(options =>
    options.UseSqlServer(connectionString));

builder.Services.AddSingleton<JwtHelper>();
builder.Services.AddSingleton<AesHelper>();
builder.Services.AddSingleton<StoragePaths>();
builder.Services.AddControllers(options => options.Filters.Add<ApiExceptionFilter>());

/*
 * CORS。
 * 正常情況下前端是走 Nuxt 的 /api/proxy 轉發（同源），不需要 CORS；
 * 這裡開放的是「直接用瀏覽器打 API」的開發情境。
 * 來源白名單放在設定檔，不要寫死也不要用 AllowAnyOrigin。
 */
var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
builder.Services.AddCors(options =>
{
    options.AddPolicy("SalesCenter", policy =>
    {
        if (allowedOrigins.Length > 0)
        {
            policy.WithOrigins(allowedOrigins).AllowAnyHeader().AllowAnyMethod().AllowCredentials();
        }
    });
});

/*
 * JWT。
 * 參數必須與 1.0 PRORIL 完全一致（Issuer + SignKey + 不驗 audience），
 * 兩邊的 token 才互通，可以漸進切換而不必強迫使用者重新登入。
 */
builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.IncludeErrorDetails = builder.Environment.IsDevelopment();
        options.TokenValidationParameters = new TokenValidationParameters
        {
            NameClaimType = "sub",
            RoleClaimType = "role",
            ValidateIssuer = true,
            ValidIssuer = builder.Configuration.GetValue<string>("JwtSettings:Issuer"),
            ValidateAudience = false,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = false,
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(builder.Configuration.GetValue<string>("JwtSettings:SignKey") ?? ""))
        };
    });

builder.Services.AddAuthorization();

var app = builder.Build();

// ---------------------------------------------------------------- Pipeline

/*
 * /ShareRoot 靜態檔。
 * GetDownloadUrl 回的路徑就是對應這裡。刻意**不開** EnableDirectoryBrowsing：
 * 1.0 開著，等於任何人都能瀏覽整個共享目錄的檔案清單。
 */
var storagePaths = app.Services.GetRequiredService<StoragePaths>();
Directory.CreateDirectory(storagePaths.ShareRoot);

app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new PhysicalFileProvider(Path.GetFullPath(storagePaths.ShareRoot)),
    RequestPath = "/ShareRoot",
    // 附件什麼副檔名都有，不在白名單內的也要能下載
    ServeUnknownFileTypes = true,
    DefaultContentType = "application/octet-stream"
});

app.UseMiddleware<RequestLoggingMiddleware>();
app.UseRouting();
app.UseCors("SalesCenter");
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

// 給 Docker/K8s 健康檢查用，不需要 token
app.MapGet("/health", () => Results.Ok(new { status = "ok", utc = DateTime.UtcNow })).AllowAnonymous();

app.Run();
