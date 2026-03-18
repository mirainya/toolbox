#Requires -Version 5.1
<#
.SYNOPSIS
    Install cc - Claude CLI Profile Switcher
.DESCRIPTION
    Copies cc.ps1 to ~/.claude/ and adds it to your PowerShell profile.
#>

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "  Installing cc - Claude CLI Profile Switcher" -ForegroundColor Cyan
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host ""

# 1. Check claude CLI exists
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host "  [!] 'claude' command not found. Please install Claude CLI first." -ForegroundColor Red
    Write-Host "      https://docs.anthropic.com/en/docs/claude-code" -ForegroundColor DarkGray
    exit 1
}

# 2. Copy cc.ps1 to ~/.claude/
$targetDir  = "$HOME\.claude"
$targetFile = "$targetDir\cc.ps1"
$sourceFile = "$PSScriptRoot\cc.ps1"

if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

Copy-Item -Path $sourceFile -Destination $targetFile -Force
Write-Host "  [OK] cc.ps1 -> $targetFile" -ForegroundColor Green

# 3. Create profiles directory
$profilesDir = "$targetDir\profiles"
if (-not (Test-Path $profilesDir)) {
    New-Item -ItemType Directory -Path $profilesDir -Force | Out-Null
    Write-Host "  [OK] Created $profilesDir" -ForegroundColor Green
} else {
    Write-Host "  [OK] $profilesDir (already exists)" -ForegroundColor Green
}

# 4. Add to PowerShell profile
$dotSourceLine = '. "$HOME\.claude\cc.ps1"'

if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    Write-Host "  [OK] Created PowerShell profile: $PROFILE" -ForegroundColor Green
}

$profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
if ($profileContent -and $profileContent.Contains('cc.ps1')) {
    Write-Host "  [OK] Profile already loads cc.ps1 (skipped)" -ForegroundColor Green
} else {
    Add-Content -Path $PROFILE -Value "`n$dotSourceLine"
    Write-Host "  [OK] Added to $PROFILE" -ForegroundColor Green
}

# 5. Done
Write-Host ""
Write-Host "  Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor Yellow
Write-Host "    1. Reload profile:   . `$PROFILE" -ForegroundColor White
Write-Host "    2. Add a profile:    cc add myapi" -ForegroundColor White
Write-Host "    3. Launch:           cc" -ForegroundColor White
Write-Host ""
