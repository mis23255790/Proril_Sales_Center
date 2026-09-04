<#
.SYNOPSIS
    比對任兩個環境在白名單資料表上的 schema 差異。

.DESCRIPTION
    預設比對測試區/正式區：回答「測試區有哪些欄位還沒上正式區」，上線前跑一次
    就知道這次要帶什麼 schema 變更。純讀取 INFORMATION_SCHEMA，不需要
    SqlPackage，也不會寫任何東西。

    -From / -To 可以換成 'snapshot'（獨立資料庫 Proril_Sales_Center），
    拿來查那個快照庫跟 PRORIL_WEB 是不是真的長一樣、有沒有偷加欄位進去。

.EXAMPLE
    .\drift.ps1
    .\drift.ps1 -Detailed
    .\drift.ps1 -From snapshot -To prod
#>
[CmdletBinding()]
param(
    [ValidateSet('test', 'prod', 'snapshot', 'snapshot-prod')][string]$From = 'test',
    [ValidateSet('test', 'prod', 'snapshot', 'snapshot-prod')][string]$To = 'prod',
    [switch]$Detailed
)

. "$PSScriptRoot\_common.ps1"

# 只用來讓報告的文字好讀，不影響邏輯。
$script:EnvLabel = @{
    test          = '測試區'
    prod          = '正式區'
    snapshot      = '快照庫-測試(Proril_Sales_Center@test)'
    'snapshot-prod' = '快照庫-正式(Proril_Sales_Center@prod)'
}

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
    $fromLabel = $script:EnvLabel[$From]
    $toLabel = $script:EnvLabel[$To]

    Write-Host "讀取 $fromLabel..." -ForegroundColor Cyan
    $fromSnap = Get-SchemaSnapshot -ConnectionString (Get-ConnectionString -Environment $From) -Tables $tables

    Write-Host "讀取 $toLabel..." -ForegroundColor Cyan
    $toSnap = Get-SchemaSnapshot -ConnectionString (Get-ConnectionString -Environment $To) -Tables $tables

    $onlyFrom = $fromSnap.Keys | Where-Object { -not $toSnap.ContainsKey($_) } | Sort-Object
    $onlyTo   = $toSnap.Keys | Where-Object { -not $fromSnap.ContainsKey($_) } | Sort-Object
    $changed  = $fromSnap.Keys | Where-Object {
        $toSnap.ContainsKey($_) -and (
            $fromSnap[$_].Type     -ne $toSnap[$_].Type -or
            $fromSnap[$_].Length   -ne $toSnap[$_].Length -or
            $fromSnap[$_].Nullable -ne $toSnap[$_].Nullable
        )
    } | Sort-Object

    Write-Host ""
    Write-Host "===== Schema 漂移報告：$fromLabel -> $toLabel =====" -ForegroundColor Cyan
    Write-Host "納管資料表 $($tables.Count) 張，$fromLabel 欄位 $($fromSnap.Count) 個，$toLabel 欄位 $($toSnap.Count) 個。"
    Write-Host ""

    if ($onlyFrom.Count -eq 0 -and $onlyTo.Count -eq 0 -and $changed.Count -eq 0) {
        Write-Host "兩邊完全一致，沒有差異。" -ForegroundColor Green
        exit 0
    }

    if ($onlyFrom.Count -gt 0) {
        Write-Host "[$fromLabel 有、$toLabel 沒有]：" -ForegroundColor Yellow
        foreach ($k in $onlyFrom) {
            $c = $fromSnap[$k]
            $len = if ($c.Length -ne '') { "($($c.Length))" } else { '' }
            $nul = if ($c.Nullable -eq 'YES') { 'NULL' } else { 'NOT NULL' }
            Write-Host ("  + {0,-45} {1}{2} {3}" -f $k, $c.Type, $len, $nul) -ForegroundColor Yellow
            if ($c.Nullable -eq 'NO' -and $c.Default -eq '') {
                Write-Host ("      風險：NOT NULL 且無 DEFAULT，往 $toLabel 部署會讓 ALTER 失敗。" ) -ForegroundColor Red
            }
        }
        Write-Host ""
    }

    if ($onlyTo.Count -gt 0) {
        Write-Host "[反向漂移] $toLabel 有、$fromLabel 沒有 —— 可能被人手動砍過或加過，要查：" -ForegroundColor Red
        foreach ($k in $onlyTo) { Write-Host "  - $k" -ForegroundColor Red }
        Write-Host ""
    }

    if ($changed.Count -gt 0) {
        Write-Host "[型別/可空性不同] 兩邊同名但定義不同：" -ForegroundColor Red
        foreach ($k in $changed) {
            $f = $fromSnap[$k]; $t = $toSnap[$k]
            Write-Host "  ~ $k" -ForegroundColor Red
            Write-Host "      $($fromLabel): $($f.Type)($($f.Length)) $($f.Nullable)"
            Write-Host "      $($toLabel): $($t.Type)($($t.Length)) $($t.Nullable)"
        }
        Write-Host ""
    }

    if ($Detailed) {
        Write-Host "[明細] $fromLabel 獨有欄位的完整定義：" -ForegroundColor Cyan
        $onlyFrom | ForEach-Object { $fromSnap[$_] } | Format-Table -AutoSize
    }

    if ($From -eq 'test' -and $To -eq 'prod') {
        Write-Host "提醒：未上線欄位請進 feature branch 的 database/Tables/*.sql，不要留在 main。" -ForegroundColor Cyan
    }
    exit 0
}
catch {
    Write-Host "[drift] 失敗: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace
    exit 1
}
