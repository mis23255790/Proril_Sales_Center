<#
.SYNOPSIS
    比對測試區與正式區在白名單資料表上的 schema 差異。

.DESCRIPTION
    回答「測試區有哪些欄位還沒上正式區」。上線前跑一次，就知道這次要帶什麼 schema 變更。
    純讀取 INFORMATION_SCHEMA，不需要 SqlPackage，也不會寫任何東西。

.EXAMPLE
    .\drift.ps1
    .\drift.ps1 -Detailed
#>
[CmdletBinding()]
param(
    [switch]$Detailed
)

. "$PSScriptRoot\_common.ps1"

function Get-SchemaSnapshot {
    param(
        [Parameter(Mandatory = $true)][string]$ConnectionString,
        [Parameter(Mandatory = $true)][string[]]$Tables
    )
    try {
        $a = ConvertTo-SqlCmdArgs -ConnectionString $ConnectionString
        $inList = ($Tables | ForEach-Object { "'" + $_.Replace("'", "''") + "'" }) -join ','

        # 用 CHAR(9) 當分隔，避免表名/欄位名裡的符號打壞解析
        $query = @"
SET NOCOUNT ON;
SELECT c.TABLE_NAME + CHAR(9) + c.COLUMN_NAME + CHAR(9) + c.DATA_TYPE
     + CHAR(9) + ISNULL(CAST(c.CHARACTER_MAXIMUM_LENGTH AS varchar(10)), '')
     + CHAR(9) + c.IS_NULLABLE
     + CHAR(9) + ISNULL(c.COLUMN_DEFAULT, '')
FROM INFORMATION_SCHEMA.COLUMNS c
WHERE c.TABLE_SCHEMA = 'dbo' AND c.TABLE_NAME IN ($inList)
ORDER BY c.TABLE_NAME, c.ORDINAL_POSITION;
"@

        $raw = & sqlcmd -S $a.Server -U $a.User -P $a.Password -d $a.Database `
                    -C -h -1 -W -s "`t" -Q $query
        if ($LASTEXITCODE -ne 0) { throw "sqlcmd 查詢失敗 (exit $LASTEXITCODE)" }

        $map = @{}
        foreach ($line in $raw) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $p = $line -split "`t"
            if ($p.Count -lt 5) { continue }

            $key = "$($p[0].Trim()).$($p[1].Trim())"
            $map[$key] = [PSCustomObject]@{
                Table    = $p[0].Trim()
                Column   = $p[1].Trim()
                Type     = $p[2].Trim()
                Length   = $p[3].Trim()
                Nullable = $p[4].Trim()
                Default  = if ($p.Count -ge 6) { $p[5].Trim() } else { '' }
            }
        }
        return $map
    }
    catch {
        Write-Host "[Get-SchemaSnapshot] $($_.Exception.Message)" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace
        throw
    }
}

try {
    Assert-SqlCmd | Out-Null
    $tables = Get-ManagedTables

    Write-Host "讀取測試區..." -ForegroundColor Cyan
    $test = Get-SchemaSnapshot -ConnectionString (Get-ConnectionString -Environment test) -Tables $tables

    Write-Host "讀取正式區..." -ForegroundColor Cyan
    $prod = Get-SchemaSnapshot -ConnectionString (Get-ConnectionString -Environment prod) -Tables $tables

    $onlyTest = $test.Keys | Where-Object { -not $prod.ContainsKey($_) } | Sort-Object
    $onlyProd = $prod.Keys | Where-Object { -not $test.ContainsKey($_) } | Sort-Object
    $changed  = $test.Keys | Where-Object {
        $prod.ContainsKey($_) -and (
            $test[$_].Type     -ne $prod[$_].Type -or
            $test[$_].Length   -ne $prod[$_].Length -or
            $test[$_].Nullable -ne $prod[$_].Nullable
        )
    } | Sort-Object

    Write-Host ""
    Write-Host "===== Schema 漂移報告 =====" -ForegroundColor Cyan
    Write-Host "納管資料表 $($tables.Count) 張，測試區欄位 $($test.Count) 個，正式區 $($prod.Count) 個。"
    Write-Host ""

    if ($onlyTest.Count -eq 0 -and $onlyProd.Count -eq 0 -and $changed.Count -eq 0) {
        Write-Host "兩邊完全一致，沒有未上線的 schema 變更。" -ForegroundColor Green
        exit 0
    }

    if ($onlyTest.Count -gt 0) {
        Write-Host "[未上線] 測試區有、正式區沒有 —— 這些就是上線時要帶的欄位：" -ForegroundColor Yellow
        foreach ($k in $onlyTest) {
            $c = $test[$k]
            $len = if ($c.Length -ne '') { "($($c.Length))" } else { '' }
            $nul = if ($c.Nullable -eq 'YES') { 'NULL' } else { 'NOT NULL' }
            Write-Host ("  + {0,-45} {1}{2} {3}" -f $k, $c.Type, $len, $nul) -ForegroundColor Yellow
            if ($c.Nullable -eq 'NO' -and $c.Default -eq '') {
                Write-Host ("      風險：NOT NULL 且無 DEFAULT，正式區既有資料列會讓 ALTER 失敗。" ) -ForegroundColor Red
            }
        }
        Write-Host ""
    }

    if ($onlyProd.Count -gt 0) {
        Write-Host "[反向漂移] 正式區有、測試區沒有 —— 測試區可能被人手動砍過，要查：" -ForegroundColor Red
        foreach ($k in $onlyProd) { Write-Host "  - $k" -ForegroundColor Red }
        Write-Host ""
    }

    if ($changed.Count -gt 0) {
        Write-Host "[型別/可空性不同] 兩邊同名但定義不同：" -ForegroundColor Red
        foreach ($k in $changed) {
            $t = $test[$k]; $p = $prod[$k]
            Write-Host "  ~ $k" -ForegroundColor Red
            Write-Host "      測試: $($t.Type)($($t.Length)) $($t.Nullable)"
            Write-Host "      正式: $($p.Type)($($p.Length)) $($p.Nullable)"
        }
        Write-Host ""
    }

    if ($Detailed) {
        Write-Host "[明細] 測試區未上線欄位的完整定義：" -ForegroundColor Cyan
        $onlyTest | ForEach-Object { $test[$_] } | Format-Table -AutoSize
    }

    Write-Host "提醒：未上線欄位請進 feature branch 的 database/Tables/*.sql，不要留在 main。" -ForegroundColor Cyan
    exit 0
}
catch {
    Write-Host "[drift] 失敗: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace
    exit 1
}
