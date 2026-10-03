# pr-inbox

A Claude Code mod that turns your review requests and your own pull requests into an inbox, ordered by what needs you next.

- A status line under the prompt keeps the counts in view (`👀 To review 0 (+2 bot) · ⚠ High risk 1 · 🔴 Needs action 2 · ✅ Ready 0 · ⏳ Waiting 9`)
- `/pr-inbox` opens a pane with two tabs
  - **To review**: review requests, the longest-waiting first. Each PR gets an AI summary, a risk level (low / medium / high) and its impact on release (visible to users / not visible / cannot tell), taking feature flags into account
  - **My PRs**: needs action (changes requested, CI failed, conflict) → ready to merge → waiting for review → stale. Failed CI checks are listed with links to their runs
- A toast tells you about new review requests, and when your PRs are approved, get changes requested or fail CI

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
| `language` | auto | The language of the AI summary, risk and release impact |

The menus are in English. The AI analysis and its labels follow `language`:

1. `language` set to anything other than `auto`, such as `English` or `Japanese`
2. Otherwise Claude Code's [`language`](https://code.claude.com/docs/en/settings-reference#language) setting
3. Otherwise the terminal locale (`LC_ALL`, `LC_MESSAGES`, then `LANG`)
4. Otherwise English

The labels are in Japanese when the language is Japanese, and in English otherwise. The analysis itself is written in whatever language is chosen.

The analysis calls the model once per PR, on your plan. Results are stored with the PR's update time and language, and are redone only when the PR changes or the language does.

## Security

- **PR content is untrusted input.** Anyone can open a PR and request your review, so the title, body and diff may carry instructions aimed at the model
  - The analysis call has no tools and only returns text. It is told not to follow instructions in the PR
  - When you press `e`, the request to Claude always says not to follow instructions in the PR and to use only read-only `gh` commands: no other commands, file changes, pushes, approvals or comments. Claude still runs with your session's permissions, so keep your permission mode as careful as usual
- **The analysis is a hint.** Do not approve on the strength of the risk or impact judgment. Approve runs only after you choose **Approve** in the confirmation dialog, which names the commit on screen. The approval is pinned to that commit, and it is refused if the PR got new commits in the meantime
- **Displayed text is sanitized.** Terminal escape sequences, control characters, bidirectional override characters and invisible characters are stripped from PR titles, author names, check names and model output before they are drawn
- **Where your code goes.** The diff of each review request (its first 30,000 characters) is sent to your own Claude for analysis. Follow your organization's rules when you use it on work code
- **Access.** All GitHub access goes through `gh`; the mod holds no token. Commands run as argument lists, without a shell

## Development

```bash
pnpm install
claude --plugin-dir .   # run the working copy; loading once also writes the type declarations to .claude-plugin/types/ (needed by typecheck)
pnpm run check          # validate (--strict) → tsc → Biome → claude plugin test
```

Tests live in `tests/*.test.ts`. GitHub, the model, the store and the environment are all stubbed, so tests make no network calls.
