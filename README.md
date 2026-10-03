# pr-inbox

A Claude Code mod that turns your review requests and your own pull requests into an inbox, ordered by what needs you next.

- A status line under the prompt keeps the counts in view (`👀 To review 3 (+2 bot) · ⚠ High risk 1 · 🔴 Needs action 1 · ✅ Ready 1 · ⏳ Waiting 2`)
- `/pr-inbox` opens a pane with two tabs
  - **To review**: review requests, the longest-waiting first. Each PR gets an AI summary, a risk level (low / medium / high) and its impact on release (visible to users / not visible / cannot tell), taking feature flags into account
  - **My PRs**: needs action (changes requested, CI failed, conflict) → ready to merge → waiting for review → stale. Failed CI checks are listed with links to their runs
- A toast tells you about new review requests, and when your PRs are approved, get changes requested or fail CI

![The To review tab: each review request with an AI summary, risk level and release impact](docs/screenshot.png)

Tested with Claude Code v2.1.288. Mods need v2.1.287 or later.

## Install

In Claude Code:

```
/plugin marketplace add 2bo/pr-inbox
/plugin install pr-inbox@pr-inbox
```

Or from the shell: `claude plugin marketplace add 2bo/pr-inbox && claude plugin install pr-inbox@pr-inbox`.

## Usage

| Key | Action |
| :- | :- |
| `1` / `2` | To review / My PRs |
| `j` / `k` | Select the next / previous PR |
| `e` | Ask Claude to explain the PR (for your own PR, to diagnose what blocks it) |
| `a` | Approve (runs only after you choose **Approve** in the confirmation dialog) |
| `o` | Open in the browser |
| `b` / `s` | Show or hide bot PRs / stale PRs |
| `r` | Fetch again |
| `Esc` | Close the pane |

PR numbers and failed checks are hyperlinks: Cmd+click them in a terminal that supports hyperlinks.

`/pr-inbox refresh` fetches again and prints the counts without opening the pane.

## Requirements

- [GitHub CLI](https://cli.github.com/), signed in with `gh auth login`. The mod fetches, diffs and approves PRs through `gh`, as the account `gh` is signed in to

## Settings

Change them with `/config` or `/plugin configure`.

| Setting | Default | What it does |
| :- | :- | :- |
| `org_filter` | (empty) | Only show PRs in this GitHub organization |
| `stale_days` | 30 | Fold your PRs not updated for this many days under Stale |
| `refresh_minutes` | 5 | How often to fetch from GitHub |
| `summary_model` | sonnet | The model that writes the summary, risk and release impact |
| `analysis` | auto | When review requests are analyzed: `auto` (from startup), `when opened` (once you open `/pr-inbox` in the session) or `off` |
| `language` | auto | The language of the AI summary, risk and release impact |

The menus are in English. The AI analysis and its labels follow `language`:

1. `language` set to anything other than `auto`, such as `English` or `Japanese`
2. Otherwise Claude Code's [`language`](https://code.claude.com/docs/en/settings-reference#language) setting
3. Otherwise the terminal locale (`LC_ALL`, `LC_MESSAGES`, then `LANG`)
4. Otherwise English

The labels are in Japanese when the language is Japanese, and in English otherwise. The analysis itself is written in whatever language is chosen.

The analysis calls the model once per PR, on your plan. Results are stored with the PR's update time and language, and are redone only when the PR changes or the language does. A failed analysis is retried after 15 minutes, then 30, 60 and 120, and then left until the PR changes. At most 30 analyses start in an hour.

When a PR is too large to read whole (more than 30,000 characters of diff, 4,000 of description or 300 files), the analysis says so (`judged on part of the PR`) and never rates it low risk.

## Security

- **PR content is untrusted input.** Anyone who can open a PR and request your review controls its title, body, diff and CI output, and may plant instructions aimed at the model
  - The analysis call has no tools and only returns text. The PR content is fenced with a random marker, and the model is told not to follow instructions in it. Invisible Unicode tag characters are removed first
  - When you press `e`, that turn runs under a read-only guard enforced by the mod: only Read, Grep, Glob and the read-only `gh pr view`, `gh pr diff`, `gh pr checks`, `gh run view` and `gh run list` can run. Edits, other commands, web access, subagents, approvals, comments and pushes are refused, even if your permission mode or allow rules would let them through. The guard ends with that turn; anything you ask next runs with your session's usual permissions
- **The analysis is a hint.** Do not approve on the strength of the risk or impact judgment. Approve runs only after you choose **Approve** in the confirmation dialog, which names the commit on screen. The approval is pinned to that commit, and it is refused if the PR got new commits in the meantime. Turning on "Dismiss stale pull request approvals" in your repositories' branch rules adds a second line of defense
- **Displayed text is sanitized.** Terminal escape sequences, control characters, bidirectional override characters and invisible characters are stripped from PR titles, author names, check names and model output before they are drawn. Links open only canonical `https://` URLs. Failed-check links point wherever the CI system says, which may be a third-party site
- **What is sent, and when.** With `analysis` on `auto`, as soon as Claude Code starts (including `claude -p` runs and sessions in other projects) and on every refresh, each review request that has not been analyzed yet is sent to the model Claude Code is configured with (Anthropic, or your Bedrock, Vertex or gateway setup), under your account: its repository and number, author, title, list of changed files, description (first 4,000 characters) and diff (first 30,000 characters). You do not have to open the pane. Follow your organization's rules for work code: narrow it with `org_filter`, or set `analysis` to `when opened` or `off`
- **What is stored locally.** In Claude Code's plugin store (`~/.claude/plugins/store/`): the URLs of your review requests and the state of your own PRs (to notice changes), and each analysis (summary, risk, release impact). Analyses of PRs that are no longer open are deleted on the next refresh
- **Access.** All GitHub access goes through `gh`; the mod holds no token. Commands run as argument lists, without a shell

## Development

```bash
pnpm install
claude --plugin-dir .   # run the working copy; loading once also writes the type declarations to .claude-plugin/types/ (needed by typecheck)
pnpm run check          # validate (--strict) → tsc → Biome → claude plugin test
```

Tests live in `tests/*.test.ts`. GitHub, the model, the store and the environment are all stubbed, so tests make no network calls.

## License

MIT
