# ~/projects — workspace instructions

This folder is a **container of independent projects**, not a monorepo. Each
subdirectory is its own git repo with its own stack, tests, and dependencies.
Never assume a change in one project affects another, and never run a build or
test command from this directory — always `cd` into the specific project first.

Projects with their own `CLAUDE.md` (currently `study-platform/`) override this
file. Treat this as the baseline; the project-level file wins on conflict.

## Project index

| Project | Stack | Test command |
|---|---|---|
| `study-platform/` | Next.js 16 + NestJS + FastAPI (see its own CLAUDE.md) | per-service |
| `CSA/` | Concept prototype for CSA Rotterdam IT Committee (see its own CLAUDE.md) | not scaffolded yet |
| `ai-automation/` | Python 3.10+, anthropic (`src/` layout, pkg `ai_automation`) | `pytest` |
| `deeper-apps-leads/` | Python 3.10+, requests/bs4/feedparser (`src/` layout, pkg `leadgen`) | `pytest` |
| `kalshi/` | Python 3.10+, requests, numpy, duckdb | `pytest` |
| `market-data-toolkit/` | Python 3.10+, stdlib-only (`src/` layout, pkg `mdt`) | `pytest` |
| `pairs-trading/` | Python 3.10+, numpy/statsmodels/PyWavelets/hmmlearn (`src/` layout, pkg `pairs`) | `pytest` |
| `lucas-hsu-website/` | Astro 7 + TypeScript | `npm test` (Playwright) |
| `lrl-systems/` | Next.js 16 + NestJS 11 monorepo, pnpm + Turborepo | `pnpm test` (Vitest), `pnpm test:e2e` (Playwright) |
| `fullhouse-hackathon-write-up-repo/` | Python, poker bot — archived write-up | n/a |
| `claude-code-setup/` | Bash — Claude Code bootstrap for new devices | n/a |

Default branch is `main` everywhere except `claude-code-setup` (`master`).

## Feature workflow

The standard loop for adding a feature:

1. `/plan` — restate the requirement, surface risks, produce a step plan. It
   **waits for explicit confirmation** before any code is written. Don't skip
   this on anything touching more than one file.
2. `/tdd` — tests first, then the minimal implementation that passes them.
3. `/verify` — mechanical gate: build → typecheck → lint → tests, in that order,
   stopping at the first failure.
4. `/code-review` — judgment gate: security and quality review of the diff.
   Different from `/verify` — green tests don't mean a good change.
5. `/learn` — optional, at the end of a session worth learning from.

Steps 3 and 4 are both needed and are not substitutes for each other.

Situational, **not** part of every feature:

- `/build-fix` — build or type errors are blocking
- `/refactor-clean` — periodic dead-code sweep, not per-feature
- `/test-coverage` — coverage dropped below 80%
- `/e2e` — user-facing flow changed (website only)
- `/orchestrate` — task genuinely needs several agents chained

## Tooling caveat: Python projects

The installed hooks and some commands are JS/TS-oriented. In `kalshi/`,
`market-data-toolkit/`, and `pairs-trading/`:

- The auto-format (Prettier), `tsc` check, and `console.log` hooks **do not
  fire** — they match `.ts/.tsx/.js/.jsx` only. Formatting is on you.
- `/test-coverage` assumes `npm test --coverage`. Use
  `pytest --cov` instead.
- `/verify` has no build or typecheck step to run; expect lint + `pytest` only.

All three use pytest with `testpaths = ["tests"]`. `market-data-toolkit` and
`pairs-trading` are `src/`-layout (`pythonpath = ["src"]`), `kalshi` is flat
(`pythonpath = ["."]`).

## Conventions

- `market-data-toolkit` is deliberately **stdlib-only** in its runtime
  dependencies. Do not add a runtime dependency to it without asking — dev
  extras (`pytest`, `pytest-cov`) are fine.
- `kalshi` is paper-trading only. Anything that could place a real order needs
  an explicit go-ahead, not an inferred one.
- `deeper-apps-leads` scrapes third-party sites and stores personal data under
  GDPR. Two standing rules: robots.txt is honoured through `leadgen.robots`
  with no bypass on the crawling path, and the repo contains no message sender
  — outreach is rendered and reviewed by hand. Both need an explicit
  go-ahead to change, not an inferred one.
- Don't create new `.md` files for documentation — a hook blocks it. Put
  documentation in the project's existing `README.md`.

## Git — standing permission

Committing and merging no longer need to be asked for. Granted 2026-08-10,
replacing the previous "commit only when asked" rule.

- **Commit freely**, at sensible checkpoints, without confirming first.
- **Merge freely** — branch for anything non-trivial, then merge back when the
  work is green. Branching first on the default branch is still the habit, but
  a direct commit to `main` is fine for small or self-contained changes.
- **Pushing still gets confirmed.** A push is outward-facing: it publishes, and
  what lands on a remote can be cached or indexed even if later deleted. Same
  for opening PRs. Ask first. (Most repos here have no remote configured, so
  this rarely comes up.)
- Never commit secrets or operational data. Every project's `.gitignore`
  already excludes `.env`, `*.db`, `cache/` and `exports/` — check `git status`
  before a first commit in a new repo rather than trusting that blindly.
- Commit messages: say why, not just what. End with the `Co-Authored-By` line.
