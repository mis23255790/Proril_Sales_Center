<#
.SYNOPSIS
    本機 build 好 app/api 兩個 image，存成 tar 檔，方便用 AnyDesk 之類的工具傳到
    D:\proril-sales-center-dev.proril\ 那台主機。

.DESCRIPTION
    docker-compose.yml 的 app/api 服務都已經用 image: 指定跟遠端 docker-compose.yml
    一致的名稱（proril-sales-center-app-dev.proril / proril-sales-center-api-dev.proril），
    docker compose build 出來就是這個名字，不需要再另外 tag。

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

# service key -> docker-compose.yml 裡 image: 指定的名稱
$ImageNames = @{
    api = 'proril-sales-center-api-dev.proril'
    app = 'proril-sales-center-app-dev.proril'
}

$services = @(if ($Service -eq 'all') { 'api', 'app' } else { $Service })

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
        $image = $ImageNames[$svc]

        $tarPath = Join-Path $OutDir "$image.tar"
        Write-Host "save: $tarPath" -ForegroundColor Cyan
        docker save -o $tarPath $image
        if ($LASTEXITCODE -ne 0) { throw "docker save 失敗：$image" }

        $size = [math]::Round((Get-Item $tarPath).Length / 1MB, 1)
        Write-Host "完成 $image.tar（${size} MB）" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "傳到遠端主機（例如透過 AnyDesk 檔案傳輸），放到" -ForegroundColor Cyan
    Write-Host "D:\proril-sales-center-dev.proril\ 底下任意位置，再依序執行：" -ForegroundColor Cyan
    foreach ($svc in $services) {
        Write-Host "  docker load -i $($ImageNames[$svc]).tar" -ForegroundColor Cyan
    }
    Write-Host "  docker compose up -d --force-recreate" -ForegroundColor Cyan
    exit 0
}
catch {
    Write-Host "[pack-docker-images] 失敗: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace
    exit 1
}
