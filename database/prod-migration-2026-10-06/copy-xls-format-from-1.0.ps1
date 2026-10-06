<#
.SYNOPSIS
    把 1.0 PRORIL_WEB 的 Excel 匯出版型（2.0 有用到的三支）搬進 Proril_Sales_Center.dbo.CMN_XlsFileFormat。

.DESCRIPTION
    來源（1.0 PRORIL_WEB）            → 2.0 PermissionKey
      PUR_XlsFileFormat FunctionNo 410 → salesSearch.mixSalesShipping（銷貨檢索）
      PUR_XlsFileFormat FunctionNo 420 → salesSearch.queryUnFinish（未完成訂單）
      CMN_XlsFileFormat FunctionNo 425 → salesSearch.orderInfoVerify（訂單資料檢核）
    FunctionSubNo（0 = 有金額、1 = 無金額）與其他欄位照搬，StyleWrapText 留 NULL。
    1.0 存的顏色字串（"Color Index: 64"、"Color Theme: Text1, Tint: 0"、ARGB）
    2.0 的 XlsStyleCodec 都讀得懂，不用轉。

    為什麼是 PowerShell 不是 .sql：正式區沒有一個帳號同時能讀 PRORIL_WEB 又能寫 Proril_Sales_Center
    （proril_sales_center 讀不到 PRORIL_WEB；proril_ac1 讀得到但對新庫沒有 INSERT），
    所以分兩條連線：來源用 -SourceEnv（預設 prod = proril_ac1），目標用 -TargetEnv（預設 snapshot-prod）。

    目標已經有某組 (PermissionKey, FunctionSubNo) 的版型就跳過該組（不覆寫格式匯入頁匯入過的），
    要覆寫加 -Replace（先刪該組再寫）。整批在一個交易內。

.EXAMPLE
    .\prod-migration-2026-10-06\copy-xls-format-from-1.0.ps1                 # dry-run
    .\prod-migration-2026-10-06\copy-xls-format-from-1.0.ps1 -Execute
#>
param(
    [ValidateSet('test', 'prod')][string]$SourceEnv = 'prod',
    [ValidateSet('snapshot', 'snapshot-prod')][string]$TargetEnv = 'snapshot-prod',
    [switch]$Replace,
    [switch]$Execute
)

. "$PSScriptRoot\..\scripts\_common.ps1"
Import-DotEnv

$map = @(
    @{ Table = 'PUR_XlsFileFormat'; FunctionNo = 410; Key = 'salesSearch.mixSalesShipping' },
    @{ Table = 'PUR_XlsFileFormat'; FunctionNo = 420; Key = 'salesSearch.queryUnFinish' },
    @{ Table = 'CMN_XlsFileFormat'; FunctionNo = 425; Key = 'salesSearch.orderInfoVerify' }
)

$copyCols = 'WSName', 'ColumnStartID', 'ColumnEndID', 'RowStartID', 'RowEndID', 'Caption', 'FormulaA1',
    'StyleAlignmentH', 'StyleAlignmentV', 'StyleBorderLeft', 'StyleBorderTop', 'StyleBorderRight', 'StyleBorderBottom',
    'StyleFillColor', 'StyleFontSize', 'StyleFontBold', 'StyleFontColor', 'Width', 'Height', 'SplitRow', 'SplitColumn',
    'XLSettings', 'IsHidden', 'Creator', 'CreateTime', 'Modifier', 'ModiTime'

$open = {
    param([string]$envName, [string]$database)
    $b = New-Object System.Data.SqlClient.SqlConnectionStringBuilder (Get-ConnectionString $envName)
    # PowerShell 把 builder 當字典處理，屬性寫法會被當成連線字串關鍵字，要用索引
    $b['Initial Catalog'] = $database
    $c = New-Object System.Data.SqlClient.SqlConnection $b.ConnectionString
    $c.Open()
    return $c
}

$src = $null; $dst = $null; $tx = $null
try {
    $src = & $open $SourceEnv 'PRORIL_WEB'
    $dst = & $open $TargetEnv 'Proril_Sales_Center'
    Write-Host "來源：$($src.DataSource) / PRORIL_WEB [$SourceEnv]"
    Write-Host "目標：$($dst.DataSource) / Proril_Sales_Center [$TargetEnv]"
    Write-Host ''

    # 讀來源（ID 照順序，維持 1.0 寫入順序）
    $data = New-Object System.Data.DataTable
    foreach ($m in $map) {
        $sql = "SELECT CAST(@key AS varchar(100)) AS PermissionKey, RTRIM(FunctionSubNo) AS FunctionSubNo, " +
            (($copyCols | ForEach-Object { if ($_ -eq 'WSName') { 'RTRIM(WSName) AS WSName' } else { "[$_]" } }) -join ', ') +
            " FROM dbo.$($m.Table) WHERE FunctionNo = @no ORDER BY ID"
        $cmd = $src.CreateCommand()
        $cmd.CommandText = $sql
        [void]$cmd.Parameters.AddWithValue('@key', $m.Key)
        [void]$cmd.Parameters.AddWithValue('@no', $m.FunctionNo)
        $da = New-Object System.Data.SqlClient.SqlDataAdapter $cmd
        [void]$da.Fill($data)
    }

    # 依 (PermissionKey, FunctionSubNo) 分組，對照目標現況
    $groups = $data.Rows | Group-Object { "$($_.PermissionKey)|$($_.FunctionSubNo)" } | Sort-Object Name
    $plan = @()
    foreach ($g in $groups) {
        $key, $subNo = $g.Name -split '\|', 2
        $cmd = $dst.CreateCommand()
        $cmd.CommandText = 'SELECT COUNT(*) FROM dbo.CMN_XlsFileFormat WHERE PermissionKey = @k AND FunctionSubNo = @s'
        [void]$cmd.Parameters.AddWithValue('@k', $key)
        [void]$cmd.Parameters.AddWithValue('@s', $subNo)
        $existing = [int]$cmd.ExecuteScalar()
        $sheets = ($g.Group | ForEach-Object { $_.WSName } | Select-Object -Unique) -join '、'
        $action = if ($existing -eq 0) { 'INSERT' } elseif ($Replace) { 'REPLACE' } else { 'SKIP' }
        $plan += [pscustomobject]@{ PermissionKey = $key; SubNo = $subNo; Rows = $g.Count; Sheets = $sheets; TargetRows = $existing; Action = $action; Group = $g.Group }
    }
    $plan | Format-Table PermissionKey, SubNo, Rows, Sheets, TargetRows, Action -AutoSize | Out-String -Width 200 | Write-Host

    $todo = @($plan | Where-Object { $_.Action -ne 'SKIP' })
    if ($todo.Count -eq 0) { Write-Host '沒有要寫入的版型。'; return }
    if (-not $Execute) { Write-Host 'dry-run 結束，沒有動任何東西。確認無誤後加 -Execute 真的執行。'; return }

    $tx = $dst.BeginTransaction()
    $now = Get-Date
    foreach ($p in $todo) {
        if ($p.Action -eq 'REPLACE') {
            $cmd = $dst.CreateCommand()
            $cmd.Transaction = $tx
            $cmd.CommandText = 'DELETE FROM dbo.CMN_XlsFileFormat WHERE PermissionKey = @k AND FunctionSubNo = @s'
            [void]$cmd.Parameters.AddWithValue('@k', $p.PermissionKey)
            [void]$cmd.Parameters.AddWithValue('@s', $p.SubNo)
            [void]$cmd.ExecuteNonQuery()
        }
        $batch = $data.Clone()
        foreach ($r in $p.Group) { $batch.ImportRow($r) }

        $bulk = New-Object System.Data.SqlClient.SqlBulkCopy($dst, [System.Data.SqlClient.SqlBulkCopyOptions]::CheckConstraints, $tx)
        $bulk.DestinationTableName = 'dbo.CMN_XlsFileFormat'
        foreach ($col in $batch.Columns) { [void]$bulk.ColumnMappings.Add($col.ColumnName, $col.ColumnName) }
        $bulk.WriteToServer($batch)
        $bulk.Close()
        Write-Host "已寫入 $($p.PermissionKey) / $($p.SubNo)：$($p.Rows) 筆"
    }
    $tx.Commit()
    $tx = $null
    Write-Host ''
    Write-Host "完成（$($now.ToString('yyyy-MM-dd HH:mm:ss'))）。"
}
catch {
    Write-Host "[copy-xls-format-from-1.0] 失敗，已 rollback：$($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace
    if ($tx) { $tx.Rollback() }
    throw
}
finally {
    if ($src) { $src.Dispose() }
    if ($dst) { $dst.Dispose() }
}
