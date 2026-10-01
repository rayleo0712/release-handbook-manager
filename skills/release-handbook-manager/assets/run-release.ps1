﻿<#
.SYNOPSIS  Release SQL runner + verifier + report generator (version-agnostic)

.DESCRIPTION
  Runs all 02-db-*.sql and 03-config-*.sql in its OWN directory (the version
  directory) in filename order, waits a few seconds after each, parses the
  verification output for PASS/FAIL, generates JSON + Markdown + log reports.
  The version label is auto-detected from the directory name, so this file is
  copied verbatim into every release/versions/{version}/ folder with zero edits.

.USAGE
  powershell -ExecutionPolicy Bypass -File run-release.ps1
  powershell -ExecutionPolicy Bypass -File run-release.ps1 -DbHost 10.0.0.1 -User myuser -Password xxx -Database mydb
  powershell -ExecutionPolicy Bypass -File run-release.ps1 -ResetFirst
  powershell -ExecutionPolicy Bypass -File run-release.ps1 -StartIndex 5 -EndIndex 15
  powershell -ExecutionPolicy Bypass -File run-release.ps1 -ListOnly          # 只做命名/依赖硬预检并打印执行计划，不连库
  powershell -ExecutionPolicy Bypass -File run-release.ps1 -StopOnError       # 任一脚本失败立即中止，保护依赖链

.ORDER CONTRACT
  Execution order is hard-bound to the filename sort: 02-db-NNN-* then 03-config-NNN-*,
  NNN is a fixed-width 3-digit number unique within its prefix. Cross-file prerequisites
  must be declared with "-- @depends <02-db-001>" lines.

.SINGLE-CHANNEL CONTRACT
  The version directory contains ONLY scripts required for the production release, and
  EVERY executable script MUST carry a verification block (check_result/fail_count).
  There is NO skip/blacklist mechanism: no-check scripts, "-- @test-only" test scripts and
  000 placeholders containing real statements all fail preflight. Rules:
  scripts-sql-规范.md section 4.4 (order) and 4.5 (single channel). Preflight aborts with
  exit code 2 before any SQL runs. Executed scripts are reported PASS or FAIL only.
#>

param(
  [string]$ScriptDir    = "$PSScriptRoot",   # 脚本所在目录 = 版本目录，默认即批量执行范围
  [string]$DbHost       = "localhost",       # 数据库主机，允许带 http(s):// 前缀（会自动清洗）
  [int]   $Port         = 3306,              # 数据库端口
  [string]$User         = "root",            # 数据库用户
  [string]$Password     = "",                # 数据库密码，建议执行时通过参数传入而非固化在文件里
  [string]$Database     = "mydb",             # 目标数据库名
  [int]   $IntervalSec  = 5,                 # 每个脚本执行后的间隔秒数
  [switch]$ResetFirst,                       # 是否先 DROP+CREATE 库（需二次确认）
  [int]   $StartIndex   = -1,                # 区间执行起始下标（-1 = 从头）
  [int]   $EndIndex     = -1,                # 区间执行结束下标（-1 = 到尾）
  [switch]$ListOnly,                         # 仅做命名/依赖硬预检并打印执行计划，不执行任何 SQL（巡检/CI 用）
  [switch]$StopOnError                       # 任一脚本执行或校验失败立即中止，不再继续后续脚本（依赖链保护）
)

$ErrorActionPreference = "Stop"
$script:StartTime = Get-Date

# Force UTF-8 encoding for PowerShell process and all child processes.
# On Windows default code page 936, MySQL outputs GBK bytes which PS 5 misreads as ?? garbage.
# Setting OutputEncoding + Console.OutputEncoding + chcp 65001 in child shells ensures UTF-8 round-trip.
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8

# Sanitize DbHost: strip http:// https:// prefix and trailing slash
$rawHost = $DbHost
$script:DbHost = ($rawHost -replace '^https?://', '') -replace '/+$', ''

if ($script:DbHost -ne $rawHost) {
  Write-Host "[INFO] DbHost sanitized: '$rawHost' -> '$($script:DbHost)'"
}

# 版本号自动取所在目录名（release/versions/{version}/ -> {version}），
# 保证同一份脚本可以原样复制进任何版本目录而无需手工改版本字符串。
$script:Version = Split-Path $ScriptDir -Leaf

$script:LogFile    = Join-Path $ScriptDir "run-report.log"
$script:JsonReport = Join-Path $ScriptDir "run-report.json"
$script:MdReport   = Join-Path $ScriptDir "run-report.md"

if (Test-Path $script:LogFile) { Remove-Item $script:LogFile -Force }

# 统一以 UTF-8（无 BOM）写日志/报告。PS 5.1 的 Add-Content/Out-Content 默认按系统 ANSI(GBK)
# 落盘，用 UTF-8 打开时中文文件名和 mysql 中文校验输出会变成乱码，这里固定编码避免歧义。
$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Step {
  param([string]$Msg, [string]$Level = "INFO")
  $ts = Get-Date -Format "HH:mm:ss"
  $prefix = switch ($Level) {
    "PASS" { "[OK]" }
    "FAIL" { "[XX]" }
    "WARN" { "[!!]" }
    "SKIP" { "[--]" }
    default { "[  ]" }
  }
  $line = "$ts $prefix $Msg"
  Write-Host $line
  # 用 .NET 以 UTF-8 无 BOM 追加，保证中文在日志文件中不乱码（PS5 Add-Content 默认 GBK）。
  [System.IO.File]::AppendAllText($script:LogFile, "$line`r`n", $script:Utf8NoBom)
}

function Invoke-MySqlRaw {
  param([string]$Sql)
  # Use cmd.exe wrapper: chcp 65001 forces MySQL to output UTF-8 on Windows
  # (otherwise MySQL follows console code page 936 and Chinese becomes ??).
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = "cmd.exe"
  $psi.Arguments = "/c chcp 65001 >nul && mysql -h $script:DbHost -P $Port -u $User --password=$Password -D $Database --default-character-set=utf8mb4 --connect-timeout=10 --batch --raw -e `"$Sql`""
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  # chcp 65001 + utf8mb4 下子进程输出为 UTF-8 字节，显式按 UTF-8 解码，
  # 避免 PS5 重定向时默认按系统 ANSI(GBK) 解码导致中文输出乱码。
  $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
  $psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8
  try {
    $proc = [System.Diagnostics.Process]::Start($psi)
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    $output = ($stdout.TrimEnd() + "`n" + $stderr.TrimEnd()).Trim()
    if ($proc.ExitCode -ne 0) {
      return @{ Ok = $false; Output = $output; ExitCode = $proc.ExitCode }
    }
    return @{ Ok = $true; Output = $output; ExitCode = 0 }
  } catch {
    return @{ Ok = $false; Output = $_.Exception.Message; ExitCode = -1 }
  }
}

function Invoke-MySqlFile {
  param([string]$FilePath)
  $sqlContent = Get-Content $FilePath -Raw -Encoding UTF8
  # cmd.exe wrapper ensures chcp 65001 before mysql starts, so Chinese output stays UTF-8.
  # RedirectStandardInput still feeds directly to the child process stdin (cmd.exe),
  # which passes it through to mysql's stdin automatically.
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = "cmd.exe"
  $psi.Arguments = "/c chcp 65001 >nul && mysql -h $script:DbHost -P $Port -u $User --password=$Password -D $Database --default-character-set=utf8mb4 --connect-timeout=10 --batch --raw"
  $psi.RedirectStandardInput  = $true
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  # chcp 65001 + utf8mb4 下子进程输出为 UTF-8 字节，显式按 UTF-8 解码，
  # 避免 PS5 重定向时默认按系统 ANSI(GBK) 解码导致中文输出乱码。
  $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
  $psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8
  try {
    $proc = [System.Diagnostics.Process]::Start($psi)
    # Give cmd+mysql a moment to establish connection before writing SQL
    Start-Sleep -Milliseconds 300
    if ($proc.HasExited) {
      $stderr = $proc.StandardError.ReadToEnd()
      return @{ Ok = $false; Output = $stderr.Trim(); ExitCode = $proc.ExitCode }
    }
    $proc.StandardInput.Write($sqlContent)
    $proc.StandardInput.Close()
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    $output = ($stdout.TrimEnd() + "`n" + $stderr.TrimEnd()).Trim()
    if ($proc.ExitCode -ne 0) {
      return @{ Ok = $false; Output = $output; ExitCode = $proc.ExitCode }
    }
    return @{ Ok = $true; Output = $output; ExitCode = 0 }
  } catch {
    return @{ Ok = $false; Output = $_.Exception.Message; ExitCode = -1 }
  }
}

Write-Step "============================================================"
Write-Step "$($script:Version) Release SQL Runner"
Write-Step "DB: $script:DbHost`:$Port/$Database"
Write-Step "Dir: $ScriptDir"
Write-Step "Interval: ${IntervalSec}s"
Write-Step "============================================================"

# ===== 单一通道 + 文件名即执行序：收集 + 硬预检（任何 SQL 执行之前必须先通过）=====
# 本 runner 没有黑名单/skip 机制：版本目录只放生产发布必须执行的脚本（规范 §4.5）。
# 发布前人工备份等运维动作不属于发布变更，按人工操作登记（01 §5 / 04 §8），不得放 SQL 进目录。
# 命名正则：前缀-3 位定宽序号-简述.sql；定宽序号保证字典序 == 数值序（杜绝 1,10,2 错乱）
$strictNameRx  = '^(02-db|03-config)-(\d{3})-.+\.sql$'
# 000 为保留占位号（如 02-db-000-本版暂无数据库脚本.sql），runner 永不执行，且只允许含注释
$placeholderRx = '^(02-db|03-config)-000(-.+)?\.sql$'
# 依赖声明标记：-- @depends <token>；token 写完整 BaseName 或「前缀-NNN」简写，空格/逗号可分隔多个
$dependsRx     = '(?m)^\s*--\s*@depends\s+(.+?)\s*$'
# 测试专用标记：版本目录（生产发布通道）中出现即违例；测试/造数脚本归 rta 的 scripts/test-auto/
$testOnlyRx    = '(?im)^\s*--\s*@(?:test-only|env\s*:\s*test)\b'
# 校验区标记：每个可执行脚本必须存在（对应 §4.1 尾部【执行后校验SQL】）
$checkMarkerRx = 'check_result|fail_count'

# 1) 收集所有命中两大前缀的候选
$candidateSqls = @(Get-ChildItem -Path $ScriptDir -Filter "*.sql" |
  Where-Object { $_.Name -match '^(02-db|03-config)-' } |
  Sort-Object Name)

# 2) 000 占位文件隔离：仅用于「本版暂无脚本」占位，永不执行
$placeholderSqls = @($candidateSqls | Where-Object { $_.Name -match $placeholderRx })
$nonPlaceholder  = @($candidateSqls | Where-Object { $_.Name -notmatch $placeholderRx })
if ($placeholderSqls) {
  Write-Step "Placeholder 000 scripts (never executed): $($placeholderSqls.Name -join ', ')" "SKIP"
}

# 3) 正式执行清单 = 全部非 000 候选，严格按文件名升序（文件名排序是唯一执行顺序真源）
$allSqls = @($nonPlaceholder | Sort-Object Name)
Write-Step "Found $($allSqls.Count) executable SQL scripts (single channel: every one runs and must verify)"

# 去除 SQL 注释后是否仍有可执行文本（仅用于校验 000 占位文件必须为空；不追求完整词法解析）
function Get-HasExecutableText {
  param([string]$Sql)
  $noBlock = [regex]::Replace($Sql, '(?s)/\*.*?\*/', ' ')   # 去块注释
  $kept = foreach ($line in ($noBlock -split "`r?`n")) {
    $l = $line
    $d = $l.IndexOf('--'); if ($d -ge 0) { $l = $l.Substring(0, $d) }  # 去 -- 行注释
    $h = $l.IndexOf('#');  if ($h -ge 0) { $l = $l.Substring(0, $h) }  # 去 # 行注释
    $l.Trim()
  }
  return (($kept -join "`n") -replace '[\s;]','').Length -gt 0
}

# ---------- 硬预检：违例则一条 SQL 都不执行 ----------
$preflightErrors = @()   # 全部致命违例收集于此
$planEdges       = @()   # 依赖边（owner -> target BaseName），仅用于执行计划打印

# (a) 命名合规：所有非占位文件都必须满足 前缀-NNN-简述.sql
foreach ($f in $nonPlaceholder) {
  if ($f.Name -notmatch $strictNameRx) {
    $preflightErrors += "命名不合规: '$($f.Name)'；要求 02-db-NNN-简述.sql / 03-config-NNN-简述.sql（NNN=001~999 三位定宽，禁止 1 位/4 位序号、禁止缺简述）"
  }
}

# (b) 序号唯一：同前缀 NNN 不得重复——重号会让先后顺序落到中文简述的字符排序上
$numberedFiles = @()
foreach ($f in $nonPlaceholder) {
  if ($f.Name -match $strictNameRx) {
    $numberedFiles += [pscustomobject]@{ SeqKey = "$($Matches[1])-$($Matches[2])"; File = $f }
  }
}
foreach ($g in @($numberedFiles | Group-Object SeqKey | Where-Object { $_.Count -gt 1 })) {
  $dupNames = ($g.Group | ForEach-Object { $_.File.Name }) -join '、'
  $preflightErrors += "序号重复: '$($g.Name)' 被多个文件共用（$dupNames）；同前缀 NNN 必须全局唯一"
}

# (b2) 000 占位文件只能含注释；检出任何可执行语句即违例（防止真脚本被 000 号静默吞掉）
foreach ($f in $placeholderSqls) {
  $txt = Get-Content $f.FullName -Raw -Encoding UTF8
  if (Get-HasExecutableText -Sql $txt) {
    $preflightErrors += "占位文件含可执行语句: '$($f.Name)'；000 仅作「本版暂无脚本」空占位，真实脚本必须使用 001~999 序号"
  }
}

# (c) 排序下标映射：BaseName -> 下标（依赖先后判定的基准）
$indexByBase = @{}
for ($i = 0; $i -lt $allSqls.Count; $i++) { $indexByBase[$allSqls[$i].BaseName] = $i }

# 依赖目标解析：先按完整 BaseName 精确匹配，再按「前缀-NNN」简写前缀匹配；找不到返回 $null
function Resolve-DepTarget {
  param([string]$Token)
  $key = ($Token.Trim()) -replace '\.sql$',''
  $pool = @($allSqls + $placeholderSqls | Sort-Object Name -Unique)
  $hit = @($pool | Where-Object { $_.BaseName -eq $key })
  if ($hit.Count -eq 1) { return $hit[0] }
  if ($key -match '^(02-db|03-config)-\d{3}$') {
    $hit = @($pool | Where-Object { $_.BaseName -like "$key-*" })
    if ($hit.Count -ge 1) { return $hit[0] }
  }
  return $null
}

# (d) 逐文件扫描：@depends 依赖合法性 + 单一通道（校验区必备、测试专用禁止）
for ($i = 0; $i -lt $allSqls.Count; $i++) {
  $owner = $allSqls[$i]
  $sqlText = Get-Content $owner.FullName -Raw -Encoding UTF8
  $edgeTargets = @()
  foreach ($m in [regex]::Matches($sqlText, $dependsRx)) {
    $tokens = $m.Groups[1].Value -split '[\s,，;；]+' | Where-Object { $_ }
    foreach ($tok in $tokens) {
      $target = Resolve-DepTarget -Token $tok
      if ($null -eq $target) {
        $preflightErrors += "依赖缺失: '$($owner.Name)' 声明 @depends '$tok'，但目录中找不到对应脚本"
        continue
      }
      $edgeTargets += $target.BaseName
      if ($placeholderSqls.BaseName -contains $target.BaseName) {
        $preflightErrors += "非法依赖: '$($owner.Name)' 依赖 000 占位文件 '$($target.Name)'（占位文件不产生任何变更）"
      } elseif ($indexByBase.ContainsKey($target.BaseName) -and $indexByBase[$target.BaseName] -ge $i) {
        # 硬保证核心：被依赖脚本排序下标必须严格更小，即文件名排序保证它天然先执行
        $preflightErrors += "依赖倒序: '$($owner.Name)'（位 $i）依赖 '$($target.Name)'（位 $($indexByBase[$target.BaseName])）；前置脚本序号必须更小，需按 §4.4 重编号"
      }
    }
  }
  if ($edgeTargets.Count -gt 0) {
    $planEdges += [pscustomobject]@{ Owner = $owner.BaseName; Targets = @($edgeTargets | Select-Object -Unique) }
  }
  # 单一通道①：测试专用/造数脚本禁止进版本目录（应放 rta 的 scripts/test-auto/）
  if ($sqlText -match $testOnlyRx) {
    $preflightErrors += "测试专用脚本不得进版本目录: '$($owner.Name)' 含 @test-only/@env:test 标记；测试/造数/基线恢复脚本归属 rta 的 scripts/test-auto/（§4.5）"
  }
  # 单一通道②：每个生产执行脚本必须有校验区，执行结果必须可判定（禁止「跑了但不知道成没成」）
  if ($sqlText -notmatch $checkMarkerRx) {
    $preflightErrors += "缺少校验区: '$($owner.Name)' 不含 check_result/fail_count 校验标记；每个生产执行脚本必须按 §4.1 带尾部【执行后校验SQL】"
  }
}

# 打印执行计划（即使预检失败也打印，便于人工对照修正）
Write-Step "Execution plan (order = Sort-Object Name; NNN is the hard order key):"
for ($i = 0; $i -lt $allSqls.Count; $i++) {
  $edge = @($planEdges | Where-Object { $_.Owner -eq $allSqls[$i].BaseName })
  $depSuffix = if ($edge.Count -gt 0) { "    <- @depends: $($edge[0].Targets -join ', ')" } else { "" }
  Write-Step ("  [{0,2}] {1}{2}" -f $i, $allSqls[$i].Name, $depSuffix)
}

if ($preflightErrors.Count -gt 0) {
  Write-Step "PREFLIGHT FAILED ($($preflightErrors.Count) violation(s)) - NO SQL will be executed:" "FAIL"
  foreach ($e in $preflightErrors) { Write-Step "  $e" "FAIL" }
  exit 2
}
Write-Step "Preflight passed: naming / unique NNN / @depends order / every script has check block / no test-only file" "PASS"

$runList = @()
if ($StartIndex -ge 0 -or $EndIndex -ge 0) {
  $s = if ($StartIndex -ge 0) { $StartIndex } else { 0 }
  $e = if ($EndIndex -ge 0)   { $EndIndex }   else { $allSqls.Count - 1 }
  for ($i = $s; $i -le $e -and $i -lt $allSqls.Count; $i++) {
    $runList += $allSqls[$i]
  }
  Write-Step "Range: index $s ~ $e, actual $($runList.Count) scripts"
  # 区间补跑：区间内脚本依赖了区间外前置脚本时只告警（假定人工已先执行），不阻断
  $rangeBaseNames = @($runList | ForEach-Object { $_.BaseName })
  foreach ($edge in $planEdges) {
    if ($rangeBaseNames -contains $edge.Owner) {
      foreach ($t in $edge.Targets) {
        if ($indexByBase.ContainsKey($t) -and ($rangeBaseNames -notcontains $t)) {
          Write-Step "Range warning: '$($edge.Owner)' depends on '$t' OUTSIDE the range; make sure it has already been applied" "WARN"
        }
      }
    }
  }
} else {
  $runList = $allSqls
}

# -ListOnly：只做命名/依赖硬预检并打印计划，不连库、不执行（巡检/CI 用）
if ($ListOnly) {
  Write-Step "ListOnly: preflight and plan finished, no SQL executed." "SKIP"
  exit 0
}

# Reset db (optional)
if ($ResetFirst) {
  Write-Step "DB reset requested" "WARN"
  $confirm = Read-Host "Confirm DROP+CREATE database [$Database] ? (y/N)"
  if ($confirm -eq "y") {
    $resetSql = "DROP DATABASE IF EXISTS ``$Database``; CREATE DATABASE ``$Database`` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    $result = Invoke-MySqlRaw -Sql $resetSql
    if ($result.Ok) {
      Write-Step "DB reset done" "PASS"
    } else {
      Write-Step "DB reset FAILED: $($result.Output)" "FAIL"
      exit 1
    }
  } else {
    Write-Step "DB reset skipped by user" "SKIP"
  }
} else {
  Write-Step "DB reset skipped (default)" "SKIP"
}

# Run each script
$results   = @()
$totalPass = 0
$totalFail = 0
$totalSkip = 0

foreach ($sqlFile in $runList) {
  $scriptName = $sqlFile.Name
  Write-Step ""
  Write-Step ">>> $scriptName"

  $content = Get-Content $sqlFile.FullName -Raw -Encoding UTF8
  # Check block: script has verification SQL at the end.
  # Use ASCII-only marker to avoid PowerShell 5.1 encoding issues with Chinese.
  # All check scripts contain either check_result column or tmp_ check table.
  $hasCheckBlock = ($content -match 'check_result') -or ($content -match 'tmp_.*check_result') -or ($content -match 'fail_count')

  $stepStart = Get-Date
  $execResult = Invoke-MySqlFile -FilePath $sqlFile.FullName
  $execDur = (Get-Date) - $stepStart

  $item = [ordered]@{
    ScriptName  = $scriptName
    ExecOk      = $execResult.Ok
    ExitCode    = $execResult.ExitCode
    DurationSec = [math]::Round($execDur.TotalSeconds, 2)
    HasCheck    = $hasCheckBlock
    CheckResult = ""
    CheckLines  = @()
    ErrorMsg    = ""
  }

  if (-not $execResult.Ok) {
    Write-Step "EXEC FAILED (exit=$($execResult.ExitCode))" "FAIL"
    $snippet = $execResult.Output.Substring(0, [math]::Min(400, $execResult.Output.Length))
    Write-Step "Snippet: $snippet" "FAIL"
    $item.CheckResult = "EXEC_FAIL"
    $item.ErrorMsg = $execResult.Output.Substring(0, [math]::Min(600, $execResult.Output.Length))
    $totalFail++
  }
  elseif ($hasCheckBlock) {
    # Parse check output. Three patterns all need to be handled:
    #   A) check_result column with PASS/FAIL per row -> count keywords
    #   B) total_count / success_count / fail_count summary row -> extract numbers
    #   C) scattered pass_count/fail_count in multiple result tables -> sum ALL rows
    $checkOut = $execResult.Output
    $lines = $checkOut -split "`n"
    $checkLines = @()
    $inTable = $false

    # Extract table rows (skip header rows with column names)
    foreach ($line in $lines) {
      $trimmed = $line.Trim()
      if ($trimmed -match 'check_result' -or $trimmed -match 'success_count' -or $trimmed -match 'check_name') {
        $inTable = $true
        # Header row itself is not a data row, skip adding to checkLines
        continue
      }
      if ($inTable -and $trimmed -ne "") {
        $checkLines += $trimmed
      }
      if ($inTable -and $trimmed -eq "" -and $checkLines.Count -gt 0) {
        break
      }
    }
    $item.CheckLines = $checkLines

    # --- Parse strategy: try all patterns, aggregate ---
    $checkPass = 0
    $checkFail = 0

    # Pattern A: scan checkLines for PASS/FAIL keywords
    foreach ($cl in $checkLines) {
      if ($cl -match '\bPASS\b') { $checkPass++ }
      if ($cl -match '\bFAIL\b') { $checkFail++ }
    }

    # Pattern B: extract single summary row success_count/fail_count
    if ($checkPass -eq 0 -and $checkFail -eq 0) {
      foreach ($cl in $checkLines) {
        if ($cl -match 'success_count\s+(\d+)') { $checkPass = [int]$Matches[1] }
        if ($cl -match 'fail_count\s+(\d+)')     { $checkFail = [int]$Matches[1] }
      }
    }

    # Pattern C: scattered pass_count/fail_count in tab-separated tables
    # Scripts like 008/009/010 output multiple small tables each with:
    #   item\tpass_count\tfail_count   (header row, may appear multiple times)
    #   xxx\t1\t0                       (data row)
    # mysql --batch outputs tab-separated, so data rows NEVER contain word "fail_count"
    # - we must detect header presence, then sum last column of every data row.
    if ($checkFail -eq 0 -and $checkPass -eq 0) {
      $hasTableHeader = ($lines | Where-Object { $_ -match '\bfail_count\b' -and $_ -notmatch 'mysql:' }).Count -gt 0
      if ($hasTableHeader) {
        foreach ($line in $lines) {
          # Skip header rows, mysql warnings, and blank lines
          if ($line -match '\bfail_count\b') { continue }
          if ($line -match 'mysql:|\[Warning\]') { continue }
          if ($line.Trim() -eq "") { continue }
          # Split by tab, take the last column
          $cols = $line -split "`t"
          if ($cols.Count -ge 2) {
            $lastCol = $cols[-1].Trim()
            if ($lastCol -match '^\d+$') {
              $checkFail += [int]$lastCol
            }
          }
        }
        # If we found table headers but fail_count column is all 0s, still count as PASS
        if ($checkFail -eq 0) {
          # Each header + data pair = 1 check item. Count data rows as pass count.
          $checkPass = ($lines | Where-Object {
            if ($_ -match '\bfail_count\b') { return $false }
            if ($_ -match 'mysql:|\[Warning\]') { return $false }
            if ($_.Trim() -eq "") { return $false }
            $cols = $_ -split "`t"
            return ($cols.Count -ge 2 -and $cols[-1].Trim() -match '^\d+$')
          }).Count
        }
      }
    }

    # Fail-closed：三种模式都解析不出明确反馈（含校验区零输出）时一律判 FAIL。
    # 单一通道原则下「执行了但无法确认结果」不算通过；脚本须按 §4.1 输出显式
    # PASS/FAIL 或 success_count/fail_count 汇总行，让每个执行的脚本都有可判定反馈。
    if ($checkFail -gt 0) {
      Write-Step "CHECK FAIL: pass=$checkPass fail=$checkFail" "FAIL"
      foreach ($cl in $checkLines) { Write-Step "  $cl" "FAIL" }
      $item.CheckResult = "FAIL"
      $totalFail++
    } elseif ($checkPass -gt 0 -and $checkFail -eq 0) {
      Write-Step "CHECK PASS: $checkPass items" "PASS"
      $item.CheckResult = "PASS"
      $totalPass++
    } else {
      Write-Step "NO verifiable feedback from check output - fail-closed" "FAIL"
      $raw = $checkOut.Substring(0, [math]::Min(400, $checkOut.Length))
      Write-Step "Raw: $raw" "FAIL"
      $item.CheckResult = "FAIL"
      $item.ErrorMsg = "校验输出无法解析出 PASS/FAIL（fail-closed）；须输出显式校验结果"
      $totalFail++
    }
  } else {
    # 防御性分支：预检已保证每个可执行脚本含校验区，走到这里说明预检被绕过/文件被中途改动
    Write-Step "EXEC OK but no check block despite preflight - fail-closed" "FAIL"
    $item.CheckResult = "FAIL"
    $item.ErrorMsg = "缺少校验区却进入执行（预检应已拦截），按失败处理"
    $totalFail++
  }

  $results += [pscustomobject]$item

  # -StopOnError：依赖链保护，任一脚本失败立即中止，避免后续脚本踩在失败的前置上级联出错
  if ($StopOnError -and ($item.CheckResult -eq "FAIL" -or $item.CheckResult -eq "EXEC_FAIL")) {
    Write-Step "StopOnError: abort remaining $($runList.Count - ($results.Count)) script(s)" "FAIL"
    break
  }

  if ($sqlFile -ne $runList[-1]) {
    Write-Step "Wait ${IntervalSec}s..." "SKIP"
    Start-Sleep -Seconds $IntervalSec
  }
}

# Report
$total = $results.Count
$elapsed = (Get-Date) - $script:StartTime

Write-Step ""
Write-Step "============================================================"
Write-Step "DONE! Total=$total  Time=$([math]::Round($elapsed.TotalSeconds,1))s"
Write-Step "PASS=$totalPass  FAIL=$totalFail  (single channel: no skipped scripts)"
Write-Step "============================================================"

# JSON
# 注意：对象变量名不能用 $jsonReport——PS 变量名大小写不敏感，会与上面的文件路径
# $script:JsonReport 冲突并覆盖它，导致 -FilePath 拿到的是字典对象而非路径。
$jsonPayload = [ordered]@{
  Version    = $script:Version
  ScriptDir  = $ScriptDir
  Database   = "$script:DbHost`:$Port/$Database"
  StartTime  = $script:StartTime.ToString("yyyy-MM-dd HH:mm:ss")
  EndTime    = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  ElapsedSec = [math]::Round($elapsed.TotalSeconds, 1)
  Summary    = [ordered]@{ Total = $total; Pass = $totalPass; Fail = $totalFail; Skip = $totalSkip }
  Details    = $results
}
[System.IO.File]::WriteAllText($script:JsonReport, ($jsonPayload | ConvertTo-Json -Depth 6), $script:Utf8NoBom)
Write-Step "JSON report: $script:JsonReport"

# Markdown
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("# $($script:Version) Release SQL Runner Report")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Info")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| Item | Value |")
[void]$sb.AppendLine("|:---|:---|")
[void]$sb.AppendLine("| Version | $($script:Version) |")
[void]$sb.AppendLine("| DB | $script:DbHost`:$Port/$Database |")
[void]$sb.AppendLine("| Start | $($script:StartTime.ToString('yyyy-MM-dd HH:mm:ss')) |")
[void]$sb.AppendLine("| End | $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) |")
[void]$sb.AppendLine("| Elapsed | $([math]::Round($elapsed.TotalSeconds,1))s |")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Summary")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| Metric | Count |")
[void]$sb.AppendLine("|:---|:---|")
[void]$sb.AppendLine("| Total | $total |")
[void]$sb.AppendLine("| PASS | $totalPass |")
[void]$sb.AppendLine("| FAIL | $totalFail |")
[void]$sb.AppendLine("| SKIP | 0（单一通道：无跳过脚本，000 占位不计入） |")
[void]$sb.AppendLine("")

if ($totalFail -gt 0) {
  [void]$sb.AppendLine("## FAILURES")
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("| # | Script | Result | Error |")
  [void]$sb.AppendLine("|:---|:---|:---|:---|")
  $i = 0
  foreach ($r in $results) {
    $i++
    if ($r.CheckResult -eq "FAIL" -or $r.CheckResult -eq "EXEC_FAIL") {
      $err = if ($r.ErrorMsg) { $r.ErrorMsg.Substring(0, [math]::Min(120, $r.ErrorMsg.Length)) } else { "" }
      [void]$sb.AppendLine("| $i | $($r.ScriptName) | $($r.CheckResult) | $err |")
    }
  }
  [void]$sb.AppendLine("")
}

[void]$sb.AppendLine("## Details")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| # | Script | Exec | Check | Time(s) | Note |")
[void]$sb.AppendLine("|:---|:---|:---|:---|:---|:---|")
$i = 0
foreach ($r in $results) {
  $i++
  $ex = if ($r.ExecOk) { "OK" } else { "FAIL" }
  $ck = $r.CheckResult
  $note = if (-not $r.ExecOk) { "exit=$($r.ExitCode)" } elseif ($r.CheckLines.Count -gt 0) { "$($r.CheckLines.Count) lines" } else { "" }
  [void]$sb.AppendLine("| $i | $($r.ScriptName) | $ex | $ck | $($r.DurationSec) | $note |")
}
[void]$sb.AppendLine("")

[System.IO.File]::WriteAllText($script:MdReport, $sb.ToString(), $script:Utf8NoBom)
Write-Step "MD report: $script:MdReport"
Write-Step "Full log: $script:LogFile"
Write-Step ""
Write-Step "=== DONE ==="

# 非零退出码供 CI / 发布流水线判定：有任何执行或校验失败即 exit 1（预检违例 exit 2）
if ($totalFail -gt 0) { exit 1 }
