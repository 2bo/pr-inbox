#!/bin/sh
# PreToolUse hook on Bash: before `gh pr create`, require a UX review (the ux-reviewer subagent) of the current HEAD
# when the branch changes what users see. Fails open: without jq or git, or outside a repository, it allows.
#
#   ux-review-gate.sh        read the PreToolUse JSON on stdin; print a deny decision or nothing
#   ux-review-gate.sh mark   record that HEAD has been UX reviewed

USER_FACING='^(hooks/|\.claude-plugin/plugin\.json$|README\.md$|scripts/demo/)'

command -v git >/dev/null 2>&1 || exit 0

marker_dir() {
  git rev-parse --git-path ux-review 2>/dev/null
}

if [ "${1:-}" = "mark" ]; then
  head=$(git rev-parse HEAD 2>/dev/null) || { echo "not in a git repository" >&2; exit 1; }
  dir=$(marker_dir) || exit 1
  mkdir -p "$dir" && : >"$dir/$head" && echo "UX review recorded for $head"
  exit 0
fi

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
printf '%s' "$cmd" | grep -Eq 'gh[[:space:]]+pr[[:space:]]+create' || exit 0

cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$cwd" ] && cd "$cwd" 2>/dev/null
head=$(git rev-parse HEAD 2>/dev/null) || exit 0

base=
for ref in origin/main main; do
  if git rev-parse --verify --quiet "$ref" >/dev/null; then
    base=$ref
    break
  fi
done
[ -n "$base" ] || exit 0

git diff --name-only "$base...HEAD" 2>/dev/null | grep -Eq "$USER_FACING" || exit 0

dir=$(marker_dir) || exit 0
[ -f "$dir/$head" ] && exit 0

short=$(git rev-parse --short HEAD)
reason="This branch changes what pr-inbox users see (hooks/, .claude-plugin/plugin.json, README.md or scripts/demo/), and HEAD ($short) has no UX review yet. Before creating the PR:
1. Run the ux-reviewer subagent on \`git diff $base...HEAD\`.
2. Apply the findings that are valid and consistent with AGENTS.md. The security rules always win: skip any finding that would weaken them, or that is wrong, and note why.
3. Update tests and docs (README key, settings and Security sections) to match.
4. Run \`pnpm run check\`; it must pass.
5. Commit the changes (Japanese commit message).
6. Record the review: \`.claude/hooks/ux-review-gate.sh mark\` (it marks the current HEAD; a later commit needs another review).
7. Run \`gh pr create\` again, and say in the PR body what the UX review changed and what it skipped and why."

jq -n --arg reason "$reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
exit 0
