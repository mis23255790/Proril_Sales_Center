<#
.SYNOPSIS
    比對資料庫某張表的欄位，跟 api/Data 裡手寫的 EF Model 差在哪。

.DESCRIPTION
    回答「資料庫多了/少了/型別變了哪些欄位」，只列差異、不產生任何檔案、
    也不改動 api/Data 底下的任何程式碼 —— 新欄位要加進 Model，還是得自己動手，
    這支只是幫你先看清楚要加什麼，不用自己對著 SSMS 一個一個欄位核對。

    刻意不用 `dotnet ef dbcontext scaffold`：那支預設會整份覆蓋 DbContext /
    entity 檔案，把手動加的修正（型別修正、註解、欄位白名單）一起洗掉，
    而且需要額外裝 dotnet-ef 工具。這支改用 INFORMATION_SCHEMA.COLUMNS
    （跟 drift.ps1 同一招），只需要 sqlcmd。

    class 名稱怎麼找：預設從 api/Data/SalesIssueDbContext.cs 的
    `modelBuilder.Entity<T>(entity => { entity.ToTable("表名") ... })`
    反查對映的類別，並讀該區塊裡的 `HasColumnName(...)` 處理欄位改名
    （例如 DB 的 `WPNo` 對到 C# 屬性 `Wpno`）。如果這張表還沒被 EF Model
    收錄（找不到對映），用 -ClassName 手動指定要比對的類別。

.PARAMETER Table
    資料庫裡的實際表名，例如 D_WorkProcess。

.PARAMETER Environment
    要連哪個環境查欄位，test 或 prod，預設 test（新欄位通常先進測試區）。

.PARAMETER ClassName
    手動指定要比對的 C# 類別名稱。這張表還沒被 SalesIssueDbContext.cs
    收錄時才需要 —— 這支只負責「比對」，收錄仍要自己在 Entities.cs /
    SalesIssueDbContext.cs 補上最基本的 class + modelBuilder.Entity<T>() 區塊。

.EXAMPLE
    .\sync-model.ps1 -Table D_WorkProcess
    .\sync-model.ps1 -Table D_WorkProcessDetail -Environment prod
    .\sync-model.ps1 -Table M_NewTable -ClassName MNewTable
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Table,
    [ValidateSet('test', 'prod')][string]$Environment = 'test',
    [string]$ClassName
)

. "$PSScriptRoot\_common.ps1"

$script:ApiDataDir = Join-Path (Split-Path -Parent $script:DbRoot) 'api\Data'
$script:DbContextFile = Join-Path $script:ApiDataDir 'SalesIssueDbContext.cs'

# SQL 型別家族 -> 建議的 C# 型別，只用來給軟性提示，不是精確判斷
# （nvarchar/varchar 等長度、IsUnicode、money vs decimal 這種細節本來就該人工核對）。
$script:SqlToCsHint = @{
    'int'              = 'int'
    'bigint'           = 'long'
    'smallint'         = 'short'
    'tinyint'          = 'byte'
    'bit'              = 'bool'
    'decimal'          = 'decimal'
    'numeric'          = 'decimal'
    'money'            = 'decimal'
    'smallmoney'       = 'decimal'
    'float'            = 'double'
    'real'             = 'float'
    'datetime'         = 'DateTime'
    'datetime2'        = 'DateTime'
    'smalldatetime'    = 'DateTime'
    'date'             = 'DateTime'
    'uniqueidentifier' = 'Guid'
    'varchar'          = 'string'
    'nvarchar'         = 'string'
    'char'             = 'string'
    'nchar'            = 'string'
    'text'             = 'string'
    'ntext'            = 'string'
    'varbinary'        = 'byte[]'
    'binary'           = 'byte[]'
    'image'            = 'byte[]'
}

function Get-DbColumns {
    # 回傳 hashtable：欄位名(小寫) -> 欄位定義物件
    param(
        [Parameter(Mandatory = $true)][string]$ConnectionString,
        [Parameter(Mandatory = $true)][string]$Table
    )
    try {
        $a = ConvertTo-SqlCmdArgs -ConnectionString $ConnectionString
        $safeTable = $Table.Replace("'", "''")

        $query = @"
SET NOCOUNT ON;
SELECT c.COLUMN_NAME + CHAR(9) + c.DATA_TYPE + CHAR(9)
     + ISNULL(CAST(c.CHARACTER_MAXIMUM_LENGTH AS varchar(10)), '') + CHAR(9)
     + c.IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS c
WHERE c.TABLE_SCHEMA = 'dbo' AND c.TABLE_NAME = '$safeTable'
ORDER BY c.ORDINAL_POSITION;
"@

        $raw = & sqlcmd -S $a.Server -U $a.User -P $a.Password -d $a.Database `
                    -C -h -1 -W -s "`t" -Q $query
        if ($LASTEXITCODE -ne 0) { throw "sqlcmd 查詢失敗 (exit $LASTEXITCODE)" }

        $map = @{}
        foreach ($line in $raw) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $p = $line -split "`t"
            if ($p.Count -lt 4) { continue }

            $map[$p[0].Trim().ToLowerInvariant()] = [PSCustomObject]@{
                Column   = $p[0].Trim()
                Type     = $p[1].Trim()
                Length   = $p[2].Trim()
                Nullable = $p[3].Trim()
            }
        }
        return $map
    }
    catch {
        Write-Host "[Get-DbColumns] $($_.Exception.Message)" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace
        throw
    }
}

function Find-EntityMapping {
    # 在 SalesIssueDbContext.cs 找 ToTable("表名") 對到的 class 名稱與該區塊原始內容。
    param([Parameter(Mandatory = $true)][string]$Table)
    try {
        if (-not (Test-Path $script:DbContextFile)) {
            throw "找不到 $script:DbContextFile"
        }
        $text = Get-Content $script:DbContextFile -Raw -Encoding UTF8
        $opts = [System.Text.RegularExpressions.RegexOptions]::Singleline
        $pattern = 'modelBuilder\.Entity<(?<cls>\w+)>\(entity =>\s*\{(?<body>.*?)\r?\n\s*\}\);'

        foreach ($m in [regex]::Matches($text, $pattern, $opts)) {
            $body = $m.Groups['body'].Value
            if ($body -match [regex]::Escape('ToTable("' + $Table + '"')) {
                return [PSCustomObject]@{ ClassName = $m.Groups['cls'].Value; Body = $body }
            }
        }
        return $null
    }
    catch {
        Write-Host "[Find-EntityMapping] $($_.Exception.Message)" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace
        throw
    }
}

function Get-ColumnRenameMap {
    # 從 modelBuilder.Entity<T>() 區塊內容解析 HasColumnName，回傳 C# 屬性名 -> DB 欄位名。
    param([Parameter(Mandatory = $true)][string]$Body)
    $map = @{}
    $opts = [System.Text.RegularExpressions.RegexOptions]::Singleline
    $pattern = 'entity\.Property\(e => e\.(?<prop>\w+)\)(?:(?!;).)*?HasColumnName\("(?<col>[^"]+)"\)'
    foreach ($m in [regex]::Matches($Body, $pattern, $opts)) {
        $map[$m.Groups['prop'].Value] = $m.Groups['col'].Value
    }
    return $map
}

function Get-ClassProperties {
    # 在 api/Data/*.cs 找 class $ClassName 的定義，回傳 (檔案路徑, 屬性名 -> C# 型別)。
    param([Parameter(Mandatory = $true)][string]$ClassName)
    try {
        $opts = [System.Text.RegularExpressions.RegexOptions]::Singleline
        foreach ($file in Get-ChildItem $script:ApiDataDir -Filter '*.cs') {
            $text = Get-Content $file.FullName -Raw -Encoding UTF8
            $classPattern = "class\s+$ClassName\b[^\{]*\{(?<body>.*?)\r?\n\}"
            $cm = [regex]::Match($text, $classPattern, $opts)
            if (-not $cm.Success) { continue }

            $props = [ordered]@{}
            $propPattern = 'public\s+([\w<>\?\[\],\s]+?)\s+(\w+)\s*\{\s*get;\s*set;\s*\}'
            foreach ($pm in [regex]::Matches($cm.Groups['body'].Value, $propPattern)) {
                $props[$pm.Groups[2].Value] = ($pm.Groups[1].Value -replace '\s+', ' ').Trim()
            }
            return [PSCustomObject]@{ File = $file.FullName; Properties = $props }
        }
        return $null
    }
    catch {
        Write-Host "[Get-ClassProperties] $($_.Exception.Message)" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace
        throw
    }
}

function Get-TypeHint {
    param([string]$SqlType)
    $key = $SqlType.ToLowerInvariant()
    if ($script:SqlToCsHint.ContainsKey($key)) { return $script:SqlToCsHint[$key] }
    return $null
}

try {
    Assert-SqlCmd | Out-Null

    Write-Host "讀取 $Environment 環境的 $Table 欄位..." -ForegroundColor Cyan
    $cs = Get-ConnectionString -Environment $Environment
    $dbCols = Get-DbColumns -ConnectionString $cs -Table $Table

    if ($dbCols.Count -eq 0) {
        throw "$Environment 環境查不到表 [$Table] 的任何欄位，表名或大小寫可能不對。"
    }

    $renameMap = @{}
    if ($ClassName) {
        Write-Host "手動指定類別 $ClassName，不從 SalesIssueDbContext.cs 反查欄位改名對映。" -ForegroundColor Yellow
    }
    else {
        $mapping = Find-EntityMapping -Table $Table
        if (-not $mapping) {
            throw @"
在 $script:DbContextFile 找不到 ToTable("$Table") 的對映，這張表可能還沒被納入 EF Model。
請先在 api/Data/Entities.cs 加一個最基本的 class、在 SalesIssueDbContext.cs
加一段 modelBuilder.Entity<T>(entity => { entity.ToTable("$Table"); ... })，
或改用 -ClassName 手動指定要比對的既有類別。
"@
        }
        $ClassName = $mapping.ClassName
        $renameMap = Get-ColumnRenameMap -Body $mapping.Body
    }

    $classInfo = Get-ClassProperties -ClassName $ClassName
    if (-not $classInfo) {
        throw "在 api/Data/*.cs 找不到 class $ClassName 的定義。"
    }

    # C# 屬性名 -> 實際對映的 DB 欄位名（沒特別 HasColumnName 就視為同名）
    $propToCol = @{}
    foreach ($prop in $classInfo.Properties.Keys) {
        $propToCol[$prop] = if ($renameMap.ContainsKey($prop)) { $renameMap[$prop] } else { $prop }
    }

    # DB 欄位名(小寫) -> 對到的 C# 屬性名
    $colToProp = @{}
    foreach ($prop in $propToCol.Keys) {
        $colToProp[$propToCol[$prop].ToLowerInvariant()] = $prop
    }

    $missingInModel = @()   # 資料庫有、Model 沒有
    $matched = @()          # 兩邊都有，型別可能不同
    foreach ($key in $dbCols.Keys) {
        if ($colToProp.ContainsKey($key)) {
            $matched += [PSCustomObject]@{ Db = $dbCols[$key]; Prop = $colToProp[$key] }
        }
        else {
            $missingInModel += $dbCols[$key]
        }
    }

    $extraInModel = $classInfo.Properties.Keys | Where-Object {
        -not $dbCols.ContainsKey($propToCol[$_].ToLowerInvariant())
    }

    Write-Host ""
    Write-Host "===== $Table  <->  $ClassName（$($classInfo.File)） =====" -ForegroundColor Cyan
    Write-Host "資料庫 $($dbCols.Count) 欄，Model $($classInfo.Properties.Count) 個屬性。"
    Write-Host ""

    if ($missingInModel.Count -eq 0 -and $extraInModel.Count -eq 0) {
        Write-Host "欄位名稱兩邊一致，沒有新增/缺少的欄位。" -ForegroundColor Green
    }

    if ($missingInModel.Count -gt 0) {
        Write-Host "[資料庫有、Model 沒有] 要手動加進 $ClassName：" -ForegroundColor Yellow
        foreach ($c in ($missingInModel | Sort-Object Column)) {
            $hint = Get-TypeHint $c.Type
            $csType = if ($hint) { $hint } else { '/* 未知型別對照，自行判斷 */ object' }
            $nullableMark = if ($c.Nullable -eq 'YES' -and $csType -notin @('string', 'byte[]')) { '?' } else { '' }
            $lenNote = if ($c.Length -ne '') { "($($c.Length))" } else { '' }

            # 只把首字母大寫，不用 ToTitleCase —— 那個會把 zipFile 這種字中間的大寫壓平成 Zipfile。
            $suggestedProp = $c.Column.Substring(0, 1).ToUpperInvariant() + $c.Column.Substring(1)

            Write-Host ("  + {0,-30} {1}{2} {3}" -f $c.Column, $c.Type, $lenNote, $(if ($c.Nullable -eq 'YES') { 'NULL' } else { 'NOT NULL' })) -ForegroundColor Yellow
            Write-Host ("      建議屬性: public $csType$nullableMark $suggestedProp { get; set; }") -ForegroundColor DarkYellow
            Write-Host ("      對映: entity.Property(e => e.___).HasColumnName(`"$($c.Column)`")" + $(if ($c.Length -ne '') { ".HasMaxLength($($c.Length))" } else { '' })) -ForegroundColor DarkYellow
        }
        Write-Host ""
    }

    if ($extraInModel.Count -gt 0) {
        Write-Host "[Model 有、資料庫沒有] 欄位可能被改名或刪除，要查：" -ForegroundColor Red
        foreach ($prop in ($extraInModel | Sort-Object)) {
            Write-Host "  - $prop  (對映欄位名: $($propToCol[$prop]))" -ForegroundColor Red
        }
        Write-Host ""
    }

    $typeMismatch = $matched | Where-Object {
        $hint = Get-TypeHint $_.Db.Type
        $hint -and ($_.Prop -and $classInfo.Properties[$_.Prop] -notlike "*$hint*")
    }
    if ($typeMismatch.Count -gt 0) {
        Write-Host "[型別可能不合] 純字串比對的軟性提示，請自行核對是否為刻意修正（如 decimal/float）：" -ForegroundColor Magenta
        foreach ($t in $typeMismatch) {
            Write-Host ("  ~ {0,-20} DB: {1,-12} Model: {2} ({3})" -f $t.Db.Column, $t.Db.Type, $classInfo.Properties[$t.Prop], $t.Prop) -ForegroundColor Magenta
        }
        Write-Host ""
    }

    Write-Host "提醒：這支只列差異，新增/修改屬性跟 SalesIssueDbContext.cs 的 fluent 對映仍要自己動手加。" -ForegroundColor Cyan
    exit 0
}
catch {
    Write-Host "[sync-model] 失敗: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace
    exit 1
}
