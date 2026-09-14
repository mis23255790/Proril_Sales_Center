<#
.SYNOPSIS
    本機 build 好 app/api 兩個 image，改成遠端 docker-compose.yml 認得的名字，
    存成 tar 檔，方便用 AnyDesk 之類的工具傳到 D:\intranet-sales-center-dev.proril\ 那台主機。

.DESCRIPTION
    對應遠端那份 docker-compose.yml：
        web-server: image: intranet-sales-center-api-dev.proril
        app:        image: intranet-sales-center-app-dev.proril
    本機 docker compose build 出來的名字是 intranet_sales_center-api / intranet_sales_center-app
    （跟著 docker-compose.yml 的 name: intranet_sales_center 走），兩邊對不起來，
    docker load 過去之後遠端 compose 會找不到 image——這支負責重新 tag 成正確名字再存檔。

    預設兩個都重建/重存；只有一邊改了程式碼，用 -Service 只處理那一邊，
    省得每次都要重傳整包。

.PARAMETER Service
    要處理哪個 service：app、api、或 all（預設 all）。

.PARAMETER OutDir
    tar 檔輸出目錄，預設 ./docker-images（不進版控）。

.EXAMPLE
    .\scripts\pack-docker-images.ps1
    .\scripts\pack-docker-images.ps1 -Service app
#>
[CmdletBinding()]
param(
    [ValidateSet('app', 'api', 'all')][string]$Service = 'all',
    [string]$OutDir = "$PSScriptRoot\..\docker-images"
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot

# service key -> (本機 build 出來的 image, 遠端 compose 要的 image 名稱)
$Targets = @{
    api = @{ Local = 'intranet_sales_center-api'; Remote = 'intranet-sales-center-api-dev.proril' }
    app = @{ Local = 'intranet_sales_center-app'; Remote = 'intranet-sales-center-app-dev.proril' }
}

$services = if ($Service -eq 'all') { @('api', 'app') } else { @($Service) }

try {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw "找不到 docker，請先安裝/啟動 Docker Desktop。"
    }
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

    Write-Host "build: $($services -join ', ')" -ForegroundColor Cyan
    Push-Location $RepoRoot
    try {
        docker compose build @services
        if ($LASTEXITCODE -ne 0) { throw "docker compose build 失敗 (exit $LASTEXITCODE)" }
    }
    finally {
        Pop-Location
    }

    foreach ($svc in $services) {
        $t = $Targets[$svc]

        Write-Host "tag: $($t.Local) -> $($t.Remote)" -ForegroundColor Cyan
        docker tag $t.Local $t.Remote
        if ($LASTEXITCODE -ne 0) { throw "docker tag 失敗：$($t.Local)" }

        $tarPath = Join-Path $OutDir "$($t.Remote).tar"
        Write-Host "save: $tarPath" -ForegroundColor Cyan
        docker save -o $tarPath $t.Remote
        if ($LASTEXITCODE -ne 0) { throw "docker save 失敗：$($t.Remote)" }

        $size = [math]::Round((Get-Item $tarPath).Length / 1MB, 1)
        Write-Host "完成 $($t.Remote).tar（${size} MB）" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "傳到遠端主機（例如透過 AnyDesk 檔案傳輸），放到" -ForegroundColor Cyan
    Write-Host "D:\intranet-sales-center-dev.proril\ 底下任意位置，再依序執行：" -ForegroundColor Cyan
    foreach ($svc in $services) {
        Write-Host "  docker load -i $($Targets[$svc].Remote).tar" -ForegroundColor Cyan
    }
    Write-Host "  docker compose up -d" -ForegroundColor Cyan
    exit 0
}
catch {
    Write-Host "[pack-docker-images] 失敗: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace
    exit 1
}
