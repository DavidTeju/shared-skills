# Install the safely-skip-permissions hook for Claude Code (Windows).
#
# Copies readonly-gate.sh to ~/.claude/hooks/ and registers it as a
# PreToolUse hook in ~/.claude/settings.json. Idempotent — safe to re-run.
#
# Usage:
#   .\install-readonly-gate.ps1            # install
#   .\install-readonly-gate.ps1 -DryRun    # preview changes
#
# Requires: Perl (e.g. Strawberry Perl) on PATH for the hook itself.

param([switch]$DryRun)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$HookSrc = Join-Path $ScriptDir 'readonly-gate.sh'
$HookDir = Join-Path $env:USERPROFILE '.claude\hooks'
$HookDst = Join-Path $HookDir 'readonly-gate.sh'
$Settings = Join-Path $env:USERPROFILE '.claude\settings.json'
$EventType = 'PreToolUse'
$HookCmd = '~/.claude/hooks/readonly-gate.sh'

if (-not (Test-Path $HookSrc)) {
    Write-Error "readonly-gate.sh not found at $HookSrc`nRun this script from the hooks/user-level/ directory."
}

# ── Step 1: Copy hook to ~/.claude/hooks/ ──
Write-Host "Hook: $HookSrc -> $HookDst"
if ($DryRun) {
    Write-Host '  WOULD COPY'
} else {
    if (-not (Test-Path $HookDir)) { New-Item -ItemType Directory -Path $HookDir -Force | Out-Null }
    Copy-Item -Path $HookSrc -Destination $HookDst -Force
    Write-Host '  Copied'
}

# ── Step 2: Register in settings.json ──
Write-Host "Settings: $Settings"
if ($DryRun) {
    Write-Host "  WOULD REGISTER $EventType -> $HookCmd"
} else {
    $settings_obj = @{}
    if (Test-Path $Settings) {
        try { $settings_obj = Get-Content $Settings -Raw | ConvertFrom-Json -AsHashtable }
        catch { $settings_obj = @{} }
    }

    if (-not $settings_obj.ContainsKey('hooks')) { $settings_obj['hooks'] = @{} }
    if (-not $settings_obj['hooks'].ContainsKey($EventType)) { $settings_obj['hooks'][$EventType] = @() }

    $already = $false
    foreach ($group in $settings_obj['hooks'][$EventType]) {
        foreach ($h in $group['hooks']) {
            if ($h['command'] -eq $HookCmd) { $already = $true; break }
        }
        if ($already) { break }
    }

    if ($already) {
        Write-Host '  Already registered'
    } else {
        $settings_obj['hooks'][$EventType] += @{
            matcher = ''
            hooks = @(@{ type = 'command'; command = $HookCmd })
        }

        $dir = Split-Path -Parent $Settings
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $settings_obj | ConvertTo-Json -Depth 10 | Set-Content $Settings -Encoding UTF8
        Write-Host '  Registered'
    }
}

Write-Host ''
Write-Host 'Done. The safely-skip-permissions hook will auto-approve read-only tool calls'
Write-Host 'in all future Claude Code sessions.'
