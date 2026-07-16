#!/usr/bin/env bash
# Agent Commons — installer (macOS / Linux / WSL / Git Bash)
#
# Windows users: use install.ps1 instead.
#
# Usage (sub-install mode — copy from the local repo, no network):
#   bash agent-commons/installer/install.sh
# or, from inside the installer dir:
#   bash install.sh
#
# This script bootstraps ~/.agent-commons/ by copying the protocol files from
# the agent-commons subtree of this repository (the files co-located next to
# this script). It does NOT fetch anything from the network and does NOT touch
# any AI agent's home directory — agents join the system on their own by
# reading ONBOARDING.md (one-time joining flow); afterwards they use
# skills/agent-commons/SKILL.md as their runtime capability.
#
# Idempotent: re-running upgrades the protocol skeleton without touching your data.

set -e

CENTRAL="$HOME/.agent-commons"

# ── Locate the local source tree (sub-install mode) ────────────────
# This script lives at <repo>/agent-commons/installer/install.sh.
#   INSTALLER_DIR = this script's own dir    → ONBOARDING.md, CONVENTIONS.md, examples/
#   AGENT_ROOT    = parent (agent-commons/)  → SKILL.md, manifest.json
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="${AGENT_COMMONS_INSTALLER_DIR:-$SCRIPT_DIR}"
AGENT_ROOT="$(cd "$INSTALLER_DIR/.." && pwd)"

ONBOARDING_SRC="$INSTALLER_DIR/ONBOARDING.md"
CONVENTIONS_SRC="$INSTALLER_DIR/CONVENTIONS.md"
SKILL_SRC="$AGENT_ROOT/SKILL.md"
MANIFEST_SRC="$AGENT_ROOT/manifest.json"
EXAMPLES_DIR="$INSTALLER_DIR/examples"

# Verify the local source files exist (visible — before the silent bootstrap).
for f in "$ONBOARDING_SRC" "$CONVENTIONS_SRC" "$SKILL_SRC" "$MANIFEST_SRC"; do
  if [ ! -f "$f" ]; then
    echo "✗ Local source missing: $f" >&2
    echo "  Sub-install mode: run this script from within the agent-commons repo." >&2
    exit 1
  fi
done

# ── Silent bootstrap ───────────────────────────────────────────────
{
  # Directory skeleton
  #   skills/<name>/        agent-loadable capabilities (this skill itself + future ones)
  #   skills_data/<name>/   per-skill persistent data (private to the owning skill)
  #   mcp/<server>/         shared MCP server configs / local implementations
  #   plugins/<name>/       shared plugins (e.g. browser/editor extensions)
  #   tools/<name>/         shared scripts / utilities (CLI helpers, dotfiles, etc.)
  mkdir -p "$CENTRAL"/{skills/agent-commons,skills_data,mcp,plugins,tools,identity,rules,toolchain,projects,log/daily,log/decisions,log/archive,handoff/inbox,handoff/archive,handoff/shared-state}

  # Protocol skeleton (always overwrite — controlled by this project; copied locally)
  cp -f "$ONBOARDING_SRC"  "$CENTRAL/ONBOARDING.md"
  cp -f "$CONVENTIONS_SRC" "$CENTRAL/CONVENTIONS.md"
  cp -f "$SKILL_SRC"       "$CENTRAL/skills/agent-commons/SKILL.md"
  cp -f "$MANIFEST_SRC"   "$CENTRAL/skills/agent-commons/manifest.json"

  # User-owned templates (only seed if missing — never overwrite your edits)
  seed_if_missing() {
    local target="$1"
    local src="$2"
    [ -f "$target" ] && return 0
    [ -f "$src" ] || return 0
    cp -f "$src" "$target"
  }
  seed_if_missing "$CENTRAL/identity/profile.md"    "$EXAMPLES_DIR/identity-profile.template.md"
  seed_if_missing "$CENTRAL/identity/ROUTINE.md"    "$EXAMPLES_DIR/identity-routine.template.md"
  seed_if_missing "$CENTRAL/rules/universal.md"     "$EXAMPLES_DIR/rules-universal.template.md"
  seed_if_missing "$CENTRAL/rules/public-repo.md"   "$EXAMPLES_DIR/rules-public-repo.template.md"
  seed_if_missing "$CENTRAL/rules/file-cleanup.md"  "$EXAMPLES_DIR/rules-file-cleanup.template.md"
  seed_if_missing "$CENTRAL/rules/safety.md"        "$EXAMPLES_DIR/rules-safety.template.md"
  seed_if_missing "$CENTRAL/toolchain/paths.md"     "$EXAMPLES_DIR/toolchain-paths.template.md"

  # Initial state files
  if [ ! -f "$CENTRAL/handoff/shared-state/current-focus.md" ]; then
    cat > "$CENTRAL/handoff/shared-state/current-focus.md" <<'EOF'
# Current Focus

> Last updated: <date> by <agent-name>

(Empty — no active task. Update this file when you start substantive work.)
EOF
  fi

  if [ ! -f "$CENTRAL/projects/active.md" ]; then
    cat > "$CENTRAL/projects/active.md" <<'EOF'
# Active Projects

(Empty. Add the projects you are currently working on.)
EOF
  fi

  if [ ! -f "$CENTRAL/registry.json" ]; then
    cat > "$CENTRAL/registry.json" <<'EOF'
{
  "protocol_version": "2.1",
  "agents": {}
}
EOF
  fi
} > /dev/null 2>&1
