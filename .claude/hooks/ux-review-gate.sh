#!/bin/sh
# PreToolUse hook on Bash: before `gh pr create`, require a UX review (the ux-reviewer subagent) of the current HEAD
# when the branch changes what users see. Fails open: without jq or git, or outside a repository, it allows.
#
#   ux-review-gate.sh        read the PreToolUse JSON on stdin; print a deny decision or nothing
#   ux-review-gate.sh diff   write the branch's diff for the ux-reviewer subagent (it has no shell) and print its path
#   ux-review-gate.sh mark   record that HEAD has been UX reviewed

USER_FACING='^(hooks/|\.claude-plugin/plugin\.json$|README\.md$|scripts/demo/)'

command -v git >/dev/null 2>&1 || exit 0

marker_dir() {
  git rev-parse --git-path ux-review 2>/dev/null
}

base_ref() {
  for ref in origin/main main; do
    if git rev-parse --verify --quiet "$ref" >/dev/null; then
      echo "$ref"
      return 0
    fi
  done
  return 1
}

if [ "${1:-}" = "diff" ]; then
  base=$(base_ref) || { echo "no origin/main or main to compare with" >&2; exit 1; }
  dir=$(marker_dir) || exit 1
  mkdir -p "$dir" && git diff "$base...HEAD" >"$dir/review.diff" && echo "$dir/review.diff"
  exit 0
fi

if [ "${1:-}" = "mark" ]; then
  head=$(git rev-parse HEAD 2>/dev/null) || { echo "not in a git repository" >&2; exit 1; }
  dir=$(marker_dir) || exit 1
  mkdir -p "$dir" && : >"$dir/$head" && echo "UX review recorded for $head"
  exit 0
fi

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
# Only a real call: a command (after ; && || | or a newline, env assignments allowed) that is gh … pr … create, so
# gh -R owner/repo pr create counts and echo 'gh pr create' does not. Quoted text is blanked first (to Q), so a
# separator or a gh inside quotes is never taken for a command
printf '%s\n' "$cmd" |
  awk '{
    out = ""
    for (i = 1; i <= length($0); i++) {
      c = substr($0, i, 1)
      if (q != "") { if (c == q) { q = ""; out = out "Q" }; continue }
      if (c == "\\") { i++; out = out "Q"; continue }
      if (c == "\047" || c == "\"") { q = c; continue }
      if (c == ";" || c == "&" || c == "|") c = "\n"
      out = out c
    }
    print out
  }' |
  grep -Eq '^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*gh([[:space:]]+[^[:space:]]+)*[[:space:]]+pr([[:space:]]+[^[:space:]]+)*[[:space:]]+create([[:space:]]|$)' ||
  exit 0

cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$cwd" ] && cd "$cwd" 2>/dev/null
head=$(git rev-parse HEAD 2>/dev/null) || exit 0

base=$(base_ref) || exit 0

# Both sides of a rename, and paths as they are (-z: not quoted when they are not ASCII)
git diff --name-only --no-renames -z "$base...HEAD" 2>/dev/null | tr '\0' '\n' | grep -Eq "$USER_FACING" || exit 0

dir=$(marker_dir) || exit 0
[ -f "$dir/$head" ] && exit 0

short=$(git rev-parse --short HEAD)
reason="This branch changes what pr-inbox users see (hooks/, .claude-plugin/plugin.json, README.md or scripts/demo/), and HEAD ($short) has no UX review yet. Before creating the PR:
1. Write the diff with \`.claude/hooks/ux-review-gate.sh diff\` and run the ux-reviewer subagent, giving it the path it prints (the subagent has no shell).
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
