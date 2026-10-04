#!/usr/bin/env bash
# Try pr-inbox against made-up PRs (pnpm run demo). The fake gh next to this script answers every GitHub call, so
# nothing real is read or written, and approvals and merges go nowhere.
# The mod's own state in Claude Code's plugin store is set aside first and put back when Claude Code exits.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
store="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/store"
backup="$(mktemp -d)"

shopt -s nullglob
mkdir -p "$store"
for f in "$store"/pr-inbox_inline-*.json; do mv "$f" "$backup/"; done

restore() {
  rm -f "$store"/pr-inbox_inline-*.json
  for f in "$backup"/*.json; do mv "$f" "$store/"; done
  rmdir "$backup"
}
trap restore EXIT

cd "$root"
PATH="$here:$PATH" claude --plugin-dir "$root" --settings '{"language":"English"}' "$@"
