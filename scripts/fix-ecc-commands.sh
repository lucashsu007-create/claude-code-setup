#!/usr/bin/env bash
# Repair everything-claude-code's unregistered slash commands.
#
# WHY: Claude Code only registers a .md file as a slash command if it begins
# with a YAML frontmatter block. 11 of ECC's 15 command files ship without one,
# so /orchestrate, /verify, /code-review, /learn and others silently never
# appear. This copies those files into ~/.claude/commands/ with the missing
# frontmatter prepended.
#
# Writing to ~/.claude/commands/ (rather than patching the plugin in place)
# means the fix survives `claude plugin update`. Re-run this after an update to
# pick up upstream edits to the command bodies.
#
# Usage: ./scripts/fix-ecc-commands.sh
set -euo pipefail

SRC="$HOME/.claude/plugins/marketplaces/everything-claude-code/commands"
DEST="$HOME/.claude/commands"

[ -d "$SRC" ] || { echo "✘ ECC plugin not found at $SRC — run ./setup.sh first." >&2; exit 1; }
mkdir -p "$DEST"

# description lines for the commands that ship without frontmatter
describe() {
  case "$1" in
    build-fix)       echo "Incrementally fix build and TypeScript errors one at a time, re-running the build after each fix." ;;
    checkpoint)      echo "Create, verify, or list workflow checkpoints backed by git and .claude/checkpoints.log." ;;
    code-review)     echo "Security and quality review of uncommitted changes, reporting CRITICAL/HIGH/MEDIUM findings with fixes." ;;
    eval)            echo "Define, check, and report eval criteria for a feature (capability and regression evals)." ;;
    learn)           echo "Extract reusable patterns from the current session and save them as skills." ;;
    orchestrate)     echo "Run a sequential multi-agent workflow: feature, bugfix, refactor, security, or a custom agent chain." ;;
    refactor-clean)  echo "Find and safely remove dead code via knip, depcheck, and ts-prune, verifying tests around each deletion." ;;
    test-coverage)   echo "Analyze test coverage, generate missing tests, and bring the project to the 80% threshold." ;;
    update-codemaps) echo "Regenerate token-lean architecture codemaps from imports and exports." ;;
    update-docs)     echo "Sync contributor and runbook documentation from package.json and .env.example." ;;
    verify)          echo "Run build, typecheck, lint, tests, and a console.log audit in order, stopping at the first failure." ;;
    *)               echo "" ;;
  esac
}

fixed=0
skipped=0

for path in "$SRC"/*.md; do
  name="$(basename "$path" .md)"

  # already has frontmatter -> the plugin registers it fine, leave it alone
  if head -1 "$path" | grep -q '^---$'; then
    skipped=$((skipped + 1))
    continue
  fi

  desc="$(describe "$name")"
  if [ -z "$desc" ]; then
    echo "  ? no description mapped for '$name' — skipping"
    continue
  fi

  {
    printf -- '---\n'
    printf 'description: %s\n' "$desc"
    printf -- '---\n\n'
    cat "$path"
  } > "$DEST/$name.md"

  echo "  ✔ /$name"
  fixed=$((fixed + 1))
done

echo
echo "Repaired $fixed command(s) into $DEST; $skipped already worked."
echo "Restart Claude Code (fully quit the desktop app) to load them."
