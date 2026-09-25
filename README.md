# Claude Code Setup

Personal bootstrap for my Claude Code workflow stack. Running one script on a
new device reproduces the full setup:

- **[everything-claude-code](https://github.com/worldflowai/everything-claude-code)** —
  agents, slash commands, skills, rules, and hooks from an Anthropic hackathon
  winner. Installed as a Claude Code plugin.

Ruflo was trialled alongside ECC and **removed** — see "Why ruflo was removed".

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

### Skills from this repo (user scope)

`setup.sh` links every `skills/<name>/` into `~/.claude/skills/<name>`, which
makes it a personal skill on this device. They are symlinks, so pulling this
repo updates them.

| Skill | What it's for |
|---|---|
| [`website-copy`](skills/website-copy/SKILL.md) | Writing and reviewing customer-facing website copy, in English and Dutch, so it sounds like the business talking instead of like AI. Comes with `copy_audit.py`, a scanner that pulls a page's visible text and flags the usual tells. |

Personal skills don't exist in cloud sessions or on a machine that hasn't run
this setup, so each skill is also committed into the repos under `~/projects`
as `.claude/skills/<name>/`. Where the personal skill is installed, it takes
precedence over the repo's copy. After changing a skill here, send the copies
out again:

```bash
scripts/sync-skill.sh website-copy --dry-run   # show what would happen
scripts/sync-skill.sh website-copy             # copy and commit in every repo; never pushes
```

It commits only the skill's own path, on each repo's default branch, going
through a temporary worktree when another branch is checked out. A few repos
are handled differently, with the reasons in the script: `csa-main` and
`claude-video` are skipped, and `study-platform` and `csa-platform` get a local
`chore/<skill>-skill` branch to push as a pull request.

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
| Overnight run | ~80-min checkpointed chunks via `/loop` — see "Overnight runs" below |
| Before opening a PR | `/verify pre-pr` → `/code-review` |
| Quarterly cleanup | `/refactor-clean` → `/verify` |

### Multi-agent workflows

Installing the plugin registered all nine agents — there is no further setup.
Confirm with `claude plugin details everything-claude-code`. The question is how
to drive them, and there are three modes that escalate in how much control you
hand over.

**1. Automatic delegation (the default).** Each agent's `description` frontmatter
contains trigger language — *"Use PROACTIVELY when build fails"*, *"MUST BE USED
for all code changes"*. Claude reads that to decide when to delegate on its own.
You invoke nothing. This accounts for most multi-agent behavior you'll actually
see.

**2. Explicit invocation** — force a specific agent:

```
use the security-reviewer agent on backend-api/src/auth
```

**3. Chains via `/orchestrate`** — a fixed sequence with a structured handoff
document (context, findings, files modified, open questions) passed between
agents. Four presets plus custom ordering:

```
/orchestrate feature "add webhook delivery with retries"
/orchestrate custom "architect,tdd-guide,code-reviewer" "redesign the caching layer"
```

#### The nine agents, and what they can touch

| Agent | Tools | Can edit code? |
|---|---|---|
| `planner` | Read, Grep, Glob | **No** |
| `architect` | Read, Grep, Glob | **No** |
| `code-reviewer` | Read, Grep, Glob, Bash | **No** |
| `tdd-guide` | Read, Write, Edit, Bash, Grep | Yes |
| `build-error-resolver` | Read, Write, Edit, Bash, Grep, Glob | Yes |
| `security-reviewer` | Read, Write, Edit, Bash, Grep, Glob | Yes |
| `e2e-runner` | Read, Write, Edit, Bash, Grep, Glob | Yes |
| `refactor-cleaner` | Read, Write, Edit, Bash, Grep, Glob | Yes |
| `doc-updater` | Read, Write, Edit, Bash, Grep, Glob | Yes |

The read-only three are deliberate: agents that *reason about* your code are
structurally prevented from changing it, so a planning or review step can never
quietly start editing files. All nine are pinned to `model: opus`.

#### Writing your own agent

Put a markdown file in `~/.claude/agents/`. This works identically in the
desktop app and the CLI, and unlike editing plugin files it survives plugin
updates:

```markdown
---
name: kalshi-risk-reviewer
description: Reviews any change touching order placement or position sizing. Use PROACTIVELY on kalshi/paper and kalshi/model.
tools: Read, Grep, Glob, Bash
model: opus
---

You review paper-trading logic for risk errors. Flag anything that could
place a live order, any unbounded position size, and any probability that
isn't clamped to [0,1].
```

Restart the session to load it. Give custom agents read-only tools unless they
genuinely need to write — that's the pattern ECC uses for its own reviewers.

#### Desktop app notes

- The `/agents` management panel is an interactive terminal dialog. In the
  desktop app, use the file-based approach above; it does everything the panel
  would.
- Agent chains are long-running — `/orchestrate feature` runs four agents
  sequentially. That's exactly the case where it beats driving the loop
  yourself: start it and step away.
- **Context is the real limit.** Each agent in a chain consumes context, and a
  long `/orchestrate` run can hit compaction mid-chain and lose handoff detail.
  For large tasks, running `/plan` → `/tdd` → `/verify` → `/code-review` manually
  gives you checkpoints between steps where you can course-correct.

### Overnight runs: checkpointed chunks

`/orchestrate feature` covers "start it and step away" for an afternoon. A run
meant to go all night needs different structure, because the two things that
kill unattended runs — a permission prompt nobody answers, and a wedged agent
with hours of uncommitted work behind it — both get worse with duration.

The fix is not asking the agent to watch a clock; it can't reliably self-time.
It's slicing the work so each chunk is **~80 minutes of scope**, letting a
scheduler fire the chunks, and ending every chunk in a durable checkpoint:
`/verify` green → commit → `.claude/checkpoints.log`. Then a failure at 3am
costs one chunk, not the night.

**1. Plan first, and size steps to the cadence.** Run `/plan` before bed and
split any step that looks bigger than ~90 minutes. Save the step list to
`.claude/overnight-plan.txt` — a text file, because the new-`.md` hook would
block a `PLAN.md`.

**2. Drive the cadence with `/loop`, run `/orchestrate` inside each iteration.**
Each firing does exactly one step and exits:

```
/loop 80m Read .claude/overnight-plan.txt and .claude/checkpoints.log. Find the
first plan step with no checkpoint. Do ONLY that step via /orchestrate feature
"<step>", then /checkpoint create "step-N". You are pre-authorized to commit on
branch overnight/<feature>. If /verify fails twice, log the failure to
.claude/checkpoints.log and end this iteration. When every step is
checkpointed, stop the loop.
```

The read-log → do-next-step → stop shape is the biggest completion-rate lever:
every iteration is resumable and idempotent, and each one starts with fresh
context reading durable state instead of a compacted memory of hour six. If the
scheduler rejects `80m`, anything in the 60–90 band works — the slicing
matters, the exact number doesn't.

**3. Pre-clear the stalls.** A permission prompt at 1am means 0% completion for
the rest of the night:

- Start the session in a permission mode that auto-accepts edits, and allowlist
  the test/build commands — `/fewer-permission-prompts` builds the allowlist
  from session history.
- The workspace convention is "commit only when asked", so the loop prompt must
  pre-authorize commits explicitly, on a named branch (never the default
  branch).
- WSL2: if the Windows host sleeps, everything stops. Keep the machine awake
  and run the session inside tmux.

**Why not one giant `/orchestrate` run with `/checkpoint` between agents?** Do
that *within* a chunk, but as the whole-night structure it fails the math: its
checkpoints land wherever phases happen to end rather than on a cadence, one
wedged agent blocks everything behind it, and context degrades across an
eight-hour session (see "Context is the real limit" above). A loop of small
orchestrations finishes 8 of 10 steps on a bad night; a monolithic run finishes
0 of 3.

### Why ruflo was removed

Ruflo (formerly claude-flow) was installed alongside ECC on 2026-07-28 and
removed on 2026-07-29. Recording why, so it isn't reinstated by reflex:

**1. It duplicated what ECC already did.** Ruflo's `/swarm` and ECC's
`/orchestrate` are competing answers to the same problem — multi-agent
coordination. Running both means two orchestrators over the same files. The
sequential ECC loop proved sufficient for solo work on small-to-medium repos.

**2. It wrote large artifacts into project repos.** It created `.claude-flow/`
directories in `study-platform/` (620K, including a 19,951-line
`neural/patterns.json`) and `lucas-hsu-website/` (508K) — **not gitignored**,
so one `git add -A` from being committed. It also ran a background daemon per
project.

**3. Its hooks fired on every edit and every bash command,** shelling out to
`npx ruflo@latest` when no local binary existed. Measured post-edit latency was
**>120s (timed out)** without a global install, ~0.6s with one. Fixable, but
only by adding a global npm package to keep a plugin's hooks usable.

The one genuinely additive feature was `/recall` — cross-session semantic
memory, which ECC lacks. Not worth the above.

**If reinstating**, do it deliberately and add `.claude-flow/` to your global
gitignore first:

```bash
claude plugin marketplace add ruvnet/ruflo
claude plugin install ruflo-rag-memory@ruflo --scope user
npm install -g ruflo   # REQUIRED, or hooks hang on every edit
```

**Removal, for reference** — what was run to undo it:

```bash
for p in ruflo-core ruflo-swarm ruflo-rag-memory ruflo-workflows; do
  claude plugin uninstall "$p@ruflo"
done
claude plugin marketplace remove ruflo
npm uninstall -g ruflo
rm -rf <project>/.claude-flow      # untracked; safe to delete
```

### Known upstream bug: 11 commands don't register

**Claude Code only registers a `.md` file as a slash command if it starts with a
YAML frontmatter block.** Only 4 of ECC's 15 command files have one
(`plan`, `tdd`, `e2e`, `setup-pm`). The other 11 — including `orchestrate`,
`verify`, `code-review`, and `learn` — ship as loose markdown and silently never
appear. Typing `/orchestrate` does nothing.

`setup.sh` fixes this automatically by running
[scripts/fix-ecc-commands.sh](scripts/fix-ecc-commands.sh), which copies the
affected files into `~/.claude/commands/` with the missing frontmatter added.
It writes there rather than patching the plugin so the fix survives
`claude plugin update` — **re-run it after any plugin update** to pick up
upstream changes to the command bodies:

```bash
./scripts/fix-ecc-commands.sh
```

The **9 agents are unaffected** — their files all have correct frontmatter, so
agent delegation works with or without this fix.

Verified broken on 2026-07-29 against ECC `432485b`.

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

## Useful commands

```bash
# See everything installed
claude plugin list

# Update marketplaces + plugins to latest
claude plugin marketplace update everything-claude-code
claude plugin update everything-claude-code@everything-claude-code

# Inspect a plugin's components and token cost before enabling more
claude plugin details everything-claude-code

# Disable / re-enable without uninstalling
claude plugin disable everything-claude-code@everything-claude-code
claude plugin enable everything-claude-code@everything-claude-code
```

## Files in this repo

- [setup.sh](setup.sh) — the one-shot bootstrap
- [scripts/fix-ecc-commands.sh](scripts/fix-ecc-commands.sh) — repairs the 11
  ECC commands that ship without frontmatter; run after each plugin update
- [skills/](skills/) — skills that `setup.sh` links into `~/.claude/skills`;
  see "Skills from this repo" above
- [scripts/sync-skill.sh](scripts/sync-skill.sh) — copies one of those skills
  into every repo under `~/projects` and commits it there
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
- Set up 2026-07-28 with Claude Code 2.1.212 and everything-claude-code
  `432485b`. Ruflo trialled and removed 2026-07-29.
