<#
.SYNOPSIS
    把白名單資料表的「資料列」從 PRORIL_WEB 複製到同一個 instance 上的獨立快照庫 Proril_Sales_Center。

.DESCRIPTION
    這支專門處理「資料列」——DACPAC 那套 (extract.ps1 / publish.ps1) 刻意只管結構
    (ExtractAllTableData=false)，不會碰任何一筆資料，對照的就是 CLAUDE.md 說的
    「18 張表一次性複製」那個動作。

    來源跟目標永遠在同一個 SQL Server instance 上（同一個 -Environment 對應的 port），
    用三段式命名 (`[PRORIL_WEB].dbo.表`) 跨資料庫查詢，不需要 linked server，
    但登入帳號要同時對兩個資料庫有存取權。

    執行前置條件（缺一都會直接失敗，不會半吊子跑一半）：
      1. 目標資料庫 Proril_Sales_Center 要先存在——這支不會、也不能建資料庫本身
         （見 database/README.md「情境速查表」，建空庫需要比 publish 更高的權限，
         本專案的部署帳號刻意不給）。
      2. 目標資料庫要先有白名單表的結構：跑
         `.\publish.ps1 -Environment <對應的 snapshot 環境> -Execute`
      3. `.env` 要有對應的 PRORIL_DB_SNAPSHOT / PRORIL_DB_SNAPSHOT_PROD

    M_System / M_Function 刻意排除在外（$script:PartialRowTables）：那兩張在目標庫只保留
    2.0 用得到的那幾列，由 database/PermissionMasterSeed.sql 維護，整批覆蓋會灌進一堆
    2.0 沒有的功能。

    **不加 -Tables 的話會覆蓋白名單裡的每一張表**，包含 D_WorkProcess* / CRM_Customer /
    H_FileLink——那幾張在 Proril_Sales_Center 已經是正式讀寫的資料，而 PRORIL_WEB 那份
    停在 2026-09-03 的快照，整批跑下去等於把業務議題的資料倒退回舊版本。
    要補灌特定幾張（例如帳號權限）請務必用 -Tables 限定範圍。

    預設 dry-run：只列出「來源列數 -> 目標列數」對照，不會動任何資料。加 -Execute
    才會真的複製，而且是**整批覆蓋**（先清空目標的白名單表，再從來源灌全新的），
    不是增量同步，執行前務必確認目標端沒有需要保留的資料。

    複製流程分三段，避免白名單表之間的 FK 互相卡住：
      1. 全部表先 NOCHECK 約束、DELETE 清空
      2. 全部表逐一 INSERT（有 IDENTITY 欄位會包 SET IDENTITY_INSERT 保留原始 ID）
      3. 全部表 WITH CHECK CHECK CONSTRAINT ALL，確認資料複製完之後約束仍然成立

.PARAMETER Environment
    來源 PRORIL_WEB 所在的 instance：
      test -> 目標對到 -Environment snapshot（Proril_Sales_Center@50002，已存在）
      prod -> 目標對到 -Environment snapshot-prod（Proril_Sales_Center@51002，還沒建）

.PARAMETER Tables
    只處理指定的表（白名單的子集，大小寫不拘）。不指定就是白名單全部——那會覆蓋
    業務議題等已經在用的表，見上面的警告。

.PARAMETER Execute
    真的執行複製。不加只會做 dry-run（列出兩邊列數對照）。

.EXAMPLE
    .\copy-snapshot-data.ps1 -Environment test
    .\copy-snapshot-data.ps1 -Environment test -Execute
    .\copy-snapshot-data.ps1 -Environment prod -Execute
    .\copy-snapshot-data.ps1 -Environment test -Tables M_User,M_Permission -Execute
#>
[CmdletBinding()]
param(
    [ValidateSet('test', 'prod')][string]$Environment = 'prod',
    [string[]]$Tables,
    [switch]$Execute
)

. "$PSScriptRoot\_common.ps1"

$script:SnapshotEnvMap = @{ test = 'snapshot'; prod = 'snapshot-prod' }

# 這兩張表在 Proril_Sales_Center **只保留 2.0 真的有頁面的那幾列**（3 個系統別 + 8 個功能），
# 不是整份複製。整批覆蓋會把 1.0 全部 90+ 個功能灌進來，2.0 的權限樹就會長出一堆
# 點下去 404 的功能，所以這支腳本刻意跳過它們——資料由 database/PermissionMasterSeed.sql
# 維護（含 varchar → nvarchar 的中文欄位覆寫）。詳見 PortingNotes.md
# 「功能主檔（M_System / M_Function）只搬 2.0 用得到的列」。
$script:PartialRowTables = @('M_System', 'M_Function')

function Invoke-SqlLines {
    # 對目標資料庫執行一段 sqlcmd 查詢，回傳非空白的輸出行。
    param(
        [Parameter(Mandatory = $true)][hashtable]$Target,
        [Parameter(Mandatory = $true)][string]$Query
    )
    try {
        $raw = & sqlcmd -S $Target.Server -U $Target.User -P $Target.Password -d $Target.Database `
                    -C -h -1 -W -Q $Query
        if ($LASTEXITCODE -ne 0) { throw "sqlcmd 失敗 (exit $LASTEXITCODE)" }
        return @($raw | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }
    catch {
        Write-Host "[Invoke-SqlLines] $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "查詢: $Query"
        throw
    }
}

function Test-TargetTableExists {
    param([hashtable]$Target, [string]$Table)
    $q = "SET NOCOUNT ON; SELECT CASE WHEN OBJECT_ID(N'dbo.$Table') IS NULL THEN 'NO' ELSE 'YES' END;"
    return ((Invoke-SqlLines -Target $Target -Query $q) -join '') -eq 'YES'
}

function Get-RowCount {
    param([hashtable]$Target, [string]$ThreePartTable)
    $q = "SET NOCOUNT ON; SELECT CAST(COUNT(*) AS varchar(20)) FROM $ThreePartTable;"
    return ((Invoke-SqlLines -Target $Target -Query $q) -join '').Trim()
}

try {
    Assert-SqlCmd | Out-Null

    $targetEnv = $script:SnapshotEnvMap[$Environment]
    $sourceConn = Get-ConnectionString -Environment $Environment
    $targetConn = Get-ConnectionString -Environment $targetEnv

    $sourceArgs = ConvertTo-SqlCmdArgs -ConnectionString $sourceConn
    $targetArgs = ConvertTo-SqlCmdArgs -ConnectionString $targetConn
    $sourceDb = $sourceArgs.Database

    if ($sourceArgs.Server -ne $targetArgs.Server) {
        throw "來源 ($($sourceArgs.Server)) 跟目標 ($($targetArgs.Server)) 不是同一個 instance——這支腳本假設兩邊同一台，用三段式命名跨資料庫，不支援跨機器。"
    }

    Write-Host "來源: $($sourceArgs.Server) / $sourceDb" -ForegroundColor Cyan
    Write-Host "目標: $($targetArgs.Server) / $($targetArgs.Database)（-Environment $targetEnv）" -ForegroundColor Cyan
    Write-Host ""

    # 注意：**不要**把這個區域變數叫 $tables。PowerShell 變數不分大小寫，
    # 那樣會直接覆寫掉參數 $Tables，-Tables 的過濾就會變成「全部都符合」（踩過一次）。
    $managedTables = Get-ManagedTables | Where-Object { $script:PartialRowTables -notcontains $_ }

    if ($Tables) {
        $requested = @($Tables | ForEach-Object { $_.Trim() })
        $unknown = @($requested | Where-Object { $managedTables -notcontains $_ })
        if ($unknown.Count -gt 0) {
            throw "-Tables 指定了不在白名單（或被 PartialRowTables 排除）的表：$($unknown -join ', ')"
        }
        $managedTables = @($managedTables | Where-Object { $requested -contains $_ })
        Write-Host "只處理 -Tables 指定的 $($managedTables.Count) 張：$($managedTables -join ', ')" -ForegroundColor Cyan
        Write-Host ""
    }
    else {
        Write-Host "警告：沒有指定 -Tables，白名單裡的每一張表都會被整批覆蓋。" -ForegroundColor Yellow
        Write-Host "      D_WorkProcess* / CRM_Customer / H_FileLink 在目標庫已經是正式資料，" -ForegroundColor Yellow
        Write-Host "      來源 PRORIL_WEB 那份是舊快照——確定要整批倒回去嗎？" -ForegroundColor Yellow
        Write-Host ""
    }

    $skippedPartial = Get-ManagedTables | Where-Object { $script:PartialRowTables -contains $_ }
    if ($skippedPartial.Count -gt 0) {
        Write-Host "[跳過] 這幾張在 Proril_Sales_Center 只保留 2.0 用得到的那幾列，不整批覆蓋：" -ForegroundColor Yellow
        $skippedPartial | ForEach-Object { Write-Host "  ~ $_" -ForegroundColor Yellow }
        Write-Host "        它們的資料由 database/PermissionMasterSeed.sql 維護，見 PortingNotes.md。" -ForegroundColor Yellow
        Write-Host ""
    }

    $ready = @()
    $notReady = @()

    foreach ($table in $managedTables) {
        if (Test-TargetTableExists -Target $targetArgs -Table $table) {
            $ready += $table
        }
        else {
            $notReady += $table
        }
    }

    if ($notReady.Count -gt 0) {
        Write-Host "[跳過] 目標還沒有這些表的結構，先跑 .\publish.ps1 -Environment $targetEnv -Execute：" -ForegroundColor Yellow
        $notReady | ForEach-Object { Write-Host "  ! $_" -ForegroundColor Yellow }
        Write-Host ""
    }

    if ($ready.Count -eq 0) {
        Write-Host "目標端一張白名單表的結構都還沒有，沒東西可以複製。" -ForegroundColor Red
        exit 1
    }

    if (-not $Execute) {
        Write-Host "dry-run 模式：只列出列數對照，不會動任何資料。加 -Execute 才會真的複製（整批覆蓋，不是增量）。" -ForegroundColor Cyan
        Write-Host ""
        foreach ($table in $ready) {
            $sourceCount = Get-RowCount -Target $targetArgs -ThreePartTable "[$sourceDb].dbo.[$table]"
            $targetCount = Get-RowCount -Target $targetArgs -ThreePartTable "dbo.[$table]"
            Write-Host ("  {0,-25} 來源 {1,8} 列  ->  目標 {2,8} 列" -f $table, $sourceCount, $targetCount)
        }
        Write-Host ""
        Write-Host "確認無誤後加 -Execute 執行。" -ForegroundColor Cyan
        exit 0
    }

    Write-Host "即將整批覆蓋目標端這 $($ready.Count) 張表的資料（先清空再從來源複製）。" -ForegroundColor Red
    $answer = Read-Host "確定執行？(yes/no)"
    if ($answer -ne 'yes') {
        Write-Host "已取消。" -ForegroundColor Yellow
        exit 1
    }

    Write-Host ""
    Write-Host "[1/3] 停用約束、清空目標資料..." -ForegroundColor Cyan
    foreach ($table in $ready) {
        $q = "SET NOCOUNT ON; ALTER TABLE dbo.[$table] NOCHECK CONSTRAINT ALL; DELETE FROM dbo.[$table];"
        Invoke-SqlLines -Target $targetArgs -Query $q | Out-Null
        Write-Host "  - $table 已清空"
    }

    Write-Host ""
    Write-Host "[2/3] 從來源逐表複製..." -ForegroundColor Cyan
    foreach ($table in $ready) {
        $copyQuery = @"
SET NOCOUNT ON;
DECLARE @cols nvarchar(max);
SELECT @cols = STUFF((
    SELECT ',' + QUOTENAME(COLUMN_NAME)
    FROM [$sourceDb].INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = '$table'
    ORDER BY ORDINAL_POSITION
    FOR XML PATH('')), 1, 1, '');

DECLARE @hasIdentity bit = CASE WHEN EXISTS (
    SELECT 1 FROM [$sourceDb].sys.columns c
    JOIN [$sourceDb].sys.tables t ON c.object_id = t.object_id
    WHERE t.name = '$table' AND c.is_identity = 1
) THEN 1 ELSE 0 END;

DECLARE @sql nvarchar(max) = N'';
IF @hasIdentity = 1 SET @sql += N'SET IDENTITY_INSERT dbo.[$table] ON; ';
SET @sql += N'INSERT INTO dbo.[$table] (' + @cols + N') SELECT ' + @cols + N' FROM [$sourceDb].dbo.[$table];';
IF @hasIdentity = 1 SET @sql += N' SET IDENTITY_INSERT dbo.[$table] OFF;';

EXEC sp_executesql @sql;
"@
        Invoke-SqlLines -Target $targetArgs -Query $copyQuery | Out-Null
        $newCount = Get-RowCount -Target $targetArgs -ThreePartTable "dbo.[$table]"
        Write-Host "  - $table 複製完成，目標現在 $newCount 列"
    }

    Write-Host ""
    Write-Host "[3/3] 重新檢查約束..." -ForegroundColor Cyan
    foreach ($table in $ready) {
        $q = "ALTER TABLE dbo.[$table] WITH CHECK CHECK CONSTRAINT ALL;"
        Invoke-SqlLines -Target $targetArgs -Query $q | Out-Null
        Write-Host "  - $table 約束已重新驗證"
    }

    Write-Host ""
    Write-Host "複製完成。建議接著跑 .\drift.ps1 -From $targetEnv -To $Environment 確認兩邊一致。" -ForegroundColor Green
}
catch {
    Write-Host "[copy-snapshot-data] 失敗: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace
    exit 1
}
