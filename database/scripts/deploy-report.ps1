<#
.SYNOPSIS
    產生「這次部署會對目標環境做哪些變更」的報告。不會修改任何東西。

.DESCRIPTION
    上線前的最後一道防線。一定要先看過這份報告再跑 publish.ps1。

.EXAMPLE
    .\deploy-report.ps1 -Environment prod
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

    Write-Host "建置 dacpac..." -ForegroundColor Cyan
    & dotnet build (Join-Path $dbRoot 'Proril.SalesIssue.Database.sqlproj') -c Release -v minimal
    if ($LASTEXITCODE -ne 0) { throw "dotnet build 失敗 (exit $LASTEXITCODE)" }

    $dacpac = Get-ChildItem -Path (Join-Path $dbRoot 'bin') -Recurse -Filter '*.dacpac' |
              Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($null -eq $dacpac) { throw "build 後找不到 dacpac" }

    $outDir = Join-Path $dbRoot '.tmp'
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
    $reportPath = Join-Path $outDir "deploy-report-$Environment.xml"

    Write-Host "比對 [$Environment]..." -ForegroundColor Cyan
    & $sqlPackage /Action:DeployReport `
        /SourceFile:"$($dacpac.FullName)" `
        /TargetConnectionString:"$conn" `
        /OutputPath:"$reportPath" `
        /p:BlockOnPossibleDataLoss=true `
        /p:DropObjectsNotInSource=false `
        /p:IgnorePermissions=true `
        /p:IgnoreUserSettingsObjects=true `
        /p:IgnoreLoginSids=true

    if ($LASTEXITCODE -ne 0) { throw "SqlPackage DeployReport 失敗 (exit $LASTEXITCODE)" }

    Write-Host ""
    Write-Host "===== 部署預覽 [$Environment] =====" -ForegroundColor Cyan

    [xml]$xml = Get-Content $reportPath -Encoding UTF8
    $ops = $xml.DeploymentReport.Operations.Operation

    if ($null -eq $ops) {
        Write-Host "沒有任何變更，目標環境已與 main 一致。" -ForegroundColor Green
    }
    else {
        foreach ($op in $ops) {
            $name = $op.Name
            $color = if ($name -match 'Drop') { 'Red' } elseif ($name -match 'Alter|Create') { 'Yellow' } else { 'Gray' }
            foreach ($item in $op.Item) {
                Write-Host ("  {0,-10} {1} {2}" -f $name, $item.Type, $item.Value) -ForegroundColor $color
            }
        }
    }

    $alerts = $xml.DeploymentReport.Alerts.Alert
    if ($null -ne $alerts) {
        Write-Host ""
        Write-Host "警示：" -ForegroundColor Red
        foreach ($a in $alerts) {
            Write-Host "  [$($a.Name)]" -ForegroundColor Red
            foreach ($issue in $a.Issue) { Write-Host "    $($issue.Value)" -ForegroundColor Red }
        }
    }

    Write-Host ""
    Write-Host "完整報告: $reportPath" -ForegroundColor Cyan
}
catch {
    Write-Host "[deploy-report] 失敗: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace
    exit 1
}
