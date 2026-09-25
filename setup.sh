#!/usr/bin/env bash
# One-shot Claude Code workflow setup for a new device.
# Installs the everything-claude-code plugin at user scope, and links this
# repo's skills/ into ~/.claude/skills, so every project on this machine gets them.
#
# Usage:  ./setup.sh
set -euo pipefail

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✔\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
die()  { printf '  \033[31m✘\033[0m %s\n' "$*" >&2; exit 1; }

bold "1/5 Checking prerequisites"

command -v node >/dev/null 2>&1 || die "Node.js is required. Install Node 18+ first (https://nodejs.org)."
NODE_MAJOR=$(node -p 'process.versions.node.split(".")[0]')
[ "$NODE_MAJOR" -ge 18 ] || die "Node >= 18 required, found $(node --version)."
ok "Node $(node --version)"

if ! command -v claude >/dev/null 2>&1; then
  warn "Claude Code not found — installing via npm..."
  npm install -g @anthropic-ai/claude-code
fi
ok "Claude Code $(claude --version)"

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  ok "GitHub CLI authenticated"
else
  warn "GitHub CLI missing or not authenticated (optional — needed for PR workflows). Run: gh auth login"
fi

bold "2/5 Adding plugin marketplace"
claude plugin marketplace add worldflowai/everything-claude-code || warn "everything-claude-code marketplace already added"

bold "3/5 Installing plugins (user scope — available in all projects)"
claude plugin install everything-claude-code@everything-claude-code --scope user

# NOTE: ruflo was trialled and deliberately removed on 2026-07-29. See
# "Why ruflo was removed" in README.md before reinstating it.

bold "4/5 Repairing ECC slash commands"
# 11 of ECC's 15 command files ship without YAML frontmatter, so Claude Code
# never registers them (/orchestrate, /verify, /code-review, ...). See the
# script header for detail.
"$(dirname "$0")/scripts/fix-ecc-commands.sh"

bold "5/5 Linking this repo's skills"
# Each skills/<name>/ here becomes a personal skill, available in every project on this
# device. A symlink rather than a copy, so a `git pull` in this repo updates it in place.
# The committed copies inside other repos are scripts/sync-skill.sh's job, not this one's.
mkdir -p "$HOME/.claude/skills"
for dir in "$(cd "$(dirname "$0")" && pwd)"/skills/*/; do
  [ -f "$dir/SKILL.md" ] || continue
  name="$(basename "$dir")"
  link="$HOME/.claude/skills/$name"
  if [ -L "$link" ] || [ ! -e "$link" ]; then
    ln -sfn "${dir%/}" "$link"
    ok "$name"
  else
    warn "$link exists and is not a symlink, so it was left alone"
  fi
done

bold "Verifying"
claude plugin list

bold "Done."
echo
echo "Restart Claude Code (fully quit the desktop app) to load the plugin,"
echo "commands, agents, and hooks."
echo
echo "See README.md in this repo for what each piece does and how to update."
