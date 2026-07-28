#!/usr/bin/env bash
# One-shot Claude Code workflow setup for a new device.
# Installs the everything-claude-code plugin and the ruflo plugin suite
# at user scope, so every project on this machine gets them.
#
# Usage:  ./setup.sh
set -euo pipefail

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✔\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
die()  { printf '  \033[31m✘\033[0m %s\n' "$*" >&2; exit 1; }

bold "1/4 Checking prerequisites"

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

bold "2/4 Adding plugin marketplaces"
claude plugin marketplace add worldflowai/everything-claude-code || warn "everything-claude-code marketplace already added"
claude plugin marketplace add ruvnet/ruflo || warn "ruflo marketplace already added"

bold "3/4 Installing plugins (user scope — available in all projects)"
claude plugin install everything-claude-code@everything-claude-code --scope user

# Baseline ruflo plugin set. See README for the other 30+ optional plugins.
for p in ruflo-core ruflo-swarm ruflo-rag-memory ruflo-workflows; do
  claude plugin install "$p@ruflo" --scope user
done

bold "4/4 Verifying"
claude plugin list

bold "Done."
echo
echo "Optional, per project: run the FULL ruflo harness (MCP server, hooks, 98 agents)"
echo "inside a project directory with:"
echo
echo "    npx ruflo init"
echo
echo "See README.md in this repo for what each piece does and how to update."
