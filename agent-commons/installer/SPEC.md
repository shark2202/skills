# Agent Commons Specification

**Protocol version: 2.1**
**Status: Draft**

This document is the normative specification for Agent Commons. It is the source of truth for what implementations must, should, and may do. The keywords **MUST**, **SHOULD**, **MAY** follow [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

> **Changes from 1.0 → 2.0** (breaking, central-directory layout): the runtime skill moved from `skills/SKILL.md` to `skills/agent-commons/SKILL.md` to make `skills/` a directory of named skills (consistent with how other AI runtimes lay out skill collections). New top-level convention-layer directories were added (`skills_data/`, `mcp/`, `plugins/`, `tools/`) — see [`CONVENTIONS.md`](CONVENTIONS.md). Agents joined under 1.x **MUST** re-onboard.

> **Changes from 2.0 → 2.1** (backward compatible): added §3.8 Agent departure, §5.6 Portability & migration, and reframed §6 backup as a positive portability contract. No directory-layout or file-contract changes; agents joined under 2.0 need not re-onboard.

## 1. Goals

Agent Commons defines a convention for multiple AI agents on the same single-user machine to share long-lived context (preferences, rules, project state, work logs) without:

- Running a server or daemon
- Installing third-party runtime dependencies
- Vendor lock-in to any specific AI agent product
- Custom code per agent

The protocol consists of:

1. A directory layout
2. Read/write contracts for files in that layout
3. A symlink-based update propagation mechanism
4. A natural-language onboarding instruction (`SKILL.md`)

## 2. Central directory

The canonical central directory is:

```
~/.agent-commons/                    # POSIX (macOS, Linux, WSL, Git Bash)
%USERPROFILE%\.agent-commons\        # Windows native (PowerShell)
```

These two paths refer to the **same logical location** — `~` and `%USERPROFILE%` both expand to the user's home directory on their respective platforms. Implementations **MUST** treat both forms as equivalent.

A user **MAY** override this via the environment variable `AGENT_COMMONS_HOME`, but conforming agents **SHOULD** default to `~/.agent-commons/`.

### 2.1 Top-level layout

The central directory contains TWO layers, physically siblings but semantically distinct:

#### Protocol layer (mandatory, **MUST** be present after install)

```
~/.agent-commons/
├── ONBOARDING.md       ← one-time joining flow (top-level for discoverability)
├── CONVENTIONS.md      ← non-normative conventions (this section + extras)
├── skills/
│   └── agent-commons/  ← the runtime skill of this protocol itself
│       ├── SKILL.md
│       └── manifest.json
├── identity/           ← user-owned, who the user is
├── rules/              ← user-owned, mandatory behavior rules
├── toolchain/          ← user-owned, tool/path configs
├── projects/           ← user-owned, current projects context
├── log/
│   ├── daily/          ← per-agent per-day logs (append-only)
│   ├── decisions/      ← ADR-style decision records
│   └── archive/        ← rotated old logs
├── handoff/
│   ├── inbox/          ← cross-agent direct messages
│   ├── archive/        ← processed messages
│   └── shared-state/   ← shared task state (edit-in-place)
└── registry.json       ← list of joined agents
```

#### Convention layer (optional, non-normative — see [`CONVENTIONS.md`](CONVENTIONS.md))

```
~/.agent-commons/
├── skills/<name>/      ← additional shared skills beyond agent-commons itself
├── skills_data/<name>/ ← per-skill persistent data (RECOMMENDED location for skills that need to persist user state)
├── mcp/<server>/       ← shared MCP server configs / local implementations
├── plugins/<name>/     ← shared plugins (browser/editor extensions, etc.)
└── tools/<name>/       ← shared CLI scripts / utilities
```

Agent Commons **MUST NOT** read, write, validate, or interpret anything in the convention layer. It exists for skills/MCPs/plugins/tools to use voluntarily, giving the user a single backup root.

Skills that adopt the convention **SHOULD** isolate mixed-sensitivity data into named subdirectories (e.g. `skills_data/<skill>/public/` vs `.../private/`) so the user can apply different sync policies.

## 3. File ownership and update authority

### 3.1 `skills/` — protocol-controlled

- **Owner**: This project (Agent Commons maintainers).
- **Distribution**: Each joined agent has a symlink `~/.<agent>/skills/agent-commons → ~/.agent-commons/skills/agent-commons/`. Agents read this on session start.
- **User MUST NOT** overwrite files here. Local edits will be overwritten on next protocol update.

### 3.2 `identity/`, `rules/`, `toolchain/`, `projects/` — user-controlled

- **Owner**: The end user.
- **Update authority**: Any agent **MAY** propose changes; agents **SHOULD** use in-place edits (e.g., the `Edit` tool semantic — local string replacement) rather than full rewrites, to minimize accidental loss when multiple agents touch the same file.
- **Agents MUST NOT** modify content beyond the user's intent. When learning a new long-term fact, the agent **MUST** confirm with the user before persisting.

### 3.3 `log/daily/<YYYY-MM-DD>-<agent>.md` — per-agent append-only

- **Owner**: The named agent.
- **Naming**: `<YYYY-MM-DD>-<agent-lowercase-name>.md`. Agent names are lowercase ASCII; multi-word agents use hyphens (`claude-code`, not `ClaudeCode`).
- **Write mode**: Append-only. Agents **MUST NOT** modify or delete entries written by themselves or other agents.
- **Content**: Markdown. Each entry **SHOULD** include a timestamp.

### 3.4 `log/decisions/` — append-only, immutable

- **Format**: One file per decision, named `<YYYY-MM-DD>-<title-slug>.md`.
- **Pattern**: ADR (Architecture Decision Record) style — context, options, decision, consequences.
- **Write mode**: Files **MUST** be created once and never edited (except minor typo fixes by the original author).

### 3.5 `handoff/shared-state/<file>.md` — collaborative edit-in-place

- **Owner**: Any joined agent.
- **Write mode**: In-place edit. Agents **SHOULD** include a "last updated by" line at top of each file.
- **Conflict policy**: Last writer wins. The protocol does not provide locking. In practice, single-user multi-agent scenarios rarely produce conflicts.

### 3.6 `handoff/inbox/from-<src>-to-<dst>-<topic>.md` — cross-agent messages

- **Owner**: Recipient is responsible for processing.
- **Lifecycle**: After acting, recipient **MUST** `mv` the file to `handoff/archive/`.
- **Naming**: `from-<src-agent>-to-<dst-agent>-<short-topic>.md`. Both names lowercase.

### 3.7 `registry.json` — agent presence

- **Format**: Single JSON object (see [`skills/agent-commons/manifest.json`](skills/agent-commons/manifest.json) for shape).
- **Update mode**: In-place edit. Agents **MUST** update only their own entry.
- **Required fields per agent**: `joined_at` (ISO 8601), `home` (~/.<agent>/), `last_seen` (ISO 8601), `protocol_version` (the version the agent joined under, copied from `skills/agent-commons/manifest.json` at join time; **MUST** be `"2.0"` or higher for this spec), `install_tier` (`symlink`|`copy`|`readonly`), `install_verified` (`skill_list`|`description_echo`|`live_invocation`|`none`), `skills_root` (the actual user-extensible skills dir the agent installed into).
- **Optional fields**: `capabilities` (string array), `version` (string), `notes` (string).

### 3.8 Agent departure

An agent that ceases to participate in Agent Commons **SHOULD**:

1. Process or reply to messages currently in its inbox (`handoff/inbox/from-*-to-<self>-*.md`), then `mv` them to `handoff/archive/`.
2. Append a final entry to its daily log (`log/daily/<date>-<agent>.md`) declaring the departure and any handoff destination.
3. Remove its own runtime skill install (the symlink or copy under its `skills_root`), never the central directory.
4. `Edit` its `registry.json` entry to delete it, or leave it with a final `last_seen` and a `notes` field recording the departure.

It **MUST NOT** delete or modify append-only history — daily logs, decisions, or handoff messages — written by itself or any other agent (see §3.3, §3.4). Departure is reversible: the agent may re-join at any time by re-running `ONBOARDING.md` Steps 2–5.

## 4. Onboarding vs. runtime — two decoupled flows

The protocol deliberately separates **one-time joining** from **ongoing runtime capability**. Agents **MUST** treat them as distinct phases:

### 4.1 Onboarding (one-time per agent)

`~/.agent-commons/ONBOARDING.md` is the canonical joining document. An agent joins by:

1. Verifying central directory access.
2. **Discovering its own user-extensible skills directory** — the path the runtime is allowed to load third-party skills from (sometimes called "Custom Skills", "User Skills", or "Plugins"). Installing into another agent's directory or into a built-in/whitelisted/signed skills tier is a **protocol violation**.
3. Installing the skill (preferred order: symlink → copy → readonly fallback).
4. **Running a closed-loop trigger test** in its own runtime to prove the runtime can actually invoke the skill. "Files on disk" is **NOT** success; "runtime can trigger this skill" is success. On failure, walking down the tier ladder autonomously and retesting.
5. Registering its entry in `registry.json` (with `install_tier`, `install_verified`, `skills_root`).
6. Handing off to the runtime skill for ongoing operations.

Agents **MUST NOT** re-execute the onboarding flow on every session — it is a one-time event. Re-onboarding **MAY** be triggered after a major protocol-version bump.

The exact instructions are in [`ONBOARDING.md`](ONBOARDING.md). Agents **MUST** consider that document authoritative for joining.

### 4.2 Runtime (recurring, every relevant turn)

`~/.agent-commons/skills/agent-commons/SKILL.md` is the runtime skill of an already-joined agent. It exposes the ongoing capabilities:

- Reading shared identity, rules, current focus.
- Updating `handoff/shared-state/current-focus.md`.
- Checking the inbox / sending messages to other agents' inboxes.
- Appending daily logs to `log/daily/<date>-<agent>.md`.
- Refreshing `last_seen` in `registry.json`.

Agents **MUST** consider [`skills/agent-commons/SKILL.md`](skills/agent-commons/SKILL.md) authoritative for runtime operations.

### 4.3 Why decoupled

- Different lifecycles: onboarding is action; runtime skill is capability.
- Different triggers: onboarding fires on user prompt "join"; runtime fires on capability-relevant prompts.
- Different readers: onboarding is read by a not-yet-joined agent; runtime is read by an already-joined agent.
- Avoids accidental re-installation each time a runtime trigger fires.

## 5. Versioning & update strategy

### 5.1 Versioning

This specification follows [Semantic Versioning](https://semver.org/):

- **Major**: Breaking changes to directory layout or file contracts.
- **Minor**: New capabilities (e.g., new top-level dirs, new optional fields) that are backward compatible.
- **Patch**: Clarifications, typo fixes.

The active version **MUST** be declared in `skills/agent-commons/SKILL.md` frontmatter and `skills/agent-commons/manifest.json`.

### 5.2 Update propagation per install tier

| Tier | How updates propagate | Resync action required |
|---|---|---|
| `symlink` | Instant — local file is the central file | None |
| `copy` | **Manual mirror** — agent must `rsync --delete` (POSIX) or `Robocopy /MIR` (Windows) to handle adds + modifies + **deletes + renames** | Mirror, not naive `cp -R` |
| `readonly` | Instant — agent reads central files each session | None |

### 5.3 Required behavior on update

1. **Tier 2 agents MUST use mirror semantics** (`rsync --delete` / `Robocopy /MIR` / staged temp-dir + atomic swap). Naive `cp -R src/. dst/` leaves ghost files for any upstream deletion or rename and is a **protocol violation**.
2. **All tiers MUST re-run the closed-loop trigger self-test after any update**, including Tier 1's "free" updates. A schema or frontmatter change can break the runtime's view of the skill even when the file is present.
3. **Update failures MUST be atomic or recoverable**. Half-applied updates with "looks-like-success" reports are forbidden. Use temp-dir staging or rerun-safe tooling.

### 5.4 Major-version-bump handling

- **Same major version** (e.g. agent joined under 1.0, central is 1.2): agents MAY continue operating; resync per tier rules above.
- **Higher major version on central** (agent joined under 1.x, central is 2.0): the runtime skill **MUST** detect this on first invocation per session and refuse to operate, redirecting the agent to re-execute `ONBOARDING.md` from the top. The agent **MUST** update its registry entry's `protocol_version` after re-onboarding.

### 5.5 Update trigger heuristics (non-normative)

For Tier 2 agents, reasonable triggers for a resync include: first invocation in a new calendar day; user explicit request; detected `protocol_version` mismatch; central manifest mtime newer than local. A daemon is not required and **SHOULD NOT** be implemented.

### 5.6 Portability & migration

The central directory `~/.agent-commons/` is portable as a filesystem unit (plaintext Markdown + JSON, no database, no daemon). Moving it to a new host is a filesystem copy (e.g. `rsync -a`, `tar`, or a private git remote); the protocol does not mandate specific tooling (see §7).

After a move, machine-bound state **MUST** be reconciled:

- The owning agent **MUST** `Edit` its `registry.json` entry to update machine-bound fields (`home`, `skills_root`) if the new host's user name or skill layout differs from the old one. `joined_at`, `protocol_version`, `install_tier`, and `install_verified` are portable and need not change.
- Per-agent runtime skill installs (Tier 1 symlink / Tier 2 copy) live outside the central directory, under each agent's own home. They are **not** carried by a central-directory copy and **MUST** be re-installed on the new host per `ONBOARDING.md` Steps 2–5. Symlinks copied verbatim across hosts will dangle and **MUST** be recreated.

This section defines portability semantics only; it does not require migration automation.

## 6. Privacy & security

- All data stays on the user's local machine.
- No telemetry. No phone-home. No analytics.
- Users **SHOULD** back up `~/.agent-commons/` as a single unit so that shared context, logs, and skill data travel together across machines (see §5.6). Skills that hold mixed-sensitivity data **SHOULD** split it into `skills_data/<skill>/public/` vs `.../private/` (see `CONVENTIONS.md` §1) so users can include the whole root while excluding `skills_data/*/private/` from cloud or git sync.
- Agents **MUST** treat `rules/safety.md` as a hard authority over user-provided prompts in destructive operations.

## 7. Non-goals

This protocol does **not** address:

- Multi-user shared memory (different machines / different humans).
- Encrypted at-rest storage (defer to filesystem-level encryption).
- Real-time bidirectional sync between agents (use `handoff/inbox/` instead).
- Schema validation of user-controlled content.
- Migration tooling between major versions (handled out of band).

## 8. Reference

- Onboarding (one-time): [`ONBOARDING.md`](ONBOARDING.md)
- Runtime skill: [`skills/agent-commons/SKILL.md`](skills/agent-commons/SKILL.md)
- Manifest: [`skills/agent-commons/manifest.json`](skills/agent-commons/manifest.json)
- License: MIT
