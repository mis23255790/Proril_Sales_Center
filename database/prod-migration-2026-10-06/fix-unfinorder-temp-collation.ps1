<#
.SYNOPSIS
    修正未完成訂單 ERP 來源顯示 "??ERP"：prc_QueryUnfinOrder / prc_QueryUnfinOrder_1 的
    #TmpDataSet.COP_Source 補上 COLLATE DATABASE_DEFAULT。

.DESCRIPTION
    #temp 欄位沒指定定序會用 tempdb 的 SQL_Latin1_General_CP1_CI_AS，varchar(7) 存不下中文，
    '浦瑞ERP'／'芳晟ERP' 寫進去就變 '??ERP'。

    不重跑 SalesOrderUnfinishObjectsMigration.sql：那支會連 V_UnfinOrder 一起 CREATE OR ALTER，
    而 V_UnfinOrder 之後被 NpsSerialNoObjectsMigration.sql 改過，重跑會蓋回舊版。
    這裡改成讀資料庫現行的 SP 定義、只替換那一行，再 CREATE OR ALTER 回去。可重複執行。

.EXAMPLE
    .\prod-migration-2026-10-06\fix-unfinorder-temp-collation.ps1 -Environment snapshot            # dry-run
    .\prod-migration-2026-10-06\fix-unfinorder-temp-collation.ps1 -Environment snapshot-prod -Execute
#>
param(
    [ValidateSet('snapshot', 'snapshot-prod')][string]$Environment = 'snapshot',
    [switch]$Execute
)

. "$PSScriptRoot\..\scripts\_common.ps1"
Import-DotEnv

$old = '[COP_Source] [varchar](7) NULL,'
$new = '[COP_Source] [varchar](7) COLLATE DATABASE_DEFAULT NULL,  -- tempdb 是 Latin1，不指定中文會變 ??'

$conn = $null
try {
    $b = New-Object System.Data.SqlClient.SqlConnectionStringBuilder (Get-ConnectionString $Environment)
    $b['Initial Catalog'] = 'Proril_Sales_Center'
    $conn = New-Object System.Data.SqlClient.SqlConnection $b.ConnectionString
    $conn.Open()
    Write-Host "目標：$($conn.DataSource) / Proril_Sales_Center [$Environment]"

    foreach ($proc in 'prc_QueryUnfinOrder', 'prc_QueryUnfinOrder_1') {
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = "SELECT OBJECT_DEFINITION(OBJECT_ID('dbo.$proc'))"
        $def = $cmd.ExecuteScalar()
        if ($def -is [DBNull] -or -not $def) { throw "找不到 dbo.$proc" }

        $hits = ([regex]::Matches($def, [regex]::Escape($old))).Count
        if ($hits -eq 0) {
            $status = if ($def.Contains('COLLATE DATABASE_DEFAULT NULL,  -- tempdb')) { '已修正，跳過' } else { '找不到要替換的欄位定義，跳過（請人工確認）' }
            Write-Host "  $proc：$status"
            continue
        }
        if ($hits -ne 1) { throw "$proc 有 $hits 處符合，預期 1 處，停止。" }

        $fixed = [regex]::Replace($def.Replace($old, $new), '^\s*CREATE\s+(OR\s+ALTER\s+)?PROC(EDURE)?\b', 'CREATE OR ALTER PROCEDURE',
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($fixed -notmatch '^CREATE OR ALTER PROCEDURE') { throw "$proc 定義開頭不是 CREATE PROCEDURE，停止。" }

        if (-not $Execute) { Write-Host "  $proc：會修正（dry-run）"; continue }

        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $fixed
        [void]$cmd.ExecuteNonQuery()
        Write-Host "  $proc：已修正"
    }

    # 驗證：同一個連線上模擬 #temp 寫入，確認中文不會變問號
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "CREATE TABLE #chk (c varchar(7) COLLATE DATABASE_DEFAULT NULL); INSERT #chk VALUES ('浦瑞ERP'); SELECT c FROM #chk;"
    Write-Host "  #temp 驗證（COLLATE DATABASE_DEFAULT）：$($cmd.ExecuteScalar())"

    if (-not $Execute) { Write-Host ''; Write-Host 'dry-run 結束，沒有動任何東西。確認無誤後加 -Execute 真的執行。' }
}
catch {
    Write-Host "[fix-unfinorder-temp-collation] 失敗：$($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace
    throw
}
finally {
    if ($conn) { $conn.Dispose() }
}
