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

### The mental model

Most commands are **thin wrappers that hand the job to a specialist agent** with
a fixed script. `/plan` invokes the `planner` agent, `/tdd` invokes `tdd-guide`,
and so on. The value isn't magic — it's that each one runs a *checklist you'd
otherwise skip*, in a fixed order, and refuses to skip steps.

Two commands are gates, and they check different things:

|  | `/verify` | `/code-review` |
|---|---|---|
| Kind of check | **Mechanical** — does it run? | **Judgment** — is it good? |
| Method | Runs build, typecheck, lint, tests | Reads the diff against a checklist |
| Catches | Broken build, type errors, failing tests | Hardcoded keys, SQL injection, missing validation, 200-line functions |
| Can it pass on bad code? | Yes, easily | No — that's the point |

Green tests don't mean a safe change. Run both.

### The core loop, with a real example

Say you're adding a bucket-probability model to `kalshi/`.

**Step 1 — `/plan`.** Give it the requirement in plain English:

```
/plan add a calculator that turns NOAA ensemble forecasts into P(bucket) for each Kalshi temperature bucket
```

It restates the requirement, breaks it into phases, lists dependencies, flags
risks with severity, estimates complexity, and then **stops** with
`WAITING FOR CONFIRMATION`. It writes no code until you reply. You can steer it:

```
modify: skip the caching phase, we only run this once per day
```

Reply `yes` / `proceed` to unblock it. Skipping `/plan` on a multi-file change is
the single easiest way to end up with the wrong thing built well.

**Step 2 — `/tdd`.** Now implement, tests first:

```
/tdd use pytest; implement the P(bucket) calculator from the plan
```

It runs a strict red-green-refactor cycle: scaffold the interface as a stub that
raises `NotImplementedError` → write tests that fail → **run them and confirm
they fail for the right reason** → write minimal code to pass → re-run → refactor
with tests still green → check coverage.

That third step is the one people skip and the one that matters. A test that
passes before the implementation exists is a broken test, and running it first is
how you catch that. Coverage bar is 80%, but 100% for financial calculations,
auth, and security-critical code — which covers most of `kalshi/`.

**Step 3 — `/verify`.** The mechanical gate:

```
/verify
```

Runs in a fixed order, **stopping at the first failure**: build → typecheck →
lint → tests → `console.log` audit → git status. Output is a scorecard ending in
`Ready for PR: YES/NO`. It takes an argument to narrow the scope:

| Argument | Runs |
|---|---|
| `/verify quick` | Build + types only — fast inner-loop check |
| `/verify` or `/verify full` | Everything (default) |
| `/verify pre-commit` | The checks that matter before a commit |
| `/verify pre-pr` | Full checks plus a security scan |

**Step 4 — `/code-review`.** The judgment gate, on uncommitted changes:

```
/code-review
```

It runs `git diff --name-only HEAD` and reviews each changed file against a
tiered checklist:

- **CRITICAL** — hardcoded credentials/API keys, SQL injection, XSS, missing
  input validation, path traversal, insecure dependencies
- **HIGH** — functions over 50 lines, files over 800 lines, nesting deeper than
  4, missing error handling, stray `console.log`, `TODO`/`FIXME`, missing JSDoc
  on public APIs
- **MEDIUM** — mutation where immutable would do, missing tests for new code,
  accessibility problems

You get severity, file, line, and a suggested fix per finding, and it will block
on CRITICAL or HIGH.

**Step 5 — `/learn`** (optional). If you solved something non-obvious, this
extracts it into a reusable skill at `~/.claude/skills/learned/<name>.md` so
future sessions inherit it. It asks before saving. It deliberately ignores
trivia — typos, one-off outages — and targets error-resolution patterns, library
quirks, and project conventions you discovered the hard way.

### Situational commands

**`/build-fix` — the build is broken.** Fixes errors *one at a time*: parse the
output, group by file, show 5 lines of context, explain, apply, re-run, confirm
that specific error is gone. It stops on its own if a fix introduces new errors
or the same error survives 3 attempts, which prevents the thrash loop where
fixing error 1 creates errors 2 and 3.

**`/refactor-clean` — periodic dead-code sweep.** Runs `knip`, `depcheck`, and
`ts-prune`, writes a report to `.reports/dead-code-analysis.md`, and buckets
findings as SAFE (unused utilities, test files) / CAUTION (API routes,
components) / DANGER (config, entry points). It only proposes SAFE deletions,
and around every single deletion it runs the full test suite, applies, re-runs,
and **rolls back if tests fail**. This is a maintenance task, not a per-feature
step. TS/JS only — the three analysis tools have no Python equivalent here.

**`/test-coverage` — coverage slipped.** Finds files under 80%, analyses the
untested paths, generates the missing tests, verifies they pass, reports
before/after. Focuses on error handling and edge cases (null, empty, boundary),
which is where the gaps usually are.

**`/e2e` — a user-facing flow changed.** Generates Playwright tests using the
Page Object Model, runs across Chrome/Firefox/Safari, captures screenshots,
videos, and traces on failure, and quarantines flaky tests. Only
`lucas-hsu-website/` and `study-platform/` have a browser UI.

**`/checkpoint` — save points in a long session.** `create <name>` runs
`/verify quick`, commits or stashes, and logs to `.claude/checkpoints.log`.
`verify <name>` diffs current state against that checkpoint — files changed,
tests gained/lost, coverage delta. Also `list` and `clear` (keeps last 5).
Useful before a risky refactor so "go back to where it worked" is one command.

**`/eval` — for work where correctness is fuzzy.** Defines pass criteria in
`.claude/evals/<feature>.md` up front, splitting *capability* evals (new
behavior, target pass@3 > 90%) from *regression* evals (old behavior still
works, target pass^3 = 100%). Worth it for model/heuristic work like `kalshi`'s
probability code, overkill for CRUD.

**`/orchestrate` — chain agents on a genuinely big task.** Runs a fixed agent
sequence, passing a structured handoff document between each:

| Workflow | Chain |
|---|---|
| `feature` | planner → tdd-guide → code-reviewer → security-reviewer |
| `bugfix` | explorer → tdd-guide → code-reviewer |
| `refactor` | architect → code-reviewer → tdd-guide |
| `security` | security-reviewer → code-reviewer → architect |

```
/orchestrate feature "add webhook delivery with retries"
/orchestrate custom "architect,tdd-guide,code-reviewer" "redesign the caching layer"
```

It ends with a report recommending SHIP / NEEDS WORK / BLOCKED. This is the
expensive option — it's the whole loop in one shot, with less steering from you.
Prefer running `/plan` → `/tdd` → `/verify` → `/code-review` yourself unless the
task is large and you want to step away.

**`/update-docs` and `/update-codemaps` — docs drifted.** The first regenerates
contributor and runbook docs from `package.json` and `.env.example` as the
source of truth, and flags docs untouched for 90+ days. The second scans imports
and exports to regenerate architecture codemaps, asking for approval if the diff
exceeds 30%.

### Picking a workflow by situation

| Situation | Sequence |
|---|---|
| New feature, multi-file | `/plan` → `/tdd` → `/verify` → `/code-review` |
| Small change, one file | `/tdd` → `/verify quick` |
| Bug fix | `/tdd` (write a test that reproduces it first) → `/verify` → `/code-review` |
| Build won't compile | `/build-fix` → `/verify` |
| Touching auth, payments, user input | add `/orchestrate security` before merge |
| Big task, want to step away | `/orchestrate feature "..."` |
| Before opening a PR | `/verify pre-pr` → `/code-review` |
| Quarterly cleanup | `/refactor-clean` → `/verify` |

### Ruflo commands

`/swarm` spins up a coordinated multi-agent team, `/watch` live-streams its
events, `/recall <query>` does semantic search over memory from past sessions,
and `/ruflo-memory`, `/workflow`, and `/ruflo-status` manage memory, workflow
templates, and health. These shell out to `npx @claude-flow/cli`, which
downloads on first use — expect a pause the first time.

### Gotchas

- **`/code-review` may collide** with Claude Code's built-in command of the same
  name. Disambiguate with `/everything-claude-code:code-review`.
- **The commands assume npm/TypeScript.** `/verify`, `/test-coverage`, and
  `/build-fix` reach for `npm run build` and `npm test --coverage` by default. In
  `kalshi/` and `market-data-toolkit/`, say `use pytest` in the prompt. See the
  Python caveats in `templates/projects-CLAUDE.md`, which is installed at
  `~/projects/CLAUDE.md` so Claude picks it up automatically.
- **Hooks fire on their own**: Prettier reformats TS/JS after edits, `tsc` errors
  surface, `console.log` gets flagged, session context saves and restores. One
  hook **blocks creating new `.md` files** other than README/CLAUDE/AGENTS/
  CONTRIBUTING — that's why this documentation lives in the README. If a hook is
  noisy, disable the whole plugin with
  `claude plugin disable everything-claude-code@everything-claude-code` rather
  than editing plugin files, since edits get overwritten on update.
- **You rarely need to name agents.** Claude delegates to planner, code-reviewer,
  and the rest on its own. The slash commands are explicit entry points for when
  you want to force a specific script.

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
- [templates/projects-CLAUDE.md](templates/projects-CLAUDE.md) — the workspace
  `CLAUDE.md` that lives at `~/projects/CLAUDE.md`. Copy it there on a new
  device and edit the project index to match:

  ```bash
  cp templates/projects-CLAUDE.md ~/projects/CLAUDE.md
  ```

  It's kept out of the repo root on purpose — a `CLAUDE.md` here would apply to
  this repo instead of your workspace.

## Notes

- Plugin state lives in `~/.claude/settings.json` (`enabledPlugins`,
  `extraKnownMarketplaces`) and caches under `~/.claude/plugins/`.
- Set up on 2026-07-28 with Claude Code 2.1.212, everything-claude-code
  `432485b`, ruflo-core 0.2.4.
