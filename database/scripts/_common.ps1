# 共用：環境變數載入、連線字串解析、工具檢查。
# 各 script 用 . "$PSScriptRoot\_common.ps1" 載入。

$ErrorActionPreference = 'Stop'

$script:DbRoot = Split-Path -Parent $PSScriptRoot

function Import-DotEnv {
    # 讀 database/.env（不進版控），把 KEY=VALUE 灌進 process 環境變數。
    # 已存在的環境變數優先，CI 上可用 CI/CD variable 覆蓋。
    try {
        $envFile = Join-Path $script:DbRoot '.env'
        if (-not (Test-Path $envFile)) { return }

        foreach ($line in (Get-Content $envFile -Encoding UTF8)) {
            $t = $line.Trim()
            if ($t -eq '' -or $t.StartsWith('#')) { continue }

            $idx = $t.IndexOf('=')
            if ($idx -lt 1) { continue }

            $key = $t.Substring(0, $idx).Trim()
            $val = $t.Substring($idx + 1).Trim().Trim('"')

            if (-not [string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($key))) { continue }
            [Environment]::SetEnvironmentVariable($key, $val)
        }
    }
    catch {
        Write-Host "[Import-DotEnv] 讀取 .env 失敗: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host $_.ScriptStackTrace
    }
}

function Get-ConnectionString {
    # $Environment: 'test' | 'prod'
    param([Parameter(Mandatory = $true)][ValidateSet('test', 'prod')][string]$Environment)
    try {
        Import-DotEnv

        $varName = if ($Environment -eq 'prod') { 'PRORIL_DB_PROD' } else { 'PRORIL_DB_TEST' }
        $cs = [Environment]::GetEnvironmentVariable($varName)

        if ([string]::IsNullOrWhiteSpace($cs)) {
            throw "環境變數 $varName 未設定。請複製 database/.env.example 為 database/.env 後填入，或在 CI 設成 masked variable。"
        }
        return $cs
    }
    catch {
        Write-Host "[Get-ConnectionString] $($_.Exception.Message)" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace
        throw
    }
}

function ConvertTo-SqlCmdArgs {
    # 把 ADO.NET 連線字串拆成 sqlcmd 需要的參數。回傳 hashtable。
    param([Parameter(Mandatory = $true)][string]$ConnectionString)
    try {
        $b = New-Object System.Data.SqlClient.SqlConnectionStringBuilder $ConnectionString
        return @{
            Server   = $b.DataSource
            Database = $b.InitialCatalog
            User     = $b.UserID
            Password = $b.Password
        }
    }
    catch {
        Write-Host "[ConvertTo-SqlCmdArgs] 連線字串解析失敗: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace
        throw
    }
}

function Get-ManagedTables {
    # 讀 TABLES.txt 白名單，回傳表名陣列。
    try {
        $file = Join-Path $script:DbRoot 'TABLES.txt'
        if (-not (Test-Path $file)) { throw "找不到白名單 $file" }

        return Get-Content $file -Encoding UTF8 |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -ne '' -and -not $_.StartsWith('#') }
    }
    catch {
        Write-Host "[Get-ManagedTables] $($_.Exception.Message)" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace
        throw
    }
}

function Assert-SqlPackage {
    # 確認 SqlPackage 可用，回傳可執行檔路徑。
    try {
        $cmd = Get-Command sqlpackage -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }

        throw "找不到 sqlpackage。請先安裝：dotnet tool install -g microsoft.sqlpackage"
    }
    catch {
        Write-Host "[Assert-SqlPackage] $($_.Exception.Message)" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace
        throw
    }
}

function Assert-SqlCmd {
    try {
        $cmd = Get-Command sqlcmd -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }

        throw "找不到 sqlcmd。請安裝 SQL Server Command Line Utilities，或改用 SqlPackage 版的 drift 比對。"
    }
    catch {
        Write-Host "[Assert-SqlCmd] $($_.Exception.Message)" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace
        throw
    }
}
