<#
.SYNOPSIS
    把 database/Tables/ 的 schema 實際部署到目標環境。

.DESCRIPTION
    預設是 dry-run（等同 deploy-report），要加 -Execute 才會真的動 DB。
    對 prod 另外要求互動式輸入資料庫名稱確認，避免手殘。

    永遠帶著這兩個保護，不要拿掉：
      BlockOnPossibleDataLoss=true   會造成資料遺失的變更直接中止
      DropObjectsNotInSource=false   目標環境多出來的物件不會被砍掉

.EXAMPLE
    .\publish.ps1 -Environment test
    .\publish.ps1 -Environment test -Execute
    .\publish.ps1 -Environment prod -Execute
#>
[CmdletBinding()]
param(
    [ValidateSet('test', 'prod')][string]$Environment = 'test',
    [switch]$Execute
)

. "$PSScriptRoot\_common.ps1"

try {
    if (-not $Execute) {
        Write-Host "dry-run 模式：只產生部署預覽，不會修改資料庫。" -ForegroundColor Cyan
        Write-Host "確認無誤後加上 -Execute 才會真的部署。" -ForegroundColor Cyan
        Write-Host ""
        & "$PSScriptRoot\deploy-report.ps1" -Environment $Environment
        exit $LASTEXITCODE
    }

    $sqlPackage = Assert-SqlPackage
    $dbRoot     = Split-Path -Parent $PSScriptRoot
    $conn       = Get-ConnectionString -Environment $Environment
    $target     = ConvertTo-SqlCmdArgs -ConnectionString $conn

    # 先讓人看過會改什麼
    Write-Host "先產生部署預覽..." -ForegroundColor Cyan
    & "$PSScriptRoot\deploy-report.ps1" -Environment $Environment
    if ($LASTEXITCODE -ne 0) { throw "部署預覽失敗，已中止，不執行部署。" }

    Write-Host ""
    if ($Environment -eq 'prod') {
        Write-Host "即將部署到【正式區】$($target.Server) / $($target.Database)" -ForegroundColor Red
        $answer = Read-Host "請輸入目標資料庫名稱以確認 ($($target.Database))"
        if ($answer -ne $target.Database) {
            Write-Host "輸入不符，已取消。" -ForegroundColor Yellow
            exit 1
        }
    }
    else {
        Write-Host "即將部署到【測試區】$($target.Server) / $($target.Database)" -ForegroundColor Yellow
        $answer = Read-Host "確定執行？(yes/no)"
        if ($answer -ne 'yes') {
            Write-Host "已取消。" -ForegroundColor Yellow
            exit 1
        }
    }

    $dacpac = Get-ChildItem -Path (Join-Path $dbRoot 'bin') -Recurse -Filter '*.dacpac' |
              Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($null -eq $dacpac) { throw "找不到 dacpac，請先跑 deploy-report.ps1 或 dotnet build" }

    Write-Host "部署中..." -ForegroundColor Cyan
    & $sqlPackage /Action:Publish `
        /SourceFile:"$($dacpac.FullName)" `
        /TargetConnectionString:"$conn" `
        /p:BlockOnPossibleDataLoss=true `
        /p:DropObjectsNotInSource=false `
        /p:IgnorePermissions=true `
        /p:IgnoreUserSettingsObjects=true `
        /p:IgnoreLoginSids=true `
        /p:GenerateSmartDefaults=false

    if ($LASTEXITCODE -ne 0) { throw "SqlPackage Publish 失敗 (exit $LASTEXITCODE)" }

    Write-Host ""
    Write-Host "部署完成 -> $($target.Server) / $($target.Database)" -ForegroundColor Green
    Write-Host "建議接著跑 .\drift.ps1 確認兩邊狀態。" -ForegroundColor Cyan
}
catch {
    Write-Host "[publish] 失敗: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace
    exit 1
}
