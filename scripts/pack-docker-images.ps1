<#
.SYNOPSIS
    本機 build 好 app/api 兩個 image，存成 tar 檔，方便用 AnyDesk 之類的工具傳到
    目標主機（dev 或 prod）。

.DESCRIPTION
    build 一律用 docker-compose.yml 這份有 build context 的檔案，build 出來的
    image 名稱固定是 proril-sales-center-{api,app}-dev.proril（docker-compose.yml
    的 image: 就是這樣寫的）。

    -Env prod 時，build 完會再 docker tag 成 proril-sales-center-{api,app}-prod.proril
    （對應 docker-compose.prod.yml 的 image: 命名），存的 tar 檔名也跟著換，
    dev 版的 image 不會被覆蓋。

    預設兩個都重建/重存；只有一邊改了程式碼，用 -Service 只處理那一邊，
    省得每次都要重傳整包。

.PARAMETER Service
    要處理哪個 service：app、api、或 all（預設 all）。

.PARAMETER Env
    要包成哪個環境的 image：dev 或 prod（預設 dev）。只影響 tag 名稱與 tar 檔名，
    build 本身沒有差異。

.PARAMETER OutDir
    tar 檔輸出目錄，預設 ./docker-images（不進版控）。

.EXAMPLE
    .\scripts\pack-docker-images.ps1
    .\scripts\pack-docker-images.ps1 -Service app
    .\scripts\pack-docker-images.ps1 -Env prod
    .\scripts\pack-docker-images.ps1 -Env prod -Service api
#>
[CmdletBinding()]
param(
    [ValidateSet('app', 'api', 'all')][string]$Service = 'all',
    [ValidateSet('dev', 'prod')][string]$Env = 'dev',
    [string]$OutDir = "$PSScriptRoot\..\docker-images"
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot

# service key -> docker-compose.yml 裡 image: 指定的名稱（build 出來一定是這個）
$BuildImageNames = @{
    api = 'proril-sales-center-api-dev.proril'
    app = 'proril-sales-center-app-dev.proril'
}

# service key -> docker-compose.prod.yml 對應的正式版名稱，-Env prod 才會用到
$ProdImageNames = @{
    api = 'proril-sales-center-api-prod.proril'
    app = 'proril-sales-center-app-prod.proril'
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
        $buildImage = $BuildImageNames[$svc]
        $image = if ($Env -eq 'prod') { $ProdImageNames[$svc] } else { $buildImage }

        if ($Env -eq 'prod') {
            Write-Host "tag: $buildImage -> $image" -ForegroundColor Cyan
            docker tag $buildImage $image
            if ($LASTEXITCODE -ne 0) { throw "docker tag 失敗：$buildImage -> $image" }
        }

        $tarPath = Join-Path $OutDir "$image.tar"
        Write-Host "save: $tarPath" -ForegroundColor Cyan
        docker save -o $tarPath $image
        if ($LASTEXITCODE -ne 0) { throw "docker save 失敗：$image" }

        $size = [math]::Round((Get-Item $tarPath).Length / 1MB, 1)
        Write-Host "完成 $image.tar（${size} MB）" -ForegroundColor Green
    }

    $composeFile = if ($Env -eq 'prod') { 'docker-compose.prod.yml' } else { 'docker-compose.yml' }
    $targetDir = if ($Env -eq 'prod') { 'D:\proril-sales-center-prod.proril\' } else { 'D:\proril-sales-center-dev.proril\' }

    Write-Host ""
    Write-Host "傳到遠端主機（例如透過 AnyDesk 檔案傳輸），放到" -ForegroundColor Cyan
    Write-Host "$targetDir 底下任意位置，再依序執行：" -ForegroundColor Cyan
    foreach ($svc in $services) {
        $image = if ($Env -eq 'prod') { $ProdImageNames[$svc] } else { $BuildImageNames[$svc] }
        Write-Host "  docker load -i $image.tar" -ForegroundColor Cyan
    }
    Write-Host "  docker compose -f $composeFile up -d --force-recreate" -ForegroundColor Cyan
    exit 0
}
catch {
    Write-Host "[pack-docker-images] 失敗: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace
    exit 1
}
