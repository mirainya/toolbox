# ============================================================
# Claude Code 自定义状态栏脚本 (Windows PowerShell)
# ============================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$esc = [char]27
$reset = "$esc[0m"

# 读取 Claude Code 传入的 JSON 数据
$data = [Console]::In.ReadToEnd() | ConvertFrom-Json

# ── 路径处理 ────────────────────────────────────────────────
$fullPath = if ($data.cwd) { $data.cwd } else { (Get-Location).Path }
$fullPath = $fullPath -replace '/', '\'
$pathParts = $fullPath -split '\\'
$currentDir = if ($pathParts.Length -le 3) {
    $fullPath
} else {
    $drive = $pathParts[0]
    $last  = $pathParts[-1]
    $mid   = ($pathParts[1..($pathParts.Length-2)] | ForEach-Object { "$($_[0])~" }) -join '\'
    "$drive\$mid\$last"
}

# ── Git Branch ──────────────────────────────────────────────
$gitBranch = $null
try {
    $gitDir = $fullPath
    while ($gitDir) {
        $parent = Split-Path $gitDir -Parent
        if ($parent -eq $gitDir) { break }
        $headFile = "$gitDir\.git\HEAD"
        if ([System.IO.File]::Exists($headFile)) {
            $headContent = [System.IO.File]::ReadAllText($headFile)
            if ($headContent -match 'ref: refs/heads/(.+)') {
                $gitBranch = $matches[1].Trim()
            } else {
                $gitBranch = $headContent.Trim().Substring(0, [Math]::Min(7, $headContent.Trim().Length))
            }
            break
        }
        $gitDir = $parent
    }
} catch {}

# ── 工具调用统计 ─────────────────────────────────────────────
$toolTotal  = 0
$toolRounds = 0
$toolTop    = $null
try {
    $transcriptPath = $data.transcript_path
    if ($transcriptPath -and [System.IO.File]::Exists($transcriptPath)) {
        $toolCounts = @{}
        foreach ($line in [System.IO.File]::ReadAllLines($transcriptPath)) {
            try {
                $obj = $line | ConvertFrom-Json
                if ($obj.type -eq 'assistant' -and $obj.message.role -eq 'assistant') {
                    $roundHasTool = $false
                    foreach ($c in $obj.message.content) {
                        if ($c.type -eq 'tool_use') {
                            $roundHasTool = $true
                            $toolTotal++
                            $n = $c.name
                            if ($toolCounts.ContainsKey($n)) { $toolCounts[$n]++ } else { $toolCounts[$n] = 1 }
                        }
                    }
                    if ($roundHasTool) { $toolRounds++ }
                }
            } catch {}
        }
        if ($toolCounts.Count -gt 0) {
            $top = $toolCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1
            $toolTop = "$($top.Key):$($top.Value)"
        }
    }
} catch {}

# ── 数值提取 ────────────────────────────────────────────────
$pct    = [math]::Round($data.context_window.used_percentage, 1)
$inTk   = $data.context_window.total_input_tokens
$outTk  = $data.context_window.total_output_tokens
$maxTk  = if ($data.context_window.context_window_size) { $data.context_window.context_window_size } else { 200000 }
$cacheR = if ($data.context_window.current_usage.cache_read_input_tokens)     { $data.context_window.current_usage.cache_read_input_tokens }     else { 0 }

$rawCost    = if ($data.cost.total_cost_usd)        { $data.cost.total_cost_usd }        else { 0 }
$durationMs = if ($data.cost.total_duration_ms)     { $data.cost.total_duration_ms }     else { 0 }
$apiDurMs   = if ($data.cost.total_api_duration_ms) { $data.cost.total_api_duration_ms } else { 0 }
$linesAdded = if ($data.cost.total_lines_added)     { $data.cost.total_lines_added }     else { 0 }
$linesRem   = if ($data.cost.total_lines_removed)   { $data.cost.total_lines_removed }   else { 0 }

# ── 格式化函数 ──────────────────────────────────────────────
function K($n) { if ($n -ge 1000) { "$([math]::Round($n/1000.0,1))k" } else { "$n" } }

function FormatCost($c) {
    if ($c -lt 0.0001) { return '$0.00' }
    if ($c -lt 0.01)   { return "`$$([math]::Round($c, 4))" }
    return "`$$([math]::Round($c, 2))"
}

function FormatDuration($ms) {
    if ($ms -lt 60000) { return "$([math]::Round($ms/1000))s" }
    $min = [math]::Floor($ms / 60000)
    $sec = [math]::Round(($ms % 60000) / 1000)
    return "${min}m${sec}s"
}

function VisualLength($s) {
    ($s -replace '\x1b\[[0-9;]*m', '').Length
}

# ── 计算值 ──────────────────────────────────────────────────
$usedK    = K ([math]::Round($maxTk * $pct / 100))
$costStr  = FormatCost $rawCost
$durStr   = FormatDuration $durationMs
$apiPct   = if ($durationMs -gt 0) { [math]::Round($apiDurMs * 100 / $durationMs) } else { 0 }
$cacheHit = if ($inTk -gt 0) { [math]::Round($cacheR * 100 / $inTk) } else { 0 }
$toolStr  = if ($toolTop) { "${toolRounds}r/${toolTotal}c($toolTop)" } else { "${toolRounds}r/${toolTotal}c" }
$gitStr   = if ($gitBranch) { $gitBranch } else { [char]0x2014 }

# ── 颜色定义 ────────────────────────────────────────────────
$cModel  = "$esc[38;5;81m"
$cNum    = "$esc[38;5;153m"
$cCost   = "$esc[38;5;222m"
$cCache  = "$esc[38;5;183m"
$cDir    = "$esc[38;5;147m"
$cSep    = "$esc[38;5;240m"
$cGit    = "$esc[38;5;114m"
$cDur    = "$esc[38;5;245m"
$cLines  = "$esc[38;5;150m"
$cTool   = "$esc[38;5;216m"
$cPct    = if ($pct -gt 80) { "$esc[38;5;210m" } elseif ($pct -gt 50) { "$esc[38;5;221m" } else { "$esc[38;5;114m" }

# ── 图标 ────────────────────────────────────────────────────
$iModel  = [char]::ConvertFromUtf32(0x1F916)  # 🤖
$iCtx    = [char]::ConvertFromUtf32(0x1F4CA)  # 📊
$iToken  = [char]::ConvertFromUtf32(0x1F4AC)  # 💬
$iCache  = [char]::ConvertFromUtf32(0x1F3AF)  # 🎯
$iCost   = [char]::ConvertFromUtf32(0x1F4B0)  # 💰
$iGit    = [char]::ConvertFromUtf32(0x1F33F)  # 🌿
$iDur    = [char]::ConvertFromUtf32(0x23F1)   # ⏱
$iLines  = [char]::ConvertFromUtf32(0x270F)   # ✏
$iTool   = [char]::ConvertFromUtf32(0x1F527)  # 🔧
$iDir    = [char]::ConvertFromUtf32(0x1F4C1)  # 📁

# ── 组装两行 ────────────────────────────────────────────────
$sep = "$cSep | $reset"

# 第一行: 模型 | 上下文 | tokens | 缓存命中 | 费用
$row1Parts = @(
    "$cModel$iModel $($data.model.display_name)$reset",
    "$cPct$iCtx ${pct}% ($usedK/$(K $maxTk))$reset",
    "$cNum$iToken in:$(K $inTk) out:$(K $outTk)$reset",
    "$cCache$iCache hit:${cacheHit}%$reset",
    "$cCost$iCost $costStr$reset"
)
$line1 = $row1Parts -join $sep

# 第二行: 工具 | 改动 | 时长 | git | 目录
$nowStr = (Get-Date).ToString("HH:mm")
$row2Parts = @(
    "$cTool$iTool $toolStr$reset",
    "$cLines$iLines +$linesAdded -$linesRem$reset",
    "$cDur$iDur $durStr(API:${apiPct}%)$reset",
    "$cGit$iGit $gitStr$reset",
    "$cDir$iDir $currentDir$reset"
)
$line2 = $row2Parts -join $sep

Write-Output $line1
Write-Output $line2
