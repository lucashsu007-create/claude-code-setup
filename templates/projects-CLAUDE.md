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
| `kalshi/` | Python 3.10+, requests, numpy, duckdb | `pytest` |
| `market-data-toolkit/` | Python 3.10+, stdlib-only (`src/` layout, pkg `mdt`) | `pytest` |
| `lucas-hsu-website/` | Astro 7 + TypeScript | `npm test` (Playwright) |
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

The installed hooks and some commands are JS/TS-oriented. In `kalshi/` and
`market-data-toolkit/`:

- The auto-format (Prettier), `tsc` check, and `console.log` hooks **do not
  fire** — they match `.ts/.tsx/.js/.jsx` only. Formatting is on you.
- `/test-coverage` assumes `npm test --coverage`. Use
  `pytest --cov` instead.
- `/verify` has no build or typecheck step to run; expect lint + `pytest` only.

Both Python projects use pytest with `testpaths = ["tests"]`.
`market-data-toolkit` is `src/`-layout (`pythonpath = ["src"]`), `kalshi` is
flat (`pythonpath = ["."]`).

## Conventions

- `market-data-toolkit` is deliberately **stdlib-only** in its runtime
  dependencies. Do not add a runtime dependency to it without asking — dev
  extras (`pytest`, `pytest-cov`) are fine.
- `kalshi` is paper-trading only. Anything that could place a real order needs
  an explicit go-ahead, not an inferred one.
- Don't create new `.md` files for documentation — a hook blocks it. Put
  documentation in the project's existing `README.md`.
- Commit only when asked. If on the default branch, branch first.
