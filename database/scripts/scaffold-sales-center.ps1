<#
.SYNOPSIS
    對獨立資料庫 Proril_Sales_Center 的全部資料表跑 dotnet ef dbcontext scaffold，
    整批覆蓋 api/Data/SalesCenterDbContext.cs，並把 Entity 產到 api/Data/SalesCenter/。

.DESCRIPTION
    跟 sync-model.ps1 定位不同：sync-model.ps1 只列差異、逐表手動搬，
    這支是整批覆蓋（--force），採用即代表放棄「哪個表確定安全再搬」的逐表遷移，
    請自行承擔 CLAUDE.md 提過的風險。

    2026 的權限控管搬遷把 M_User / M_Permission / M_PermissionGroup 一起切到
    Proril_Sales_Center（1.0 的人員管理與權限管理邏輯也一併搬進 api/），所以
    -ExcludeAuthTables 預設已改成 $false，這三張表會被 scaffold 進來。
    只有在「要退回讓 1.0 繼續管帳號權限」時才需要 -ExcludeAuthTables:$true。

    Entity 與 DbContext 都輸出到獨立 namespace（Proril.SalesIssue.Api.Data.SalesCenter，
    實體檔在 api/Data/SalesCenter/）：兩邊都要放同一個 namespace，不能只有 Entity
    搬過去、Context 留在根 namespace——C# 對「同一個檔案所在 namespace」裡的同名類別
    優先於 using 匯入的類別，Context 留根 namespace的話，modelBuilder.Entity&lt;CopCheckRule&gt;()
    這種寫法會誤解析成 OrderInfoVerifyEntities.cs 裡舊的 CopCheckRule（給
    ProrilWebDbContext 用、欄位可能沒同步更新過），編譯或執行期都會抓錯型別。
    Program.cs 的 DI 註冊需要補一行 using Proril.SalesIssue.Api.Data.SalesCenter;
    （這支腳本第一次跑時會順手處理掉舊的根目錄 SalesCenterDbContext.cs）。

    跑之前要先裝 dotnet-ef：
        dotnet tool install --global dotnet-ef --version 8.0.22
    連線資訊讀 database/.env 的 PRORIL_DB_SNAPSHOT（複製 .env.example 後填值）。

.PARAMETER Environment
    連哪個環境的 Proril_Sales_Center：snapshot（測試區，已存在）或
    snapshot-prod（正式區，見 CLAUDE.md，可能還沒建好，沒填 .env 會直接報錯）。

.PARAMETER ExcludeAuthTables
    是否排除 M_User / M_Permission，預設 $true。

.EXAMPLE
    .\scaffold-sales-center.ps1
    .\scaffold-sales-center.ps1 -Environment snapshot-prod
    .\scaffold-sales-center.ps1 -ExcludeAuthTables:$true
#>
[CmdletBinding()]
param(
    [ValidateSet('snapshot', 'snapshot-prod')][string]$Environment = 'snapshot',
    [bool]$ExcludeAuthTables = $false
)

. "$PSScriptRoot\_common.ps1"

$script:ApiDir = Join-Path (Split-Path -Parent $script:DbRoot) 'api'

function Assert-DotnetEf {
    & dotnet ef --version *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "找不到 dotnet-ef。請先安裝：dotnet tool install --global dotnet-ef --version 8.0.22"
    }
}

function Get-AllTableNames {
    param([Parameter(Mandatory = $true)][string]$ConnectionString)
    $a = ConvertTo-SqlCmdArgs -ConnectionString $ConnectionString
    $query = @"
SET NOCOUNT ON;
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'dbo' AND TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;
"@
    $raw = & sqlcmd -S $a.Server -U $a.User -P $a.Password -d $a.Database -C -h -1 -W -Q $query
    if ($LASTEXITCODE -ne 0) { throw "sqlcmd 查詢表清單失敗 (exit $LASTEXITCODE)" }
    return $raw | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() }
}

try {
    Assert-SqlCmd | Out-Null
    Assert-DotnetEf

    $cs = Get-ConnectionString -Environment $Environment
    $allTables = Get-AllTableNames -ConnectionString $cs
    if ($allTables.Count -eq 0) { throw "$Environment 環境查不到任何表，連線字串可能不對。" }

    $authTables = @('M_User', 'M_Permission', 'M_PermissionGroup')
    $targetTables = if ($ExcludeAuthTables) {
        $allTables | Where-Object { $authTables -notcontains $_ }
    }
    else {
        $allTables
    }

    if ($ExcludeAuthTables) {
        $skipped = $allTables | Where-Object { $authTables -contains $_ }
        if ($skipped.Count -gt 0) {
            Write-Host "排除（退回讓 1.0 管帳號權限）: $($skipped -join ', ')" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "M_User/M_Permission/M_PermissionGroup 會被納入 SalesCenterDbContext（2026 權限控管搬遷的預設）。" -ForegroundColor Cyan
        Write-Host "前提是 1.0 站台的人員管理／權限管理已經停用，否則兩邊帳號權限會分岔。" -ForegroundColor Cyan
    }

    if ($targetTables.Count -eq 0) { throw "篩選後沒有任何表可以 scaffold。" }

    Write-Host ""
    Write-Host "即將 scaffold $($targetTables.Count) 張表：" -ForegroundColor Cyan
    $targetTables | ForEach-Object { Write-Host "  - $_" }
    Write-Host ""

    $tableArgs = $targetTables | ForEach-Object { '--table', $_ }

    # 第一次跑之前手動建立的舊版空殼在 api/Data 根 namespace，Context 改搬進
    # SalesCenter 子 namespace 後這份舊檔會變成沒人用、卻可能撞名的殭屍檔案，先清掉。
    $staleContextFile = Join-Path $script:ApiDir 'Data/SalesCenterDbContext.cs'
    if (Test-Path $staleContextFile) {
        Remove-Item $staleContextFile -Force
        Write-Host "已刪除舊路徑的殼: $staleContextFile" -ForegroundColor DarkGray
    }

    # dotnet ef 會先把整個 api 專案 build 一次才能執行 scaffold，Program.cs 已經
    # using Proril.SalesIssue.Api.Data.SalesCenter 並注入 SalesCenterDbContext，
    # 這個型別若暫時不存在（例如上面才剛清掉舊殼）會直接 build failed、scaffold
    # 根本跑不起來——所以先確保新路徑上有一份能編過的最小空殼，跑完 --force 覆蓋掉。
    $targetContextFile = Join-Path $script:ApiDir 'Data/SalesCenter/SalesCenterDbContext.cs'
    if (-not (Test-Path $targetContextFile)) {
        New-Item -ItemType Directory -Force -Path (Split-Path $targetContextFile) | Out-Null
        @'
using Microsoft.EntityFrameworkCore;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public class SalesCenterDbContext : DbContext
{
    public SalesCenterDbContext(DbContextOptions<SalesCenterDbContext> options) : base(options) { }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
    }
}
'@ | Set-Content -Path $targetContextFile -Encoding UTF8
        Write-Host "已在新路徑補一份可編過的空殼，等 scaffold 覆蓋: $targetContextFile" -ForegroundColor DarkGray
    }

    Push-Location $script:ApiDir
    try {
        dotnet ef dbcontext scaffold `
            $cs `
            Microsoft.EntityFrameworkCore.SqlServer `
            --context SalesCenterDbContext `
            --context-dir Data/SalesCenter `
            --context-namespace Proril.SalesIssue.Api.Data.SalesCenter `
            --output-dir Data/SalesCenter `
            --namespace Proril.SalesIssue.Api.Data.SalesCenter `
            --no-onconfiguring `
            --force `
            @tableArgs

        if ($LASTEXITCODE -ne 0) { throw "dotnet ef dbcontext scaffold 失敗 (exit $LASTEXITCODE)" }
    }
    finally {
        Pop-Location
    }

    Write-Host ""
    Write-Host "完成。SalesCenterDbContext.cs + Entity 都在 api/Data/SalesCenter/，namespace 是" -ForegroundColor Green
    Write-Host "Proril.SalesIssue.Api.Data.SalesCenter。" -ForegroundColor Green
    Write-Host "接下來：" -ForegroundColor Cyan
    Write-Host "  1. api/Program.cs 加一行 using Proril.SalesIssue.Api.Data.SalesCenter;（原本只有" -ForegroundColor Cyan
    Write-Host "     using Proril.SalesIssue.Api.Data; 找不到搬過去的 SalesCenterDbContext）。" -ForegroundColor Cyan
    Write-Host "  2. dotnet build api/Proril.SalesIssue.Api.csproj 確認能編過。" -ForegroundColor Cyan
    Write-Host "  3. 哪支 Controller 改連這個 DbContext 仍要逐一確認——COP_PoCheck 等表分散在" -ForegroundColor Cyan
    Write-Host "     ErpImportApiController / BomQueryApiController / OrderInfoVerifyApiController 三支呼叫 SP，見 CLAUDE.md。" -ForegroundColor Cyan
    exit 0
}
catch {
    Write-Host "[scaffold-sales-center] 失敗: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace
    exit 1
}
