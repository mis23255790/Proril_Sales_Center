<#
.SYNOPSIS
    把獨立資料庫 Proril_Sales_Center 的定序改成與來源 PRORIL_WEB 相同
    （Chinese_Taiwan_Stroke_BIN），包含資料庫預設定序與所有既有字元欄位。

.DESCRIPTION
    **為什麼要做這件事**

    Proril_Sales_Center 當初建庫時用的是 instance 預設的
    SQL_Latin1_General_CP1_CI_AS，與 PRORIL_WEB 的 Chinese_Taiwan_Stroke_BIN 不同。
    PortingNotes.md「為什麼有 N 個欄位型別跟來源不一樣」只處理了「varchar 存中文會變 ?」
    這一半，另一半沒處理：**比對與排序語意**。

    已經實測到的症狀（2026-09-14，銷貨檢索）：同一份資料、同一組查詢條件，
    prc_QuerySalesOrder_1 在兩個庫回傳的分群統計筆數不一樣
    （N/S/Y = 200/24/33 vs 194/23/32）。原因是 SP 的
    ORDER BY TG003,COP_Source,TH001,TH002,TH003 在兩種定序下順序有 13 列不同
    （COP_Source 是中文，筆畫序 vs Latin1 序差很多），而 SP 的分群是用游標比對相鄰列做的。

    同樣的語意差也存在於已經切連線的業務議題／權限控管那幾張表：
    字串比對從 1.0 的 BIN（區分大小寫、區分全半形）變成 CI_AS（不分大小寫）。

    **這支做什麼**

      1. ALTER DATABASE ... COLLATE（只影響之後新建的物件與系統中繼資料，
         **不會**動到既有欄位——這是 SQL Server 的行為，所以才需要第 3 步）
      2. 把含字元欄位的索引先 DROP（ALTER COLUMN 不能動索引鍵欄位）
      3. 逐欄 ALTER TABLE ... ALTER COLUMN ... COLLATE，型別/長度/可為空原樣保留
      4. 重建第 2 步卸掉的索引
      5. 驗證：列出還沒對齊的欄位（正常應該是 0）

    **需要停機**：第 1 步要 SINGLE_USER（會踢掉所有連線）。跑之前先關掉 api/
    與任何連著這個庫的工具（含其他人的 SSMS 視窗）。

    **不會動資料列**：ALTER COLUMN 只改定序，不轉 code page——這些欄位不是 nvarchar
    就是只存英數，內容不變。跑完仍然建議自己抽查中文欄位。

    **DACPAC 那邊**：Tables/*.sql 不帶 COLLATE 子句，publish 時欄位會沿用資料庫預設，
    所以這支跑完之後 DACPAC 產出的新欄位自動就是對的，不用改那些 .sql。
    PortingNotes 裡那幾個 varchar → nvarchar 的覆寫可以留著（nvarchar 一定安全），
    改完定序之後它們只是「比來源寬鬆」，不是錯。

.PARAMETER Environment
    snapshot      Proril_Sales_Center@50002（測試區）
    snapshot-prod Proril_Sales_Center@51002（正式區，還沒建）

.PARAMETER Collation
    目標定序，預設 Chinese_Taiwan_Stroke_BIN（= PRORIL_WEB 現況）。

.PARAMETER Execute
    真的執行。不加只做 dry-run：印出現況、會被改的欄位數、會被重建的索引、
    以及完整的 ALTER 敘述，不動任何東西。

.EXAMPLE
    .\fix-collation.ps1 -Environment snapshot
    .\fix-collation.ps1 -Environment snapshot -Execute
#>
[CmdletBinding()]
param(
    [ValidateSet('snapshot', 'snapshot-prod')][string]$Environment = 'snapshot',
    [string]$Collation = 'Chinese_Taiwan_Stroke_BIN',
    [switch]$Execute
)

. "$PSScriptRoot\_common.ps1"

function Invoke-SqlLines {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Target,
        [Parameter(Mandatory = $true)][string]$Query,
        [string]$Database
    )
    try {
        $db = if ([string]::IsNullOrWhiteSpace($Database)) { $Target.Database } else { $Database }
        $raw = & sqlcmd -S $Target.Server -U $Target.User -P $Target.Password -d $db `
                    -C -h -1 -W -b -f 65001 -Q $Query
        if ($LASTEXITCODE -ne 0) { throw "sqlcmd 失敗 (exit $LASTEXITCODE)" }
        return @($raw | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }
    catch {
        Write-Host "[Invoke-SqlLines] $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "查詢: $Query"
        throw
    }
}

# 產生「逐欄 ALTER COLUMN」敘述。型別/長度/可為空照 sys.columns 原樣帶出來，
# 只換 COLLATE，不做任何型別轉換。
$script:GenAlterColumns = @"
SET NOCOUNT ON;
SELECT 'ALTER TABLE ' + QUOTENAME(SCHEMA_NAME(o.schema_id)) + '.' + QUOTENAME(o.name)
     + ' ALTER COLUMN ' + QUOTENAME(c.name) + ' ' + t.name
     + CASE
         WHEN t.name IN ('nvarchar','nchar')
           THEN '(' + CASE WHEN c.max_length = -1 THEN 'max' ELSE CAST(c.max_length / 2 AS varchar(10)) END + ')'
         WHEN t.name IN ('varchar','char')
           THEN '(' + CASE WHEN c.max_length = -1 THEN 'max' ELSE CAST(c.max_length AS varchar(10)) END + ')'
         ELSE ''
       END
     + ' COLLATE $Collation'
     + CASE WHEN c.is_nullable = 1 THEN ' NULL;' ELSE ' NOT NULL;' END
FROM sys.columns c
JOIN sys.objects o ON o.object_id = c.object_id
JOIN sys.types t ON t.user_type_id = c.user_type_id
WHERE o.type = 'U' AND o.is_ms_shipped = 0
  AND c.collation_name IS NOT NULL
  AND c.collation_name <> '$Collation'
ORDER BY o.name, c.column_id;
"@

# 含字元欄位的索引：ALTER COLUMN 動不了索引鍵欄位，要先 DROP 再重建。
# 這裡把 DROP 與 CREATE 兩段都產出來（含唯一性、包含欄位、排序方向）。
$script:GenIndexScripts = @"
SET NOCOUNT ON;
WITH ix AS (
    SELECT DISTINCT i.object_id, i.index_id
    FROM sys.indexes i
    JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
    JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
    JOIN sys.objects o ON o.object_id = i.object_id
    WHERE i.type > 0 AND i.is_primary_key = 0 AND i.is_unique_constraint = 0
      AND o.type = 'U' AND o.is_ms_shipped = 0
      AND c.collation_name IS NOT NULL AND c.collation_name <> '$Collation'
)
SELECT
    'DROP INDEX ' + QUOTENAME(i.name) + ' ON ' + QUOTENAME(SCHEMA_NAME(o.schema_id)) + '.' + QUOTENAME(o.name) + ';'
  + CHAR(9) + '|' + CHAR(9) +
    'CREATE ' + CASE WHEN i.is_unique = 1 THEN 'UNIQUE ' ELSE '' END + i.type_desc COLLATE DATABASE_DEFAULT
  + ' INDEX ' + QUOTENAME(i.name) + ' ON ' + QUOTENAME(SCHEMA_NAME(o.schema_id)) + '.' + QUOTENAME(o.name)
  + ' (' + STUFF((SELECT ', ' + QUOTENAME(c2.name) + CASE WHEN ic2.is_descending_key = 1 THEN ' DESC' ELSE ' ASC' END
                  FROM sys.index_columns ic2
                  JOIN sys.columns c2 ON c2.object_id = ic2.object_id AND c2.column_id = ic2.column_id
                  WHERE ic2.object_id = i.object_id AND ic2.index_id = i.index_id AND ic2.is_included_column = 0
                  ORDER BY ic2.key_ordinal FOR XML PATH('')), 1, 2, '') + ')'
  + ISNULL(' INCLUDE (' + STUFF((SELECT ', ' + QUOTENAME(c3.name)
                  FROM sys.index_columns ic3
                  JOIN sys.columns c3 ON c3.object_id = ic3.object_id AND c3.column_id = ic3.column_id
                  WHERE ic3.object_id = i.object_id AND ic3.index_id = i.index_id AND ic3.is_included_column = 1
                  ORDER BY c3.name FOR XML PATH('')), 1, 2, '') + ')', '')
  + ISNULL(' WHERE ' + i.filter_definition, '') + ';'
FROM sys.indexes i
JOIN ix ON ix.object_id = i.object_id AND ix.index_id = i.index_id
JOIN sys.objects o ON o.object_id = i.object_id;
"@

# varchar/char 換定序 = 換 code page（Latin1 CP1252 → 中文 CP950），內容只要全是
# ASCII 就是 no-op；一旦有非 ASCII 位元組，重新解讀會變成別的字。跑之前先掃一次。
$script:CheckNonAscii = @"
SET NOCOUNT ON;
DECLARE @sql nvarchar(max) = N'';
SELECT @sql = @sql + N'SELECT ''' + o.name + N'.' + c.name + N''' AS col, COUNT(*) AS cnt FROM ' + QUOTENAME(o.name)
            + N' WHERE ' + QUOTENAME(c.name) + N' COLLATE Latin1_General_BIN LIKE ''%[^ -~]%'' HAVING COUNT(*) > 0 UNION ALL '
FROM sys.columns c
JOIN sys.objects o ON o.object_id = c.object_id
JOIN sys.types t ON t.user_type_id = c.user_type_id
WHERE o.type = 'U' AND o.is_ms_shipped = 0 AND t.name IN ('varchar','char') AND c.max_length <> -1;
IF @sql = N'' RETURN;
SET @sql = LEFT(@sql, LEN(@sql) - 10);
EXEC sp_executesql @sql;
"@

try {
    Assert-SqlCmd | Out-Null

    $target = ConvertTo-SqlCmdArgs -ConnectionString (Get-ConnectionString -Environment $Environment)

    Write-Host "目標  : $($target.Server) / $($target.Database)  [$Environment]" -ForegroundColor Cyan
    Write-Host "目標定序: $Collation" -ForegroundColor Cyan
    Write-Host ""

    $current = (Invoke-SqlLines -Target $target -Query "SET NOCOUNT ON; SELECT CAST(DATABASEPROPERTYEX('$($target.Database)','Collation') AS nvarchar(128));") -join ''
    Write-Host "資料庫目前預設定序: $current"

    $pending = (Invoke-SqlLines -Target $target -Query "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.columns c JOIN sys.objects o ON o.object_id=c.object_id WHERE o.type='U' AND o.is_ms_shipped=0 AND c.collation_name IS NOT NULL AND c.collation_name <> '$Collation';") -join ''
    Write-Host "尚未對齊的字元欄位: $pending 個"
    Write-Host ""

    if ($current -eq $Collation -and $pending -eq '0') {
        Write-Host "已經全部對齊，不用做任何事。" -ForegroundColor Green
        return
    }

    $nonAscii = Invoke-SqlLines -Target $target -Query $script:CheckNonAscii
    if ($nonAscii.Count -gt 0) {
        Write-Host "警告：以下 varchar/char 欄位含非 ASCII 內容，換定序會重新解讀 code page：" -ForegroundColor Red
        foreach ($n in $nonAscii) { Write-Host "  $n" -ForegroundColor Red }
        Write-Host "請先確認這些內容，或把欄位改成 nvarchar 再跑這支。" -ForegroundColor Red
        if ($Execute) { throw "有非 ASCII 的 varchar 欄位，中止。" }
        Write-Host ""
    }
    else {
        Write-Host "varchar/char 欄位全部只有 ASCII 內容，換 code page 不會動到資料。" -ForegroundColor Green
        Write-Host ""
    }

    $alters = Invoke-SqlLines -Target $target -Query $script:GenAlterColumns
    $indexPairs = Invoke-SqlLines -Target $target -Query $script:GenIndexScripts

    $drops = @()
    $creates = @()
    foreach ($line in $indexPairs) {
        $parts = $line -split "`t\|`t"
        if ($parts.Count -eq 2) {
            $drops += $parts[0].Trim()
            $creates += $parts[1].Trim()
        }
    }

    Write-Host "會重建的索引: $($drops.Count) 個" -ForegroundColor Cyan
    foreach ($d in $drops) { Write-Host "  $d" }
    Write-Host ""
    Write-Host "會執行的 ALTER COLUMN: $($alters.Count) 個" -ForegroundColor Cyan
    foreach ($a in $alters) { Write-Host "  $a" -ForegroundColor DarkGray }
    Write-Host ""

    if (-not $Execute) {
        Write-Host "dry-run 結束，沒有動任何東西。" -ForegroundColor Yellow
        Write-Host "確認無誤後加 -Execute。**執行時會 SINGLE_USER 踢掉所有連線**，" -ForegroundColor Yellow
        Write-Host "請先停掉 api/ 與任何連著這個庫的工具。" -ForegroundColor Yellow
        return
    }

    $db = $target.Database

    Write-Host "1/5 切 SINGLE_USER 並改資料庫預設定序..." -ForegroundColor Cyan
    Invoke-SqlLines -Target $target -Database 'master' -Query @"
ALTER DATABASE [$db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
ALTER DATABASE [$db] COLLATE $Collation;
"@ | Out-Null

    try {
        Write-Host "2/5 卸掉含字元欄位的索引..." -ForegroundColor Cyan
        if ($drops.Count -gt 0) { Invoke-SqlLines -Target $target -Query ($drops -join "`n") | Out-Null }

        Write-Host "3/5 逐欄 ALTER COLUMN（$($alters.Count) 個）..." -ForegroundColor Cyan
        if ($alters.Count -gt 0) { Invoke-SqlLines -Target $target -Query ($alters -join "`n") | Out-Null }

        Write-Host "4/5 重建索引..." -ForegroundColor Cyan
        if ($creates.Count -gt 0) { Invoke-SqlLines -Target $target -Query ($creates -join "`n") | Out-Null }
    }
    finally {
        Write-Host "5/5 切回 MULTI_USER..." -ForegroundColor Cyan
        Invoke-SqlLines -Target $target -Database 'master' -Query "ALTER DATABASE [$db] SET MULTI_USER;" | Out-Null
    }

    $after = (Invoke-SqlLines -Target $target -Query "SET NOCOUNT ON; SELECT CAST(DATABASEPROPERTYEX('$db','Collation') AS nvarchar(128));") -join ''
    $left = (Invoke-SqlLines -Target $target -Query "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.columns c JOIN sys.objects o ON o.object_id=c.object_id WHERE o.type='U' AND o.is_ms_shipped=0 AND c.collation_name IS NOT NULL AND c.collation_name <> '$Collation';") -join ''

    Write-Host ""
    Write-Host "完成。資料庫預設定序: $after ／尚未對齊的欄位: $left" -ForegroundColor Green
    if ($left -ne '0') {
        Write-Host "還有欄位沒對齊，請看上面的錯誤訊息。" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "[fix-collation] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace
    exit 1
}
