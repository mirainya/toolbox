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

# ── 工具调用统计 + Transcript 解析 ──────────────────────────
$toolTotal  = 0
$toolRounds = 0
$toolTop    = $null
$lastAssistantTime = $null
$runningAgents = @()
$totalAgents = 0
$completedAgents = 0
$todos = @()
try {
    $transcriptPath = $data.transcript_path
    if ($transcriptPath -and [System.IO.File]::Exists($transcriptPath)) {
        $toolCounts = @{}
        $agentCalls = @{}  # id -> {name, desc, startTime}
        $todoState = @{}   # id -> {subject, status}
        $todoCounter = 0
        foreach ($line in [System.IO.File]::ReadAllLines($transcriptPath)) {
            try {
                $obj = $line | ConvertFrom-Json
                # 记录 assistant 消息时间戳
                if ($obj.type -eq 'assistant' -and $obj.timestamp) {
                    $lastAssistantTime = [DateTimeOffset]::Parse($obj.timestamp).UtcDateTime
                }
                if ($obj.type -eq 'assistant' -and $obj.message.role -eq 'assistant') {
                    $roundHasTool = $false
                    foreach ($c in $obj.message.content) {
                        if ($c.type -eq 'tool_use') {
                            $roundHasTool = $true
                            $toolTotal++
                            $n = $c.name
                            if ($toolCounts.ContainsKey($n)) { $toolCounts[$n]++ } else { $toolCounts[$n] = 1 }
                            # Agent 追踪
                            if ($n -eq 'Agent' -or $n -eq 'dispatch_agent') {
                                $totalAgents++
                                $desc = if ($c.input.description) { $c.input.description } elseif ($c.input.prompt) { $c.input.prompt.Substring(0, [Math]::Min(30, $c.input.prompt.Length)) } else { '' }
                                $agentCalls[$c.id] = @{ desc = $desc; startTime = $lastAssistantTime }
                            }
                            # TODO 追踪
                            if ($n -eq 'TaskCreate' -or $n -eq 'TodoWrite') {
                                $todoCounter++
                                $tid = "$todoCounter"
                                $subj = if ($c.input.subject) { $c.input.subject } elseif ($c.input.content) { $c.input.content } else { '' }
                                $todoState[$tid] = @{ subject = $subj; status = 'pending' }
                            }
                            if ($n -eq 'TaskUpdate' -or $n -eq 'TodoUpdate') {
                                $tid = if ($c.input.taskId) { $c.input.taskId } elseif ($c.input.id) { $c.input.id } else { '' }
                                if ($tid -and $c.input.status -and $todoState.ContainsKey($tid)) {
                                    $todoState[$tid].status = $c.input.status
                                }
                            }
                        }
                    }
                    if ($roundHasTool) { $toolRounds++ }
                }
                # tool_result 标记 agent 完成
                if ($obj.type -eq 'result' -or ($obj.message -and $obj.message.role -eq 'user')) {
                    if ($obj.message -and $obj.message.content) {
                        foreach ($c in $obj.message.content) {
                            if ($c.type -eq 'tool_result' -and $agentCalls.ContainsKey($c.tool_use_id)) {
                                $agentCalls.Remove($c.tool_use_id)
                                $completedAgents++
                            }
                        }
                    }
                }
            } catch {}
        }
        if ($toolCounts.Count -gt 0) {
            $top = $toolCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1
            $toolTop = "$($top.Key):$($top.Value)"
        }
        # 运行中的 agents
        $runningAgents = @($agentCalls.Values)
        # TODO 列表
        $todos = @($todoState.Values)
    }
} catch {}

# ── Effort Level ───────────────────────────────────────────
$effortLevel = $null
if ($data.effort) {
    if ($data.effort -is [string]) { $effortLevel = $data.effort }
    elseif ($data.effort.level) { $effortLevel = $data.effort.level }
}

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
$cacheTtlStr = $null
$cacheTtlColor = $null
if ($lastAssistantTime) {
    $elapsed = ([DateTime]::UtcNow - $lastAssistantTime).TotalSeconds
    $remaining = 300 - $elapsed
    if ($remaining -gt 0) {
        $min = [math]::Floor($remaining / 60); $sec = [math]::Floor($remaining % 60)
        $cacheTtlStr = "${min}m${sec}s"
        $cacheTtlColor = if ($remaining -gt 180) { "$esc[38;5;114m" } elseif ($remaining -gt 60) { "$esc[38;5;221m" } else { "$esc[38;5;210m" }
    } else {
        $cacheTtlStr = "expired"
        $cacheTtlColor = "$esc[38;5;210m"
    }
}
$toolStr  = if ($toolTop) { "${toolRounds}r/${toolTotal}c($toolTop)" } else { "${toolRounds}r/${toolTotal}c" }
$gitStr   = if ($gitBranch) { $gitBranch } else { [char]0x2014 }

# ── Rate Limit ─────────────────────────────────────────────
$rl5h = $null; $rl7d = $null
if ($data.rate_limits) {
    if ($data.rate_limits.five_hour.used_percentage -ne $null) { $rl5h = [math]::Round($data.rate_limits.five_hour.used_percentage) }
    if ($data.rate_limits.seven_day.used_percentage -ne $null) { $rl7d = [math]::Round($data.rate_limits.seven_day.used_percentage) }
}
function RlColor($v) { if ($v -gt 80) { "$esc[38;5;210m" } elseif ($v -gt 60) { "$esc[38;5;221m" } else { "$esc[38;5;114m" } }

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
$cRl     = "$esc[38;5;117m"
$cAgent  = "$esc[38;5;183m"
$cTodo   = "$esc[38;5;114m"
$cPct    = if ($pct -gt 80) { "$esc[38;5;210m" } elseif ($pct -gt 50) { "$esc[38;5;221m" } else { "$esc[38;5;114m" }
$cEffort = switch ($effortLevel) { 'max' { "$esc[38;5;222m" } 'high' { "$esc[38;5;81m" } 'low' { "$esc[38;5;245m" } default { "$esc[38;5;245m" } }

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
$iRl     = [char]::ConvertFromUtf32(0x1F6A6)  # 🚦
$iAgent  = [char]::ConvertFromUtf32(0x1F47E)  # 👾
$iTodo   = [char]::ConvertFromUtf32(0x2705)   # ✅

# ── 组装两行 ────────────────────────────────────────────────
$sep = "$cSep | $reset"

# 第一行: 模型+effort | 上下文 | tokens | 缓存命中+TTL | 费用
$modelStr = "$cModel$iModel $($data.model.display_name)$reset"
if ($effortLevel) { $modelStr += " $cEffort$([char]0x26A1)$effortLevel$reset" }
$row1Parts = @(
    $modelStr,
    "$cPct$iCtx ${pct}% ($usedK/$(K $maxTk))$reset",
    "$cNum$iToken in:$(K $inTk) out:$(K $outTk)$reset",
    "$cCache$iCache hit:${cacheHit}%$(if ($cacheTtlStr) { " $cacheTtlColor$([char]0x23F3)$cacheTtlStr$reset" } else { '' })$reset",
    "$cCost$iCost $costStr$reset"
)
$line1 = $row1Parts -join $sep

# 第二行: 工具 | 改动 | 时长 | git | 目录
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

# 第三行（动态）: [Rate Limit] | [Agent] | [TODO]
$row3Parts = @()

# Rate Limit
if ($rl5h -ne $null) {
    $rlStr = "$iRl $(RlColor $rl5h)5h:${rl5h}%$reset"
    if ($rl7d -ne $null -and $rl7d -ge 50) { $rlStr += " $(RlColor $rl7d)7d:${rl7d}%$reset" }
    $row3Parts += $rlStr
}

# Agent 状态
if ($totalAgents -gt 0) {
    $agentProgress = "$esc[38;5;245m[$completedAgents/$totalAgents]$reset"
    if ($runningAgents.Count -eq 0) {
        $row3Parts += "$cAgent$iAgent $([char]0x2713)done $agentProgress$reset"
    } elseif ($runningAgents.Count -eq 1) {
        $a = $runningAgents[0]
        $adesc = if ($a.desc.Length -gt 20) { $a.desc.Substring(0,20) + '..' } else { $a.desc }
        $aElapsed = if ($a.startTime) { $elapsed = ([DateTime]::UtcNow - $a.startTime).TotalSeconds; "$([math]::Round($elapsed))s" } else { '' }
        $row3Parts += "$cAgent$iAgent $([char]0x25D0)$adesc$(if($aElapsed){"(${aElapsed})"}) $agentProgress$reset"
    } else {
        $row3Parts += "$cAgent$iAgent $($runningAgents.Count)run $agentProgress$reset"
    }
}

# TODO 进度
if ($todos.Count -gt 0) {
    $completed = @($todos | Where-Object { $_.status -eq 'completed' }).Count
    $inProg = $todos | Where-Object { $_.status -eq 'in_progress' } | Select-Object -First 1
    $todoDisp = if ($inProg -and $inProg.subject) {
        $subj = if ($inProg.subject.Length -gt 15) { $inProg.subject.Substring(0,15) + '..' } else { $inProg.subject }
        "$iTodo $([char]0x25B8)$subj ${completed}/$($todos.Count)"
    } else {
        "$iTodo ${completed}/$($todos.Count)"
    }
    $row3Parts += "$cTodo$todoDisp$reset"
}

if ($row3Parts.Count -gt 0) {
    Write-Output ($row3Parts -join $sep)
}
