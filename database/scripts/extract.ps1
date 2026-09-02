<#
.SYNOPSIS
    從指定環境擷取白名單資料表的 schema，寫進 database/Tables/。

.DESCRIPTION
    預設從 prod 擷取 —— main branch 的 schema 定義上就等於正式區。
    從 test 擷取只在「要把測試區既有的未上線欄位收編進某個 feature branch」時才用，
    而且擷取完一定要人工 review diff，把不屬於這個 feature 的欄位拿掉。

.EXAMPLE
    .\extract.ps1
    .\extract.ps1 -Environment test
#>
[CmdletBinding()]
param(
    [ValidateSet('test', 'prod')][string]$Environment = 'prod'
)

. "$PSScriptRoot\_common.ps1"

try {
    $sqlPackage = Assert-SqlPackage
    $dbRoot     = Split-Path -Parent $PSScriptRoot
    $conn       = Get-ConnectionString -Environment $Environment
    $tables     = Get-ManagedTables

    $tmpDir     = Join-Path $dbRoot '.tmp\extract'
    $tablesDir  = Join-Path $dbRoot 'Tables'

    if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force }
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
    if (-not (Test-Path $tablesDir)) { New-Item -ItemType Directory -Path $tablesDir -Force | Out-Null }

    Write-Host "從 [$Environment] 擷取 schema..." -ForegroundColor Cyan

    # 只要結構，不要任何資料列。
    & $sqlPackage /Action:Extract `
        /SourceConnectionString:"$conn" `
        /TargetFile:"$tmpDir" `
        /p:ExtractTarget=ObjectType `
        /p:ExtractAllTableData=false `
        /p:IgnorePermissions=true `
        /p:IgnoreUserLoginMappings=true `
        /p:VerifyExtraction=false

    if ($LASTEXITCODE -ne 0) { throw "SqlPackage Extract 失敗 (exit $LASTEXITCODE)" }

    # 只把白名單的表搬進 Tables/，其他一律丟棄。
    $copied  = @()
    $missing = @()

    foreach ($t in $tables) {
        $hit = Get-ChildItem -Path $tmpDir -Recurse -Filter '*.sql' |
               Where-Object { $_.BaseName -eq $t -or $_.BaseName -eq "dbo.$t" } |
               Select-Object -First 1

        if ($null -eq $hit) { $missing += $t; continue }

        Copy-Item $hit.FullName (Join-Path $tablesDir "$t.sql") -Force
        $copied += $t
    }

    # 清掉白名單以外的殘留（例如白名單刪掉某張表之後）
    Get-ChildItem -Path $tablesDir -Filter '*.sql' |
        Where-Object { $tables -notcontains $_.BaseName } |
        ForEach-Object {
            Write-Host "  移除已不在白名單的 $($_.Name)" -ForegroundColor Yellow
            Remove-Item $_.FullName -Force
        }

    Remove-Item (Join-Path $dbRoot '.tmp') -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "擷取完成：$($copied.Count) 張表 -> database/Tables/" -ForegroundColor Green
    $copied | ForEach-Object { Write-Host "  + $_" }

    if ($missing.Count -gt 0) {
        Write-Host ""
        Write-Host "警告：下列表在 [$Environment] 找不到，白名單可能過期：" -ForegroundColor Yellow
        $missing | ForEach-Object { Write-Host "  ! $_" -ForegroundColor Yellow }
    }

    # ModelCollation 對不對，直接讓使用者看到實際值
    $sqlArgs = ConvertTo-SqlCmdArgs -ConnectionString $conn
    $sqlcmdPath = Get-Command sqlcmd -ErrorAction SilentlyContinue
    if ($sqlcmdPath) {
        $collation = & sqlcmd -S $sqlArgs.Server -U $sqlArgs.User -P $sqlArgs.Password -d $sqlArgs.Database `
                        -C -h -1 -W -Q "SET NOCOUNT ON; SELECT CONVERT(varchar(128), DATABASEPROPERTYEX(DB_NAME(),'Collation'));"
        Write-Host ""
        Write-Host "[$Environment] 資料庫定序: $($collation | Select-Object -First 1)" -ForegroundColor Cyan
        Write-Host "請確認 .sqlproj 的 <ModelCollation> 與其一致（CS = case sensitive）。"
    }

    Write-Host ""
    Write-Host "下一步：git diff database/Tables/ 檢查有沒有混進不該進來的欄位。" -ForegroundColor Cyan
}
catch {
    Write-Host "[extract] 失敗: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace
    exit 1
}
