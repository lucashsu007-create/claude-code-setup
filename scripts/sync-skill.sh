#!/usr/bin/env bash
# Copy one of this repo's skills into every git repo under ~/projects and commit it there.
#
#   scripts/sync-skill.sh <skill> [--dry-run]
#
# skills/<skill>/ in this repo is the source of truth. On a machine that ran setup.sh it is
# also a personal skill (~/.claude/skills/<skill> is a symlink back here), and a personal
# skill takes precedence over a project skill with the same name. The copies made here, at
# <repo>/.claude/skills/<skill>/, are for everywhere else: cloud sessions and other machines
# only see what a repo has committed. Re-run after every change to the skill, so the copies
# never drift from the source.
#
# Per git repo directly under $PROJECTS_DIR (default ~/projects):
#   this repo                 .claude/skills/<skill> is a relative symlink to skills/<skill>
#   on its default branch     copy, then commit only the skill's path
#   on any other branch       commit on the default branch through a temporary worktree, so
#                             the checked-out branch and any uncommitted work stay untouched
#   no commits yet            copy only; it goes in with the repo's first commit
#   skip_reason() below       left alone, with the reason printed
#   branch_only() below       committed to a local branch chore/<skill>-skill cut from the
#                             remote default branch; pushing and opening the PR stay manual
#   worktrees, plain folders  ignored
#
# It never pushes. Pre-commit hooks run as usual; a failed commit is reported, not bypassed.
# Set SYNC_COMMIT_TRAILER to append a trailer (e.g. a Co-Authored-By line) to each message.
set -euo pipefail

skill="${1:-}"
dry=""
[ "${2:-}" = "--dry-run" ] && dry=1
if ! [[ "$skill" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "usage: $0 <skill> [--dry-run]" >&2
  exit 2
fi

setup="$(cd "$(dirname "$0")/.." && pwd)"
src="$setup/skills/$skill"
projects="${PROJECTS_DIR:-$HOME/projects}"
path=".claude/skills/$skill"
[ -f "$src/SKILL.md" ] || { echo "no skill at $src" >&2; exit 1; }

skip_reason() {
  case "$1" in
    csa-main) echo "CSAEUR organisation repo, read-only (see ~/projects/CLAUDE.md)" ;;
    claude-video) echo "vendored upstream clone; a local commit would fork it" ;;
    *) return 1 ;;
  esac
}

branch_only() {
  case "$1" in
    study-platform) echo "its CLAUDE.md says never work on main, and pushing main deploys" ;;
    csa-platform) echo "main belongs to the build orchestrator; changes arrive as pull requests" ;;
    *) return 1 ;;
  esac
}

default_branch() {
  local ref b
  ref="$(git -C "$1" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [ -n "$ref" ]; then echo "${ref#origin/}"; return; fi
  for b in main master; do
    if git -C "$1" show-ref -q --verify "refs/heads/$b"; then echo "$b"; return; fi
  done
  git -C "$1" branch --show-current
}

# sync_repo runs inside an `if`, where bash ignores set -e, so every step checks itself.
copy_into() {
  rm -rf "${1:?}/$path" &&
    mkdir -p "$1/.claude/skills" &&
    cp -R "$src" "$1/$path" &&
    find "$1/$path" -name __pycache__ -type d -prune -exec rm -rf {} +
}

# Commit the skill's path alone, whatever else is staged. Prints "same", "added" or "updated".
commit_in() {
  local verb
  git -C "$1" add -A -- "$path" || return 1
  if git -C "$1" diff --cached --quiet -- "$path"; then echo same; return; fi
  if git -C "$1" cat-file -e "HEAD:$path" 2>/dev/null; then verb=Update; else verb=Add; fi
  git -C "$1" commit -q -m "$verb the $skill skill" -m "Copied from claude-code-setup/skills/$skill by scripts/sync-skill.sh, so
cloud sessions and other machines working in this repo have it too. Where
the personal skill is installed it takes precedence, and this copy is kept
identical to it." ${SYNC_COMMIT_TRAILER:+-m "$SYNC_COMMIT_TRAILER"} -- "$path" >&2 || return 1
  [ "$verb" = Add ] && echo added || echo updated
}

report() { printf '%-9s %-36s %s\n' "$1" "$2" "${3:-}"; }

sync_repo() {
  local repo="$1" name default current branch base why="" tree tmp="" result
  name="$(basename "$repo")"

  if why="$(skip_reason "$name")"; then report skip "$name" "$why"; return 0; fi

  if [ "$repo" = "$setup" ]; then
    if [ -n "$dry" ]; then report would "$name" "link $path -> ../../skills/$skill"; return 0; fi
    mkdir -p "$repo/.claude/skills" && ln -sfn "../../skills/$skill" "$repo/$path" || return 1
    result="$(commit_in "$repo")" || return 1
    report "$result" "$name" "symlink to skills/$skill"
    return 0
  fi

  if ! git -C "$repo" rev-parse -q --verify HEAD >/dev/null; then
    if [ -n "$dry" ]; then result=would; else copy_into "$repo" || return 1; result=copied; fi
    report "$result" "$name" "no commits yet, so it goes in with the first commit"
    return 0
  fi

  default="$(default_branch "$repo")"
  current="$(git -C "$repo" branch --show-current)"
  branch="$default"
  if why="$(branch_only "$name")"; then branch="chore/$skill-skill"; fi

  if [ -n "$dry" ]; then
    report would "$name" "commit on $branch${why:+ (local branch: $why)}"
    return 0
  fi

  if [ "$current" = "$branch" ]; then
    tree="$repo"
  else
    tmp="$(mktemp -d)"
    tree="$tmp/wt"
    # A pull-request branch starts from the remote's default branch: the local one can hold
    # unpushed work (csa-platform's did, 23 commits), which the PR would otherwise publish.
    base="$default"
    if [ -n "$why" ] && git -C "$repo" show-ref -q --verify "refs/remotes/origin/$default"; then
      base="origin/$default"
    fi
    if git -C "$repo" show-ref -q --verify "refs/heads/$branch"; then
      git -C "$repo" worktree add -q "$tree" "$branch" || { rmdir "$tmp"; return 1; }
    else
      git -C "$repo" worktree add -q --no-track -b "$branch" "$tree" "$base" || { rmdir "$tmp"; return 1; }
    fi
  fi

  result=failed
  if copy_into "$tree"; then result="$(commit_in "$tree")" || result=failed; fi
  if [ -n "$tmp" ]; then
    git -C "$repo" worktree remove --force "$tree"
    rmdir "$tmp"
  fi
  [ "$result" != failed ] || return 1
  report "$result" "$name" "on $branch${why:+ (local branch: $why)}"
}

status=0
for repo in "$projects"/*/; do
  repo="${repo%/}"
  [ -d "$repo/.git" ] || continue # plain folders, and linked worktrees (their .git is a file)
  if ! sync_repo "$repo"; then
    report FAILED "$(basename "$repo")" "see the git output above; nothing was pushed"
    status=1
  fi
done
exit "$status"
