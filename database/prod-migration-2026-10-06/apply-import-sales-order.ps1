<#
.SYNOPSIS
    只更新 prc_ImportSalesOrder（銷貨檢索的 ERP 銷貨單快取匯入）：匯入時也更新 ERP 已修改的既有資料。

.DESCRIPTION
    原本只 INSERT 快取裡還沒有的銷貨單，已匯入的列永遠不更新；鼎新事後調整本幣金額尾差（±1）等，
    銷貨檢索總金額就會跟 ERP / 1.0 對不起來。SalesShippingObjectsMigration.sql 已加上 UPDATE 段。

    不重跑整支 SalesShippingObjectsMigration.sql，只從檔案抽出
    CREATE OR ALTER PROCEDURE [dbo].[prc_ImportSalesOrder] 到下一個 GO 的區塊執行，其他物件不動。
    執行前會先確認兩邊現行定義（修改前）跟腳本一致才繼續，避免蓋掉別人在 DB 上的修改。

    -Run：套用後順便執行一次 prc_ImportSalesOrder（等於有人按了一次銷貨檢索的查詢），
    顯示花費時間與更新筆數。

.EXAMPLE
    .\prod-migration-2026-10-06\apply-import-sales-order.ps1 -Environment snapshot              # dry-run
    .\prod-migration-2026-10-06\apply-import-sales-order.ps1 -Environment snapshot -Execute -Run
#>
param(
    [ValidateSet('snapshot', 'snapshot-prod')][string]$Environment = 'snapshot',
    [switch]$Execute,
    [switch]$Run
)

. "$PSScriptRoot\..\scripts\_common.ps1"
Import-DotEnv

$file = Join-Path $script:DbRoot 'SalesShippingObjectsMigration.sql'
$text = [IO.File]::ReadAllText($file, [Text.Encoding]::UTF8)
$m = [regex]::Match($text, '(?ms)^CREATE OR ALTER PROCEDURE \[dbo\]\.\[prc_ImportSalesOrder\].*?(?=^GO\s*$)')
if (-not $m.Success) { throw '腳本裡找不到 prc_ImportSalesOrder 區塊' }
$procSql = $m.Value

$conn = $null
try {
    $b = New-Object System.Data.SqlClient.SqlConnectionStringBuilder (Get-ConnectionString $Environment)
    $b['Initial Catalog'] = 'Proril_Sales_Center'
    $conn = New-Object System.Data.SqlClient.SqlConnection $b.ConnectionString
    $conn.Open()
    $conn.add_InfoMessage({ param($s, $e) Write-Host "  [SQL] $($e.Message)" })
    Write-Host "目標：$($conn.DataSource) / Proril_Sales_Center [$Environment]"

    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "SELECT OBJECT_DEFINITION(OBJECT_ID('dbo.prc_ImportSalesOrder'))"
    $live = [string]$cmd.ExecuteScalar()
    $norm = { param($s) $k = 'PROCEDURE[dbo].[prc_ImportSalesOrder]'; $t = $s -replace '\s+', ''; $t.Substring([Math]::Max(0, $t.IndexOf($k))) }
    if ((& $norm $live) -eq (& $norm $procSql)) {
        Write-Host '  現行定義已是新版，不需要套用。'
    }
    elseif ($live -notmatch 'CSO\.TH001 IS NULL') {
        throw '現行定義看起來不是 prc_ImportSalesOrder 的已知版本（可能被別人改過），停止，請人工比對。'
    }
    else {
        # CREATE PROCEDURE 必須是 batch 第一句，PARSEONLY 開關要各自一個 batch
        foreach ($batch in 'SET PARSEONLY ON', $procSql, 'SET PARSEONLY OFF') {
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = $batch
            [void]$cmd.ExecuteNonQuery()
        }
        Write-Host '  語法檢查通過。'

        if (-not $Execute) {
            Write-Host ''
            Write-Host 'dry-run 結束，沒有動任何東西。確認無誤後加 -Execute 真的執行。'
            return
        }
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $procSql
        [void]$cmd.ExecuteNonQuery()
        Write-Host '  已套用 prc_ImportSalesOrder。'
    }

    if ($Run) {
        $cmd = $conn.CreateCommand()
        $cmd.CommandTimeout = 300
        $cmd.CommandText = "DECLARE @r varchar(50); EXEC dbo.prc_ImportSalesOrder 'apply-import-sales-order', @r OUTPUT; SELECT @r;"
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $r = $cmd.ExecuteScalar()
        $sw.Stop()
        Write-Host "  執行 prc_ImportSalesOrder：$r，$($sw.ElapsedMilliseconds) ms"
    }
}
catch {
    Write-Host "[apply-import-sales-order] 失敗：$($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace
    throw
}
finally {
    if ($conn) { $conn.Dispose() }
}
