# Claude Code Setup

Personal bootstrap for my Claude Code workflow stack. Running one script on a
new device reproduces the full setup:

- **[everything-claude-code](https://github.com/worldflowai/everything-claude-code)** —
  agents, slash commands, skills, rules, and hooks from an Anthropic hackathon
  winner. Installed as a Claude Code plugin.
- **[ruflo](https://github.com/ruvnet/ruflo)** (formerly claude-flow) — agent
  orchestration: swarms, persistent memory, workflows. Core plugins installed
  globally; the full harness is opt-in per project.

## New device setup

```bash
git clone https://github.com/lucashsu007-create/claude-code-setup.git
cd claude-code-setup
./setup.sh
```

Prerequisites: Node 18+ and `git`. The script installs Claude Code itself if
missing. `gh` CLI is optional but recommended (`gh auth login`).

Everything is installed at **user scope**, so it applies to all projects on the
machine — no per-project files are created by the script.

## What gets installed

### Plugins (user scope)

| Plugin | Marketplace | What it provides |
|---|---|---|
| `everything-claude-code` | `worldflowai/everything-claude-code` | 9 agents, 15 commands, 13 skills, hooks, rules |
| `ruflo-core` | `ruvnet/ruflo` | Ruflo foundation — server, health checks, plugin discovery |
| `ruflo-swarm` | `ruvnet/ruflo` | Multi-agent team coordination |
| `ruflo-rag-memory` | `ruvnet/ruflo` | Hybrid-search retrieval memory |
| `ruflo-workflows` | `ruvnet/ruflo` | Reusable multi-step task templates |

### Key slash commands from everything-claude-code

| Command | Purpose |
|---|---|
| `/plan` | Implementation planning before coding |
| `/tdd` | Test-driven development workflow |
| `/code-review` | Quality and security review |
| `/e2e` | Playwright E2E test generation |
| `/build-fix` | Resolve build errors |
| `/refactor-clean` | Dead code cleanup |
| `/verify` | Verification loop |
| `/checkpoint` | Save session state |
| `/learn` | Extract reusable patterns from the session |
| `/orchestrate` | Multi-agent orchestration |
| `/setup-pm` | Configure preferred package manager |

Agents (used automatically or via delegation): planner, architect, tdd-guide,
code-reviewer, security-reviewer, build-error-resolver, e2e-runner,
refactor-cleaner, doc-updater.

Its hooks add: tmux reminders for long-running commands, Prettier auto-format +
`tsc` check after TS/JS edits, `console.log` warnings, session memory
persistence (save/load context across sessions), and compaction suggestions.

## Daily usage

Nothing to activate per project — user-scope plugins load in every directory you
open Claude Code in. Start a session anywhere and the commands are there.

A typical feature loop:

```
/plan add rate limiting to the upload endpoint   # plan first, waits for your CONFIRM
/tdd                                             # tests first, then implementation
/code-review                                     # security + quality pass on the diff
/learn                                           # save anything reusable as a skill
```

Other commands by situation:

- Build broken → `/build-fix`
- Need browser tests → `/e2e`
- Cleaning up → `/refactor-clean`
- Big multi-part task → `/orchestrate` (chains agents sequentially)
- Long session, want a save point → `/checkpoint`
- Docs drifted from code → `/update-docs`

Ruflo commands: `/swarm` (spin up a multi-agent team), `/watch` (monitor it),
`/recall <query>` (semantic search over past sessions' memory), `/ruflo-memory`,
`/workflow`, `/ruflo-status`. These shell out to `npx @claude-flow/cli`, which
downloads on first use — expect a pause the first time.

You mostly don't need to invoke agents by hand. Claude delegates to
planner/architect/code-reviewer/etc. on its own; the slash commands are just
explicit entry points.

### Two things that surprise people

- **`/code-review` may collide** with Claude Code's built-in command of the same
  name. If you get the wrong one, disambiguate with
  `/everything-claude-code:code-review`.
- **Hooks fire automatically** once installed: Prettier reformats TS/JS after
  edits, `tsc` errors get surfaced, `console.log` gets flagged, and session
  context is saved/restored. If a hook is noisy, disable the whole plugin with
  `claude plugin disable everything-claude-code@everything-claude-code` rather
  than editing plugin files (edits get overwritten on update).

## Ruflo: plugin path vs. full install

The plugins installed above are the **lite path** — slash commands and agent
definitions only, zero files in your workspace.

For the **full ruflo loop** (MCP server with `memory_store` / `swarm_init` /
`agent_spawn`, hooks, daemon, 98 agents), run inside a specific project:

```bash
npx ruflo init
```

This writes `.claude/`, `.claude-flow/`, and `CLAUDE.md` into that project and
registers the ruflo MCP server. Only do this in projects where you want heavy
orchestration — the lite plugins are enough for most work.

Other ruflo plugins worth knowing (install with
`claude plugin install <name>@ruflo --scope user`): `ruflo-autopilot`
(autonomous loops), `ruflo-loop-workers` (scheduled background tasks),
`ruflo-federation` (cross-machine agents), `ruflo-agentdb` (vector DB memory),
`ruflo-rvf` (memory snapshots across sessions). Full list: 35 plugins in the
[ruflo README](https://github.com/ruvnet/ruflo#quick-start).

## Useful commands

```bash
# See everything installed
claude plugin list

# Update marketplaces + plugins to latest
claude plugin marketplace update everything-claude-code
claude plugin marketplace update ruflo
claude plugin update everything-claude-code@everything-claude-code

# Inspect a plugin's components and token cost before enabling more
claude plugin details ruflo-swarm

# Disable / re-enable without uninstalling
claude plugin disable ruflo-swarm
claude plugin enable ruflo-swarm
```

## Files in this repo

- [setup.sh](setup.sh) — the one-shot bootstrap
- [settings.reference.json](settings.reference.json) — snapshot of the
  `~/.claude/settings.json` this setup produces, for reference/diffing. The
  script does **not** copy it; `claude plugin` writes settings itself.

## Notes

- Plugin state lives in `~/.claude/settings.json` (`enabledPlugins`,
  `extraKnownMarketplaces`) and caches under `~/.claude/plugins/`.
- Set up on 2026-07-28 with Claude Code 2.1.212, everything-claude-code
  `432485b`, ruflo-core 0.2.4.
