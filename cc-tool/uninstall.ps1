#Requires -Version 5.1
<#
.SYNOPSIS
    Uninstall cc - Claude CLI Profile Switcher
#>

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "  Uninstalling cc" -ForegroundColor Yellow
Write-Host ""

# 1. Remove cc.ps1
$targetFile = "$HOME\.claude\cc.ps1"
if (Test-Path $targetFile) {
    Remove-Item $targetFile -Force
    Write-Host "  [OK] Removed $targetFile" -ForegroundColor Green
} else {
    Write-Host "  [--] $targetFile not found (skipped)" -ForegroundColor DarkGray
}

# 2. Remove line from profile
if (Test-Path $PROFILE) {
    $lines = Get-Content $PROFILE
    $filtered = $lines | Where-Object { $_ -notmatch 'cc\.ps1' }
    $filtered | Set-Content $PROFILE
    Write-Host "  [OK] Removed cc.ps1 from $PROFILE" -ForegroundColor Green
}

# 3. Ask about profiles
$profilesDir = "$HOME\.claude\profiles"
if (Test-Path $profilesDir) {
    $count = (Get-ChildItem $profilesDir -Filter "*.json" -ErrorAction SilentlyContinue).Count
    if ($count -gt 0) {
        $confirm = Read-Host "  Found $count profile(s) in $profilesDir. Delete them? (y/N)"
        if ($confirm -in @('y', 'Y')) {
            Remove-Item $profilesDir -Recurse -Force
            Write-Host "  [OK] Removed $profilesDir" -ForegroundColor Green
        } else {
            Write-Host "  [--] Kept $profilesDir" -ForegroundColor DarkGray
        }
    } else {
        Remove-Item $profilesDir -Recurse -Force
        Write-Host "  [OK] Removed empty $profilesDir" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "  Uninstall complete. Reload profile: . `$PROFILE" -ForegroundColor Green
Write-Host ""
