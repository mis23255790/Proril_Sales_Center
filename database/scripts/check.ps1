<#
.SYNOPSIS
    資料正確性檢查：跑 database/checks/*.sql，列出違規資料。

.DESCRIPTION
    純讀取，不會寫任何東西。每個 .sql 回傳「違規的列」，回 0 列代表通過。
    每列固定四欄：chk / severity / ident / detail。

    第一次跑通常會噴一堆 —— 老系統本來就有歷史髒資料。
    先用 -UpdateBaseline 建立基線，之後就只會看到「新產生的」問題。

.PARAMETER Environment
    test 或 prod，對應 database/.env 裡的 PRORIL_DB_TEST / PRORIL_DB_PROD。

.PARAMETER Sample
    每個檢查最多印幾筆明細，預設 5。用 -Sample 0 只看統計。

.PARAMETER Check
    只跑檔名含此關鍵字的檢查，例如 -Check consistency。

.PARAMETER UpdateBaseline
    把這次的結果寫進 database/checks/baseline.tsv 當成「已知髒資料」。
    baseline 要進版控，這樣才看得出來是誰、什麼時候把它擴大的。

.PARAMETER FailOnError
    有「新增的」ERROR 就 exit 1，給 CI 用。已在 baseline 裡的不算。

.EXAMPLE
    .\check.ps1
    .\check.ps1 -Environment prod -Sample 10
    .\check.ps1 -Check consistency
    .\check.ps1 -Environment prod -UpdateBaseline
#>
[CmdletBinding()]
param(
    [ValidateSet('test', 'prod')][string]$Environment = 'test',
    [int]$Sample = 5,
    [string]$Check = '',
    [switch]$UpdateBaseline,
    [switch]$FailOnError
)

. "$PSScriptRoot\_common.ps1"

$script:ChecksDir   = Join-Path $script:DbRoot 'checks'
$script:BaselineTsv = Join-Path $script:ChecksDir 'baseline.tsv'

function Invoke-CheckFile {
    <#
        跑一個 .sql，回傳 PSCustomObject 陣列。

        -f 65001 讓 sqlcmd 用 UTF-8 讀輸入檔也用 UTF-8 輸出，
        否則 .sql 裡的中文說明會被當成 CP950 讀成亂碼。
        搭配 Console::OutputEncoding 才接得回來。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][hashtable]$SqlArgs
    )
    try {
        $raw = & sqlcmd -S $SqlArgs.Server -U $SqlArgs.User -P $SqlArgs.Password -d $SqlArgs.Database `
                    -C -h -1 -W -s "`t" -f 65001 -i $Path
        if ($LASTEXITCODE -ne 0) {
            throw "sqlcmd 執行失敗 (exit $LASTEXITCODE)：$($raw -join ' ')"
        }

        $rows = @()
        foreach ($line in $raw) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            # sqlcmd 在 -h -1 之下仍可能吐 "(n rows affected)" 這類雜訊
            if ($line -match '^\(\d+ rows? affected\)$') { continue }

            $p = $line -split "`t"
            if ($p.Count -lt 4) { continue }

            $rows += [PSCustomObject]@{
                Check    = $p[0].Trim()
                Severity = $p[1].Trim()
                Ident    = $p[2].Trim()
                Detail   = ($p[3..($p.Count - 1)] -join ' ').Trim()
            }
        }
        return $rows
    }
    catch {
        Write-Host "[Invoke-CheckFile] $Path 失敗: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace
        throw
    }
}

function Get-Baseline {
    # 回傳 hashtable，key 是 "check`tident"
    try {
        $map = @{}
        if (-not (Test-Path $script:BaselineTsv)) { return $map }

        foreach ($line in (Get-Content $script:BaselineTsv -Encoding UTF8)) {
            $t = $line.Trim()
            if ($t -eq '' -or $t.StartsWith('#')) { continue }
            $map[$t] = $true
        }
        return $map
    }
    catch {
        Write-Host "[Get-Baseline] 讀取 baseline 失敗: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host $_.ScriptStackTrace
        return @{}
    }
}

try {
    Assert-SqlCmd | Out-Null

    # sqlcmd 以 UTF-8 輸出，PowerShell 這邊要跟著切，中文才不會變問號
    $prevEncoding = [Console]::OutputEncoding
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    $sqlArgs = ConvertTo-SqlCmdArgs -ConnectionString (Get-ConnectionString -Environment $Environment)

    $files = Get-ChildItem -Path $script:ChecksDir -Filter '*.sql' | Sort-Object Name
    if ($Check -ne '') {
        $files = $files | Where-Object { $_.Name -like "*$Check*" }
    }
    if (-not $files) { throw "在 $script:ChecksDir 找不到符合條件的 .sql" }

    Write-Host ""
    Write-Host "===== 資料正確性檢查 ($Environment / $($sqlArgs.Database)) =====" -ForegroundColor Cyan

    $all = @()
    foreach ($f in $files) {
        Write-Host "  跑 $($f.Name)..." -ForegroundColor DarkGray
        $all += Invoke-CheckFile -Path $f.FullName -SqlArgs $sqlArgs
    }

    if ($UpdateBaseline) {
        $lines = @("# 已知的歷史髒資料。由 check.ps1 -UpdateBaseline 產生，請進版控。",
                   "# 格式：<check>`t<ident>。之後 check.ps1 只會把不在這份清單裡的當成新問題。")
        $lines += ($all | ForEach-Object { "$($_.Check)`t$($_.Ident)" } | Sort-Object -Unique)
        Set-Content -Path $script:BaselineTsv -Value $lines -Encoding UTF8
        Write-Host ""
        Write-Host "已寫入基線 $script:BaselineTsv（$($all.Count) 筆）" -ForegroundColor Green
        [Console]::OutputEncoding = $prevEncoding
        exit 0
    }

    $baseline = Get-Baseline
    foreach ($r in $all) {
        $r | Add-Member -NotePropertyName IsKnown -NotePropertyValue $baseline.ContainsKey("$($r.Check)`t$($r.Ident)")
    }

    $fresh = @($all | Where-Object { -not $_.IsKnown })
    $known = @($all | Where-Object { $_.IsKnown })

    Write-Host ""
    if ($all.Count -eq 0) {
        Write-Host "全部通過，沒有任何違規。" -ForegroundColor Green
        [Console]::OutputEncoding = $prevEncoding
        exit 0
    }

    Write-Host "違規合計 $($all.Count) 筆（新增 $($fresh.Count)，已知 $($known.Count)）" -ForegroundColor Cyan
    if ($baseline.Count -eq 0) {
        Write-Host "尚未建立基線。第一次跑建議先看過內容，確認都是歷史資料後再執行 -UpdateBaseline。" -ForegroundColor Yellow
    }
    Write-Host ""

    $summary = $all | Group-Object Check | Sort-Object Name | ForEach-Object {
        [PSCustomObject]@{
            檢查項目 = $_.Name
            嚴重度   = ($_.Group | Select-Object -First 1).Severity
            合計     = $_.Count
            新增     = @($_.Group | Where-Object { -not $_.IsKnown }).Count
        }
    }
    $summary | Format-Table -AutoSize

    if ($Sample -gt 0) {
        # 新增的先印，那才是這次要處理的
        $ordered = @($fresh) + @($known)
        foreach ($g in ($ordered | Group-Object Check | Sort-Object Name)) {
            $sev = ($g.Group | Select-Object -First 1).Severity
            $color = 'Yellow'
            if ($sev -eq 'ERROR') { $color = 'Red' }

            Write-Host "[$sev] $($g.Name) —— $($g.Count) 筆" -ForegroundColor $color
            foreach ($row in ($g.Group | Select-Object -First $Sample)) {
                $tag = ''
                if ($row.IsKnown) { $tag = '(已知) ' }
                Write-Host "    $tag$($row.Ident)  $($row.Detail)"
            }
            if ($g.Count -gt $Sample) {
                Write-Host "    ... 另外還有 $($g.Count - $Sample) 筆（用 -Sample 調整）" -ForegroundColor DarkGray
            }
            Write-Host ""
        }
    }

    Write-Host "說明：各項檢查在做什麼、為什麼重要，看 database/checks/*.sql 的檔頭註解。" -ForegroundColor Cyan

    [Console]::OutputEncoding = $prevEncoding

    $freshErrors = @($fresh | Where-Object { $_.Severity -eq 'ERROR' }).Count
    if ($FailOnError -and $freshErrors -gt 0) {
        Write-Host "有 $freshErrors 筆新增的 ERROR。" -ForegroundColor Red
        exit 1
    }
    exit 0
}
catch {
    Write-Host "[check] 失敗: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace
    exit 1
}
