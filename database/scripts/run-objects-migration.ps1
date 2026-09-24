<#
.SYNOPSIS
    把 View / 預存程序 / 函式的搬移腳本（database/*ObjectsMigration.sql）
    對獨立資料庫 Proril_Sales_Center 執行。

.DESCRIPTION
    DACPAC 那套（extract.ps1 / publish.ps1）**只管資料表結構**，刻意不納管
    View / StoredProcedure（見 database/README.md）。但把 1.0 既有的 View/SP
    原樣複製一份到 Proril_Sales_Center 又是必要的一步，所以那些物件寫在
    database/ 底下的 *ObjectsMigration.sql，由這支負責執行。

    目前有四支腳本：
      OrderCheckObjectsMigration.sql       訂單資料檢核：7 View + 5 SP + 1 函式 + 5 表
      SalesShippingObjectsMigration.sql    銷貨檢索：3 SP + 1 表
      SalesOrderUnfinishObjectsMigration.sql 未完成訂單檢索：1 View + 2 SP，沒有表
      （V_UnfinOrder 每次都直接查 ERP linked server，不落地快取，所以不用複製任何資料）
      CustomerRelatedObjectsMigration.sql  客戶相關資訊：1 View（V_SalesTotal）+ 1 表（CRM_CustomerMemo）
      （唯一不需要 linked server 的一支，只對本地資料操作）
      CustomerViewObjectsMigration.sql     客戶查詢：1 View（V_COP_Customer），依賴 linked server，沒有表
      RbacObjectsMigration.sql             角色制權限：3 表（RBAC_Role / RBAC_RolePermission / RBAC_RoleUser）
      （會把 M_Permission 既有個人權限轉成角色；不需要 linked server，報「不存在」不影響它）

    三支都是可重複執行的（CREATE TABLE 包 IF OBJECT_ID(...) IS NULL、
    CREATE OR ALTER PROCEDURE/VIEW/FUNCTION、資料複製區塊在表已有資料時自動跳過）。

    預設 dry-run：只做檢查、不改任何東西——
      1. 目標資料庫連得上，而且 Initial Catalog 跟腳本裡的 USE 一致
      2. linked server [192.168.1.200]（鼎新 ERP）在這個 instance 上存在
         —— 多數腳本的 View/SP 靠它查 ERP，缺了語法能過但執行會失敗。
         例外是 CustomerRelatedObjectsMigration.sql，它只讀本地的 COP_SalesOrder，
         這項報「不存在」也不影響它。
      3. 列出腳本會建立的物件，以及它們在目標端「已存在／不存在」
      4. 用 SET PARSEONLY ON 把整份腳本送進 SQL Server 驗一次語法

    加 -Execute 才會真的執行。

    **編碼**：腳本是 UTF-8 無 BOM，而且 prc_ImportSalesOrder 裡有中文字串常值
    （'浦瑞ERP' / '芳晟ERP'）。一律用 sqlcmd -f 65001 讀，不要改用別的方式跑，
    也不要在 SSMS 以「ANSI」開啟後另存，否則那兩個字串會變亂碼寫進資料。

.PARAMETER Script
    要執行哪一支。省略時列出可選清單後結束。

.PARAMETER Environment
    目標獨立資料庫：
      snapshot      Proril_Sales_Center@50002（測試區，已存在）
      snapshot-prod Proril_Sales_Center@51002（正式區，還沒建）

.PARAMETER Execute
    真的執行。不加只做上面那四項檢查。

.EXAMPLE
    .\run-objects-migration.ps1
    .\run-objects-migration.ps1 -Script SalesShippingObjectsMigration.sql -Environment snapshot
    .\run-objects-migration.ps1 -Script SalesShippingObjectsMigration.sql -Environment snapshot -Execute
#>
[CmdletBinding()]
param(
    [ValidateSet('OrderCheckObjectsMigration.sql', 'SalesShippingObjectsMigration.sql', 'SalesOrderUnfinishObjectsMigration.sql', 'CustomerRelatedObjectsMigration.sql', 'CustomerViewObjectsMigration.sql', 'RbacObjectsMigration.sql')]
    [string]$Script,
    [ValidateSet('snapshot', 'snapshot-prod')][string]$Environment = 'snapshot',
    [switch]$Execute
)

. "$PSScriptRoot\_common.ps1"

# 多數腳本的 View/SP 透過這個 linked server 查鼎新 ERP
# （CustomerRelatedObjectsMigration.sql 例外，只讀本地表）。
$script:ErpLinkedServer = '192.168.1.200'

function Get-MigrationScripts {
    # database/ 底下所有 *ObjectsMigration.sql。
    try {
        return @(Get-ChildItem -Path $script:DbRoot -Filter '*ObjectsMigration.sql' -File |
            Sort-Object Name)
    }
    catch {
        Write-Host "[Get-MigrationScripts] $($_.Exception.Message)" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace
        throw
    }
}

function Get-ScriptObjects {
    # 從腳本文字撈出它會建立的物件，回傳 [pscustomobject]@{ Type; Name }。
    param([Parameter(Mandatory = $true)][string]$Path)
    try {
        $text = Get-Content -Path $Path -Raw -Encoding UTF8
        $objects = @()

        # 注意：預存程序內部會 CREATE TABLE [dbo].[#SalesOrder] 這種暫存表，
        # 名稱要連 # 一起抓進來才有辦法在下面濾掉，不然 regex 會退回去把 schema 的
        # dbo 當成表名。
        $patterns = @(
            @{ Type = 'TABLE'; Regex = '(?im)^\s*CREATE\s+TABLE\s+(?:\[?\w+\]?\.)?\[?(#?\w+)\]?\s*\(' },
            @{ Type = 'PROCEDURE'; Regex = '(?im)^\s*CREATE\s+OR\s+ALTER\s+PROCEDURE\s+\[?dbo\]?\.\[?(\w+)\]?' },
            @{ Type = 'VIEW'; Regex = '(?im)^\s*CREATE\s+OR\s+ALTER\s+VIEW\s+\[?dbo\]?\.\[?(\w+)\]?' },
            @{ Type = 'FUNCTION'; Regex = '(?im)^\s*CREATE\s+OR\s+ALTER\s+FUNCTION\s+\[?dbo\]?\.\[?(\w+)\]?' }
        )

        foreach ($p in $patterns) {
            foreach ($m in [regex]::Matches($text, $p.Regex)) {
                $name = $m.Groups[1].Value
                if ($name.StartsWith('#')) { continue }  # SP 內部的暫存表，不是搬移目標
                $objects += [pscustomobject]@{ Type = $p.Type; Name = $name }
            }
        }

        # 腳本裡的 USE，用來跟連線字串的 Initial Catalog 對帳。
        $useMatch = [regex]::Match($text, '(?im)^\s*USE\s+\[?(\w+)\]?\s*;?\s*$')
        $useDb = if ($useMatch.Success) { $useMatch.Groups[1].Value } else { '' }

        return [pscustomobject]@{ Objects = $objects; UseDatabase = $useDb }
    }
    catch {
        Write-Host "[Get-ScriptObjects] $($_.Exception.Message)" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace
        throw
    }
}

function Invoke-SqlLines {
    # 對目標資料庫執行一段查詢，回傳非空白的輸出行。
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

function Test-LinkedServer {
    param([hashtable]$Target)
    $q = "SET NOCOUNT ON; SELECT CASE WHEN EXISTS (SELECT 1 FROM sys.servers WHERE name = N'$script:ErpLinkedServer') THEN 'YES' ELSE 'NO' END;"
    return ((Invoke-SqlLines -Target $Target -Query $q) -join '') -eq 'YES'
}

function Show-ObjectStatus {
    # 列出腳本會建立的物件在目標端現在是不是已經存在。
    param([hashtable]$Target, [array]$Objects)
    try {
        foreach ($o in $Objects) {
            $q = "SET NOCOUNT ON; SELECT CASE WHEN OBJECT_ID(N'dbo.$($o.Name)') IS NULL THEN 'ABSENT' ELSE 'EXISTS' END;"
            $state = (Invoke-SqlLines -Target $Target -Query $q) -join ''

            $extra = ''
            if ($o.Type -eq 'TABLE' -and $state -eq 'EXISTS') {
                $cnt = (Invoke-SqlLines -Target $Target -Query "SET NOCOUNT ON; SELECT COUNT(*) FROM dbo.$($o.Name);") -join ''
                $extra = "  (目前 $cnt 筆)"
            }

            $color = if ($state -eq 'EXISTS') { 'Yellow' } else { 'Gray' }
            Write-Host ("  {0,-10} {1,-28} {2}{3}" -f $o.Type, $o.Name, $state, $extra) -ForegroundColor $color
        }
    }
    catch {
        Write-Host "[Show-ObjectStatus] $($_.Exception.Message)" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace
        throw
    }
}

function Test-ScriptSyntax {
    # SET PARSEONLY ON 之後把整份腳本送進去，只驗語法、不執行也不解析物件名稱。
    # PARSEONLY 之下 USE 也不會執行，所以刻意連到 master，避免誤會自己真的切過庫。
    param([hashtable]$Target, [string]$Path)
    try {
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("parseonly_" + [guid]::NewGuid().ToString('N') + '.sql')
        $body = Get-Content -Path $Path -Raw -Encoding UTF8
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($tmp, "SET PARSEONLY ON`r`nGO`r`n" + $body, $utf8NoBom)

        & sqlcmd -S $Target.Server -U $Target.User -P $Target.Password -d master -C -b -f 65001 -i $tmp
        $code = $LASTEXITCODE
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue

        if ($code -ne 0) { throw "語法檢查失敗 (exit $code)" }
        return $true
    }
    catch {
        Write-Host "[Test-ScriptSyntax] $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

try {
    Assert-SqlCmd | Out-Null

    $all = Get-MigrationScripts
    if ($all.Count -eq 0) { throw "database/ 底下找不到任何 *ObjectsMigration.sql" }

    if ([string]::IsNullOrWhiteSpace($Script)) {
        Write-Host "可執行的搬移腳本：" -ForegroundColor Cyan
        foreach ($f in $all) { Write-Host "  $($f.Name)" }
        Write-Host ""
        Write-Host "用法： .\run-objects-migration.ps1 -Script <檔名> -Environment snapshot [-Execute]"
        return
    }

    $path = Join-Path $script:DbRoot $Script
    if (-not (Test-Path $path)) { throw "找不到腳本 $path" }

    $target = ConvertTo-SqlCmdArgs -ConnectionString (Get-ConnectionString -Environment $Environment)
    $info = Get-ScriptObjects -Path $path

    Write-Host "腳本  : $Script" -ForegroundColor Cyan
    Write-Host "目標  : $($target.Server) / $($target.Database)  [$Environment]" -ForegroundColor Cyan
    Write-Host ""

    # 1. 腳本裡的 USE 要跟連線字串的資料庫一致，否則會建到別的庫去。
    if ($info.UseDatabase -and $info.UseDatabase -ne $target.Database) {
        throw "腳本的 USE $($info.UseDatabase) 與目標資料庫 $($target.Database) 不一致，中止。"
    }

    # 2. linked server
    if (Test-LinkedServer -Target $target) {
        Write-Host "linked server [$script:ErpLinkedServer]：存在" -ForegroundColor Green
    }
    else {
        Write-Host "linked server [$script:ErpLinkedServer]：**不存在**" -ForegroundColor Red
        Write-Host "  腳本仍然建得起來（SQL Server 對跨伺服器參照是延後解析），但 View/SP 一執行就會失敗。" -ForegroundColor Yellow
        Write-Host "  linked server 是 instance 層級設定，請先在這個 instance 上建好再跑。" -ForegroundColor Yellow
    }
    Write-Host ""

    # 3. 物件現況
    Write-Host "這支腳本會建立的物件（$($info.Objects.Count) 個）：" -ForegroundColor Cyan
    Show-ObjectStatus -Target $target -Objects $info.Objects
    Write-Host ""
    Write-Host "  EXISTS 的物件會被覆寫（CREATE OR ALTER）；已經有資料的表不會被清空。" -ForegroundColor Gray
    Write-Host ""

    # 4. 語法檢查
    Write-Host "語法檢查（SET PARSEONLY ON）..." -ForegroundColor Cyan
    Test-ScriptSyntax -Target $target -Path $path | Out-Null
    Write-Host "語法檢查通過。" -ForegroundColor Green
    Write-Host ""

    if (-not $Execute) {
        Write-Host "dry-run 結束，沒有動任何東西。確認無誤後加 -Execute 真的執行。" -ForegroundColor Yellow
        return
    }

    Write-Host "執行中..." -ForegroundColor Cyan
    & sqlcmd -S $target.Server -U $target.User -P $target.Password -d $target.Database -C -b -f 65001 -i $path
    if ($LASTEXITCODE -ne 0) { throw "執行失敗 (exit $LASTEXITCODE)" }

    Write-Host ""
    Write-Host "執行完成，物件現況：" -ForegroundColor Green
    Show-ObjectStatus -Target $target -Objects $info.Objects
}
catch {
    Write-Host "[run-objects-migration] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace
    exit 1
}
