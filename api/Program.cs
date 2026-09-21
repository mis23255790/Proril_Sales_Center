using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.FileProviders;
using Microsoft.IdentityModel.Tokens;
using Proril.SalesIssue.Api.Data;
using Proril.SalesIssue.Api.Data.SalesCenter;
using Proril.SalesIssue.Api.Filters;
using Proril.SalesIssue.Api.Helpers;
using Proril.SalesIssue.Api.Middleware;
using Proril.SalesIssue.Api.Services;

var builder = WebApplication.CreateBuilder(args);

// ---------------------------------------------------------------- 設定檢查

var prorilWebConnectionString = builder.Configuration.GetConnectionString("ProrilWeb");
if (string.IsNullOrWhiteSpace(prorilWebConnectionString))
{
    // 早點爆比之後每支 API 都回 500 好追
    throw new InvalidOperationException(
        "ConnectionStrings:ProrilWeb 未設定。請在 appsettings.Development.json（本機）"
        + "或環境變數 ConnectionStrings__ProrilWeb（部署）填入 PRORIL_WEB 的連線字串。");
}

var salesCenterConnectionString = builder.Configuration.GetConnectionString("SalesCenter");
if (string.IsNullOrWhiteSpace(salesCenterConnectionString))
{
    throw new InvalidOperationException(
        "ConnectionStrings:SalesCenter 未設定。請在 appsettings.Development.json（本機）"
        + "或環境變數 ConnectionStrings__SalesCenter（部署）填入 Proril_Sales_Center 的連線字串。");
}

// ---------------------------------------------------------------- 服務

// PRORIL_WEB 舊庫：M_User / M_Permission（1.0 還在寫，2.0 唯讀）+ 尚未搬遷的檢核表/ERP view。
builder.Services.AddDbContext<ProrilWebDbContext>(options =>
    options.UseSqlServer(prorilWebConnectionString));

// Proril_Sales_Center 獨立庫：業務議題本體 + CRM_Customer + H_FileLink，已確認單一擁有者，
// WorkProcessApiController / CustomQueryApiController.SaveCustom / UploadApiController.AddFileLog
// 都打這裡讀寫，見 CLAUDE.md 「已核對」段落。
builder.Services.AddDbContext<SalesCenterDbContext>(options =>
    options.UseSqlServer(salesCenterConnectionString));

builder.Services.AddSingleton<JwtHelper>();
builder.Services.AddSingleton<AesHelper>();
builder.Services.AddSingleton<StoragePaths>();
builder.Services.AddSingleton<LogHelper>();

// Proril_Manufacturing_Center 還沒有對應端點，BaseUrl 現在是空的（見 appsettings），
// 呼叫端 ManufacturingSerialNoLookupService 在空值時會丟例外，不在這裡註冊時就先擋下來
// ——不然開發環境還沒設定這個服務，整個 api 會直接起不來。
builder.Services.AddHttpClient("ManufacturingCenter");
builder.Services.AddScoped<ManufacturingSerialNoLookupService>();
builder.Services.AddHostedService<LogTimedHostedService>();
builder.Services.AddHostedService<SerialNoSyncHostedService>();
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
 * wwwroot 靜態檔（目前只有 images/ic_mission.png、images/ic_test.png）。
 * M_System.ImagePath 存的是這種站台根目錄相對路徑，topbar 環境圖示用它分辨正式/測試區
 * （見 useSystemInfo.ts）。放進 api/ 自己的 wwwroot，圖示才不會綁死在 1.0 站台還活著。
 */
app.UseStaticFiles();

/*
 * /ShareRoot 靜態檔。
 * GetDownloadUrl 回的路徑就是對應這裡。跟 1.0 一樣開 EnableDirectoryBrowsing：
 * 任何人都能瀏覽整個共享目錄的檔案清單，是刻意跟 1.0 對齊的已知風險，不是這裡新增的。
 */
var storagePaths = app.Services.GetRequiredService<StoragePaths>();
Directory.CreateDirectory(storagePaths.ShareRoot);

app.UseFileServer(new FileServerOptions
{
    FileProvider = new PhysicalFileProvider(Path.GetFullPath(storagePaths.ShareRoot)),
    RequestPath = "/ShareRoot",
    EnableDirectoryBrowsing = true,
    StaticFileOptions =
    {
        // 附件什麼副檔名都有，不在白名單內的也要能下載
        ServeUnknownFileTypes = true,
        DefaultContentType = "application/octet-stream"
    }
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
