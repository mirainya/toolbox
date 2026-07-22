# cc - Claude CLI Profile Switcher
# https://github.com/anthropics/claude-code
#
# Usage:
#   cc                Interactive profile selector
#   cc <name>         Launch claude with named profile
#   cc <name> -Yolo   Launch with --dangerously-skip-permissions
#   cc -Yolo          Interactive selector, then launch in YOLO mode
#   cc list           List all profiles
#   cc add <name>     Create a new profile
#   cc remove <name>  Remove a profile
#   cc help           Show help

function cc {
    param(
        [Parameter(Position = 0)]
        [string]$Command,

        [Parameter(Position = 1)]
        [string]$Name,

        [switch]$Yolo,

        [Alias('c')]
        [switch]$Continue
    )

    $ProfilesDir = "$HOME\.claude\profiles"

    if (-not (Test-Path $ProfilesDir)) {
        New-Item -ItemType Directory -Path $ProfilesDir -Force | Out-Null
    }

    if (-not $Command) {
        _cc_interactive -Yolo:$Yolo -Continue:$Continue
        return
    }

    switch ($Command) {
        'list'   { _cc_list }
        'add'    {
            if (-not $Name) { Write-Host "Usage: cc add <name>" -ForegroundColor Yellow; return }
            _cc_add $Name
        }
        'remove' {
            if (-not $Name) { Write-Host "Usage: cc remove <name>" -ForegroundColor Yellow; return }
            _cc_remove $Name
        }
        'help'   { _cc_help }
        default  { _cc_launch $Command -Yolo:$Yolo -Continue:$Continue }
    }
}

function _cc_help {
    Write-Host ""
    Write-Host "  cc                Interactive profile selector" -ForegroundColor Cyan
    Write-Host "  cc <name>         Launch claude with named profile" -ForegroundColor Cyan
    Write-Host "  cc <name> -Yolo   Launch with --dangerously-skip-permissions" -ForegroundColor Cyan
    Write-Host "  cc <name> -c      Continue the most recent conversation" -ForegroundColor Cyan
    Write-Host "  cc -Yolo          Interactive selector, then launch in YOLO mode" -ForegroundColor Cyan
    Write-Host "  cc list           List all profiles" -ForegroundColor Cyan
    Write-Host "  cc add <name>     Create a new profile" -ForegroundColor Cyan
    Write-Host "  cc remove <name>  Remove a profile" -ForegroundColor Cyan
    Write-Host "  cc help           Show this help" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Flags can combine, e.g.  cc gaccode -c -Yolo" -ForegroundColor DarkGray
    Write-Host "  Profiles with multiple models prompt for model selection." -ForegroundColor DarkGray
    Write-Host ""
}

function _cc_get_profiles {
    $ProfilesDir = "$HOME\.claude\profiles"
    if (-not (Test-Path $ProfilesDir)) { return @() }
    $files = Get-ChildItem -Path $ProfilesDir -Filter "*.json" -ErrorAction SilentlyContinue
    if (-not $files) { return @() }
    return @($files)
}

function _cc_format_url([string]$url) {
    if ($url) {
        try { return ([System.Uri]$url).Host } catch { return $url }
    }
    return "(no URL)"
}

function _cc_list {
    $profiles = @(_cc_get_profiles)
    if ($profiles.Count -eq 0) {
        Write-Host "`n  No profiles found. Use 'cc add <name>' to create one.`n" -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "  Available profiles:" -ForegroundColor Cyan
    Write-Host ""
    foreach ($p in $profiles) {
        $content = Get-Content $p.FullName -Raw | ConvertFrom-Json
        $display = _cc_format_url $content.env.ANTHROPIC_BASE_URL
        Write-Host "    $($p.BaseName)" -ForegroundColor Green -NoNewline
        Write-Host "  - $display" -ForegroundColor DarkGray
    }
    Write-Host ""
}

function _cc_add {
    param([string]$Name)

    $ProfilesDir = "$HOME\.claude\profiles"
    $filePath = "$ProfilesDir\$Name.json"

    if (Test-Path $filePath) {
        $confirm = Read-Host "  Profile '$Name' already exists. Overwrite? (y/N)"
        if ($confirm -notin @('y', 'Y')) {
            Write-Host "  Cancelled." -ForegroundColor DarkGray
            return
        }
    }

    Write-Host ""
    Write-Host "  Creating profile: $Name" -ForegroundColor Cyan
    Write-Host ""

    $baseUrl = Read-Host "  ANTHROPIC_BASE_URL"
    $token   = Read-Host "  ANTHROPIC_AUTH_TOKEN"

    if (-not $baseUrl -or -not $token) {
        Write-Host "  Both URL and Token are required." -ForegroundColor Red
        return
    }

    $modelsRaw = Read-Host "  Models (comma-separated, optional)"
    $models = @($modelsRaw -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })

    $profile = @{ env = @{ ANTHROPIC_AUTH_TOKEN = $token; ANTHROPIC_BASE_URL = $baseUrl } }
    if ($models.Count -gt 0) { $profile.models = $models }

    $profile |
        ConvertTo-Json -Depth 10 |
        Set-Content -Path $filePath -Encoding UTF8

    Write-Host ""
    Write-Host "  Profile '$Name' saved." -ForegroundColor Green
}

function _cc_remove {
    param([string]$Name)

    $ProfilesDir = "$HOME\.claude\profiles"
    $filePath = "$ProfilesDir\$Name.json"

    if (-not (Test-Path $filePath)) {
        Write-Host "  Profile '$Name' not found." -ForegroundColor Red
        return
    }

    $confirm = Read-Host "  Remove profile '$Name'? (y/N)"
    if ($confirm -notin @('y', 'Y')) {
        Write-Host "  Cancelled." -ForegroundColor DarkGray
        return
    }

    Remove-Item $filePath -Force
    Write-Host "  Profile '$Name' removed." -ForegroundColor Green
}

function _cc_select_model {
    param([string]$FilePath)

    $content = Get-Content $FilePath -Raw | ConvertFrom-Json
    $models = @($content.models | Where-Object { $_ })

    if ($models.Count -eq 0) { return $null }
    if ($models.Count -eq 1) { return $models[0] }

    Write-Host ""
    Write-Host "  Select a model:" -ForegroundColor Cyan
    Write-Host ""
    for ($i = 0; $i -lt $models.Count; $i++) {
        Write-Host "  [$($i + 1)] $($models[$i])" -ForegroundColor Green
    }
    Write-Host ""
    $choice = (Read-Host "  Enter number (1-$($models.Count))").Trim()

    if ($choice -match '^\d+$') {
        $index = [int]$choice - 1
        if ($index -ge 0 -and $index -lt $models.Count) {
            return $models[$index]
        }
    }

    Write-Host "  Invalid model selection, using profile default." -ForegroundColor Yellow
    return $null
}

function _cc_run {
    param(
        [string]$FilePath,
        [string]$Label,
        [switch]$Yolo,
        [switch]$Continue
    )

    $model = _cc_select_model $FilePath

    $claudeArgs = @('--settings', $FilePath)
    if ($Continue) { $claudeArgs += '--continue' }
    if ($model)    { $claudeArgs += @('--model', $model) }
    if ($Yolo)     { $claudeArgs += '--dangerously-skip-permissions' }

    $tags = @()
    if ($Continue) { $tags += 'continue' }
    if ($model)    { $tags += "model: $model" }
    if ($Yolo)     { $tags += 'YOLO' }
    $suffix = if ($tags.Count -gt 0) { " ($($tags -join ', '))" } else { "" }

    Write-Host "`n  Launching claude with profile: $Label$suffix`n" -ForegroundColor Cyan
    claude @claudeArgs
}

function _cc_interactive {
    param(
        [switch]$Yolo,
        [switch]$Continue
    )

    $profiles = @(_cc_get_profiles)
    if ($profiles.Count -eq 0) {
        Write-Host "`n  No profiles found. Use 'cc add <name>' to create one.`n" -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "  Select a profile:" -ForegroundColor Cyan
    Write-Host ""

    for ($i = 0; $i -lt $profiles.Count; $i++) {
        $content = Get-Content $profiles[$i].FullName -Raw | ConvertFrom-Json
        $display = _cc_format_url $content.env.ANTHROPIC_BASE_URL
        Write-Host "  [$($i + 1)] $($profiles[$i].BaseName)" -ForegroundColor Green -NoNewline
        Write-Host "  - $display" -ForegroundColor DarkGray
    }

    Write-Host ""
    $choice = (Read-Host "  Enter number (1-$($profiles.Count))").Trim()

    if ($choice -match '^\d+$') {
        $index = [int]$choice - 1
        if ($index -ge 0 -and $index -lt $profiles.Count) {
            $selected = $profiles[$index]
            _cc_run $selected.FullName $selected.BaseName -Yolo:$Yolo -Continue:$Continue
            return
        }
    }

    Write-Host "  Invalid selection." -ForegroundColor Red
}

function _cc_launch {
    param(
        [string]$Name,
        [switch]$Yolo,
        [switch]$Continue
    )

    $ProfilesDir = "$HOME\.claude\profiles"
    $filePath = "$ProfilesDir\$Name.json"

    if (-not (Test-Path $filePath)) {
        Write-Host "  Profile '$Name' not found." -ForegroundColor Red
        _cc_list
        return
    }

    _cc_run $filePath $Name -Yolo:$Yolo -Continue:$Continue
}
