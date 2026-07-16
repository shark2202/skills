# Agent Commons — Windows installer (PowerShell)
#
# Usage (sub-install mode — copy from the local repo, no network):
#   .\install.ps1
# or from the repo root:
#   powershell -ExecutionPolicy Bypass -File agent-commons\installer\install.ps1
#
# This script bootstraps %USERPROFILE%\.agent-commons\ and prints the
# agent-onboarding message. It does NOT touch any AI agent's home directory —
# agents join the system on their own by reading ONBOARDING.md (one-time
# joining flow); afterwards they use skills\agent-commons\SKILL.md as their
# runtime capability.
#
# Idempotent: re-running upgrades the protocol skeleton without touching your data.
#
# Requirements: PowerShell 5.1 or later.

# UTF-8 output (otherwise Chinese gets garbled on Windows PowerShell 5.1)
# NOTE: this file is saved as UTF-8 with BOM so PS 5.1 parses Chinese literals correctly.
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
try { chcp 65001 > $null } catch {}

$ErrorActionPreference = 'Stop'

$Central = Join-Path $env:USERPROFILE '.agent-commons'
# Sub-install mode: copy the protocol files from the local agent-commons
# subtree of this repo (co-located next to this script). No network fetch.
# This script lives at <repo>\agent-commons\installer\install.ps1.
#   $InstallerDir = this script's own dir   → ONBOARDING.md, CONVENTIONS.md, examples\
#   $AgentRoot    = parent (agent-commons\)  → SKILL.md, manifest.json
$InstallerDir = $PSScriptRoot
if (-not $InstallerDir) { $InstallerDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$AgentRoot     = Split-Path -Parent $InstallerDir
$OnboardingSrc  = Join-Path $InstallerDir 'ONBOARDING.md'
$ConventionsSrc = Join-Path $InstallerDir 'CONVENTIONS.md'
$SkillSrc       = Join-Path $AgentRoot    'SKILL.md'
$ManifestSrc    = Join-Path $AgentRoot    'manifest.json'
$ExamplesDir    = Join-Path $InstallerDir 'examples'

# Verify local sources exist (visible — before the silent bootstrap).
foreach ($src in @($OnboardingSrc, $ConventionsSrc, $SkillSrc, $ManifestSrc)) {
    if (-not (Test-Path $src)) {
        Write-Host "✗ Local source missing: $src" -ForegroundColor Red
        Write-Host "  Sub-install mode: run this script from within the agent-commons repo." -ForegroundColor Red
        exit 1
    }
}

# ── Silent bootstrap ───────────────────────────────────────────────
$null = & {
    # Directory skeleton
    #   skills\<name>\        agent-loadable capabilities
    #   skills_data\<name>\   per-skill persistent data
    #   mcp\<server>\         shared MCP server configs / local implementations
    #   plugins\<name>\       shared plugins
    #   tools\<name>\         shared scripts / utilities
    $dirs = @(
        'skills\agent-commons','skills_data','mcp','plugins','tools',
        'identity','rules','toolchain','projects',
        'log\daily','log\decisions','log\archive',
        'handoff\inbox','handoff\archive','handoff\shared-state'
    )
    foreach ($d in $dirs) {
        $full = Join-Path $Central $d
        if (-not (Test-Path $full)) {
            New-Item -ItemType Directory -Path $full -Force | Out-Null
        }
    }

    # Protocol skeleton (always overwrite — controlled by this project)
    function Copy-File {
        param([string]$Src, [string]$Dest)
        Copy-Item -LiteralPath $Src -Destination $Dest -Force -ErrorAction Stop
    }

    Copy-File $OnboardingSrc  (Join-Path $Central 'ONBOARDING.md')
    Copy-File $ConventionsSrc (Join-Path $Central 'CONVENTIONS.md')
    Copy-File $SkillSrc       (Join-Path $Central 'skills\agent-commons\SKILL.md')
    Copy-File $ManifestSrc    (Join-Path $Central 'skills\agent-commons\manifest.json')

    # User-owned templates (only seed if missing)
    function Seed-If-Missing {
        param([string]$Target, [string]$Src)
        if (-not (Test-Path $Target)) {
            if (Test-Path $Src) { Copy-Item -LiteralPath $Src -Destination $Target -Force -ErrorAction Stop | Out-Null }
        }
    }
    Seed-If-Missing (Join-Path $Central 'identity\profile.md')    (Join-Path $ExamplesDir 'identity-profile.template.md')
    Seed-If-Missing (Join-Path $Central 'identity\ROUTINE.md')   (Join-Path $ExamplesDir 'identity-routine.template.md')
    Seed-If-Missing (Join-Path $Central 'rules\universal.md')     (Join-Path $ExamplesDir 'rules-universal.template.md')
    Seed-If-Missing (Join-Path $Central 'rules\public-repo.md')  (Join-Path $ExamplesDir 'rules-public-repo.template.md')
    Seed-If-Missing (Join-Path $Central 'rules\file-cleanup.md') (Join-Path $ExamplesDir 'rules-file-cleanup.template.md')
    Seed-If-Missing (Join-Path $Central 'rules\safety.md')       (Join-Path $ExamplesDir 'rules-safety.template.md')
    Seed-If-Missing (Join-Path $Central 'toolchain\paths.md')    (Join-Path $ExamplesDir 'toolchain-paths.template.md')

    # Initial state files
    $focusFile = Join-Path $Central 'handoff\shared-state\current-focus.md'
    if (-not (Test-Path $focusFile)) {
        @"
# Current Focus

> Last updated: <date> by <agent-name>

(Empty — no active task. Update this file when you start substantive work.)
"@ | Set-Content -Path $focusFile -Encoding UTF8
    }

    $projFile = Join-Path $Central 'projects\active.md'
    if (-not (Test-Path $projFile)) {
        @"
# Active Projects

(Empty. Add the projects you are currently working on.)
"@ | Set-Content -Path $projFile -Encoding UTF8
    }

    $registry = Join-Path $Central 'registry.json'
    if (-not (Test-Path $registry)) {
        @"
{
  "protocol_version": "2.1",
  "agents": {}
}
"@ | Set-Content -Path $registry -Encoding UTF8
    }
} 2>&1

# ── User-facing output (the only thing the user sees) ──────────────
# Build Chinese strings from UTF-8 bytes to avoid PS 5.1 source-encoding pitfalls.
$utf8 = [System.Text.Encoding]::UTF8
$msg1 = $utf8.GetString([byte[]](0xE8,0xAF,0xB7,0xE5,0xA4,0x8D,0xE5,0x88,0xB6,0xE4,0xBB,0xA5,0xE4,0xB8,0x8B,0xE5,0x86,0x85,0xE5,0xAE,0xB9,0xE5,0x8F,0x91,0xE7,0xBB,0x99,0xE4,0xBD,0xA0,0xE7,0x9A,0x84,0x41,0x49))
$msg2 = $utf8.GetString([byte[]](0xEF,0xBC,0x88,0x50,0x6C,0x65,0x61,0x73,0x65,0x20,0x63,0x6F,0x70,0x79,0x20,0x74,0x68,0x65,0x20,0x6C,0x69,0x6E,0x65,0x20,0x62,0x65,0x6C,0x6F,0x77,0x20,0x74,0x6F,0x20,0x79,0x6F,0x75,0x72,0x20,0x41,0x49,0x20,0x61,0x67,0x65,0x6E,0x74,0xEF,0xBC,0x89,0xEF,0xBC,0x9A))
