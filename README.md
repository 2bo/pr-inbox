# pr-inbox

A Claude Code mod that turns your review requests and your own pull requests into an inbox, ordered by what needs you next: AI summary and risk, an AI review that can approve, a reader for the description and the diff, merging (stacks included), and CI fixes with Claude.

![The To review tab: review requests with their risk, how long they have waited, CI and AI review; the bots under their heading; the PRs you approved with why they are still open; and the selected PR's summary and release impact below](docs/screenshot.png)

- **To review**: review requests, the longest-waiting first, then bots' under their own heading, then the PRs you approved that are not merged yet. Each request gets an AI summary, a risk level and its impact on release
- **My PRs**: what needs you (changes requested, CI failed, conflict), then what is ready to merge, what is in review, and what has gone quiet
- A status line under the prompt keeps the counts in view, and new review requests come as a toast and an OS notification

Tested with Claude Code v2.1.289. Mods need v2.1.287 or later.

## Requirements

- [GitHub CLI](https://cli.github.com/), signed in with `gh auth login`. The mod reads, approves and merges through `gh`, as the account it is signed in to
- Optional: [gh stack](https://github.com/github/gh-stack) (`gh extension install github/gh-stack`) to merge stacked PRs, and [ghq](https://github.com/x-motemen/ghq) so `c` can find (or fetch) your clone of a repository

## Install

In Claude Code:

```
/plugin marketplace add 2bo/pr-inbox
/plugin install pr-inbox@pr-inbox
```

Or from the shell: `claude plugin marketplace add 2bo/pr-inbox && claude plugin install pr-inbox@pr-inbox`.

## First run

1. **Before anything else**: by default each review request is analyzed as soon as Claude Code starts, which sends its title, description and diff to the model you use (see [What is sent](#security)). For work code, set `analysis` to `when opened` or `off`, or narrow it with `org_filter`, first (`/config`)
2. The status line appears under the prompt: `review 3 ⚙2 · ▲1 high │ mine ✗1 fix · ✓1 ready · …2 in review`
3. `/pr-inbox` opens the pane. Keys reach it while it has the focus: `ctrl+x tab` moves between the prompt and the pane, `Esc` goes back to the prompt
4. `u` shows every key and what each mark means. A key that does nothing for the selected PR says why

## Reading the list

One line per PR. From left to right:

| Column | Marks |
| :- | :- |
| Marks | `▸` selected · `●` updated since you last selected it · `⚙` a bot · `┌ ├ └` a stack, bottom (on the base branch) to top |
| RISK (To review) | `▲ HIGH` · `◆ MED` · `○ LOW` from the analysis · `…` analyzing · `·` not analyzed |
| STATE (My PRs) | `✗ FIX` needs you · `✓ RDY` ready to merge · `… REVW` in review · `◇ OLD` no update for `stale_days` · `⏸ SNZ` snoozed · `⟳ WIP` Claude is fixing its CI · `⇡ PUSH` a fix waits for your push |
| Approved by you | `↻ RE` changed since you approved (re-review) · `… REVW` waits on other reviews · `◌ CI` running · `✗ CI` / `✗ CONF` / `✗ CHG` what blocks it · `✓ RDY` ready to merge |
| PR, TITLE | Links to GitHub (Cmd+click in a terminal that supports hyperlinks) |
| AGE | `▰▱▱` how long it has waited: one cell at 4 hours, two at a day, three at three days |
| CI | `✓` passed · `✗` failed · `◌` running · `·` none. Judged from the latest run of each check, so a job that failed and then passed on a re-run counts as passed |
| AI | `✓` passed or approved · `✗` blocked · `?` passed, waits for you · `·` no AI review |

Under the list, the selected PR's details: the summary, the release impact, the reason, the AI review and, for your PRs, the failed checks. Nothing is folded: bots, the PRs you approved and old PRs each have a heading; only snoozed PRs wait behind `z`.

## Keys

**Anywhere**

| Key | Action |
| :- | :- |
| `j` / `k` | Next / previous PR |
| `1` / `2`, `h` / `l` | To review / My PRs, or the tab to the left / right |
| `d` | Read the PR (below) |
| `e` | Ask Claude to explain the PR, or for your own, to diagnose what blocks it. Claude reads the description, comments, reviews and linked issues, not only the diff, in a read-only turn |
| `o` | Open in the browser |
| `x` / `z` | Snooze the PR until it is updated / show snoozed PRs |
| `f` | Filter by repository, number, title or @author (Enter keeps it; an empty one clears it) |
| `r` | Fetch again |
| `u` | Every key and mark |
| `Esc` / `ctrl+x tab` | Back to the prompt (the pane stays open) / back to the pane |
| `q` | Close the pane (`/pr-inbox` opens it again) |

**On a review request**

| Key | Action |
| :- | :- |
| `a` | Approve, after you choose **Approve** in the dialog (Cancel is selected first). On a `↻ RE` PR, approves its new commit |
| `v` | AI review ([below](#ai-review-and-approve)). `v` again cancels it |
| `i` | Every finding of the AI review, with links to the lines; `n` pages them when they do not fit |
| `w` | AI review every bot PR not reviewed yet, then approve those that passed in one dialog (on the bots heading) |

**On your PR**

| Key | Action |
| :- | :- |
| `m` | Merge a PR that is ready, after picking a method. Pinned to the commit on screen. A PR in a stack merges with `gh stack merge`: the stack from its bottom up to that PR, all or nothing; the dialog names every PR that goes |
| `c` | CI failed: fix it with Claude in a worktree ([below](#fixing-ci)), or re-run the failed jobs |

**In the reader (`d`)**

The description comes first, then the diff one file at a time, drawn like Claude Code's own diffs. On a `↻ RE` PR, it opens at what changed since your approval.

| Key | Action |
| :- | :- |
| `h` / `l` | Previous / next page |
| `j` / `k` | Scroll by a block of lines (↑↓ and PgUp/PgDn scroll too) |
| `f` | The list of pages: `j` / `k` move, `l` or `1`-`9` open |
| `t` | On a `↻ RE` PR: the whole PR, or only what changed since your approval |
| `g` | Show a folded lockfile or generated file |
| `a` / `v` / `e` | Approve, review or explain without leaving |
| `n` | The next PR in the list |
| `q` | Back to the list |

`/pr-inbox refresh` fetches again and prints the counts without opening the pane.

## Fixing CI

`c` on your PR with a failed CI (or `/pr-inbox fix <repo#number>` from the prompt) lets Claude fix it:

1. The dialog names the failed checks and what will happen. Nothing starts until you choose **Fix with Claude**
2. pr-inbox finds your clone (the session's directory, or the one `ghq` knows, or `ghq get` after you agree) and makes a git worktree of its own at the PR's head: `~/.cache/pr-inbox/worktrees/<owner>/<repo>/pr-<n>`. Your checkout is not touched
3. Claude reads the failed logs, fixes, runs the tests and commits. The row shows `⟳ WIP`. It cannot push, merge, approve or comment: pr-inbox refuses those
4. When the turn ends, the dialog lists exactly the commits a push would send: **Push**, **Show the diff first**, or Cancel. A fix not pushed yet waits as `⇡ PUSH`, and `c` pushes it, shows it or forgets it

## AI review and approve

`v` on a review request runs a review from several perspectives, each an independent model call, and approves the PR when it passes:

1. **Gates, checked in code**: not a draft, CI passed (or there is none), no merge conflict, no reviewer requested changes
2. **Screening**: the description, diff and comments are checked for instructions aimed at an AI (prompt injection) by a small model, and the PR is checked for changes to AI instructions (CLAUDE.md, `.claude/` rules, skills, subagents and the like). What happens next depends on who decides: when the approval would go through without you (`ai_approve` `auto` for an author it applies to), any of these stops the review; when you approve in the dialog, the review goes on and they are shown as ⚠ warnings in the pane, the dialog and the transcript
3. **Reviewers**, in parallel on `review_model` (Sonnet by default). Each first says what else it needs to read (files at the PR head, code searches, upstream release notes); the mod checks the request, fetches and screens it, then the reviewer reviews:
   - Purpose & scope: does it do what the description and linked issues ask, without needless complexity or unrelated changes
   - Correctness & compatibility: bugs, breaking changes, migrations, rollback, performance
   - Tests: is the changed behavior tested
   - Security & secrets
   - Conventions: the repository's CLAUDE.md, AGENTS.md, REVIEW.md, CONTRIBUTING.md and patterns. These guides, the rules in `.claude/rules/`, and any AI instruction a reviewer asks for (skills, subagent definitions, commands, nested CLAUDE.md, Cursor or Copilot instructions) are read from the base branch, so a PR cannot rewrite the rules it is reviewed by. They talk to AI by design, so they are given apart from the PR content and not screened for injection
   - For **Dependabot and Renovate** PRs, instead: **Upgrade impact** (every package that changes, directly or in the lockfile; upstream release notes and changelogs; whether this repository uses what changed) and **Supply chain**
4. **Verification**: important findings (confidence 80+) go to a verifier that tries to refute them against the code
5. **Decision, in code**: it passes only when every gate holds, nothing looked like an injection, every reviewer answered, no important finding survived and the PR got no new commits. Nits do not block

Under the PR, the outcome comes first, then each perspective's conclusion in a sentence or two: ✓ no problems, ✗ blocks the approval, △ found something that does not block (low confidence, or refuted by the verifier), ? could not tell. `i` shows every finding with its evidence and a link to the line. The conclusions and findings are also written to the transcript.

Only problems within each reviewer's perspective count, and the same problem found from two perspectives is shown once. The result is kept for the reviewed commit, so it is still there after a restart; when new commits arrive, the row says the review is of an older commit.

When it passes, `ai_approve` decides: with `confirm` (default) nothing breaks in on what you are doing: the row and a toast say it passed, and `a` approves it, its dialog carrying the review's notes and warnings. `auto` approves at once for PRs from members and collaborators of the repository and from Dependabot or Renovate (the review on GitHub then says the pr-inbox AI review approved it on its own, and so do the toast and the pane), and leaves anyone else and forks to `a`. `w` reviews every bot PR without moving your selection, then asks once to approve those that passed, naming each commit. Every approval is pinned to the reviewed commit. A review stopped by a gate (draft, CI failing, conflict, changes requested) says it did not run.

A review makes about two Sonnet calls per perspective plus the verifier and several small screening calls, on your plan. It usually takes under a minute.

## Settings

Change them with `/config` or `/plugin configure`.

| Setting | Default | What it does |
| :- | :- | :- |
| `org_filter` | (empty) | Only show PRs in this GitHub organization |
| `stale_days` | 30 | List your PRs not updated for this many days under Old |
| `refresh_minutes` | 5 | How often to fetch from GitHub |
| `summary_model` | sonnet | The model that writes the summary, risk and release impact |
| `desktop_notify` | review requests | OS notifications for `review requests`, `all` (also approvals, changes requested and CI failures on your PRs) or `off`. Uses `osascript` on macOS and `notify-send` on Linux. On macOS, allow notifications for Script Editor in System Settings if none appear |
| `analysis` | auto | When review requests are analyzed: `auto` (from startup), `when opened` (once you open `/pr-inbox` in the session) or `off` |
| `ai_approve` | confirm | When the AI review passes: `confirm` (the row says so, and `a` approves) or `auto` |
| `theme` | dark | `dark` (neon) or `light` (deeper colors for a light terminal) |
| `glyphs` | unicode | `ascii` draws every mark as one plain character, for terminals that draw symbols such as ━ ● ◆ ⚙ two cells wide |
| `review_model` | sonnet | The model of the AI review |
| `review_purpose` / `review_correctness` / `review_tests` / `review_security` / `review_conventions` | (built-in) | Instructions for each reviewer. `off` skips that perspective |
| `review_dependency_impact` / `review_supply_chain` | (built-in) | The same, for Dependabot and Renovate PRs |
| `explain_prompt` | (built-in) | What `e` asks about a review request. `{url}` becomes the PR URL |
| `risk_high` / `risk_medium` / `risk_low` | (built-in) | What counts as each risk level in the analysis |
| `release_impact` | (built-in) | How to judge the impact on release (yes / no / unknown) |
| `language` | auto | The language of the AI summary, risk and release impact |

Leave the prompt settings empty to use the built-in text. Whatever you write, the mod still adds the instruction to read comments and linked issues (for `e`), and the rules that keep PR content untrusted and `e` read-only. Changing the criteria redoes the stored analyses.

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
  - When you press `e`, that turn runs under a read-only guard enforced by the mod: only Read, Grep, Glob and the read-only `gh pr view`, `gh pr diff`, `gh pr checks`, `gh issue view`, `gh run view`, `gh run list`, and `gh api` GET requests for a PR's or issue's comments and reviews can run. Edits, other commands, web access, subagents, approvals, comments and pushes are refused, even if your permission mode or allow rules would let them through. The guard ends with that turn; anything you ask next runs with your session's usual permissions
- **AI review (`v`).** Built along Anthropic's guidance on indirect prompt injection and the dual-LLM pattern. The approval is decided in code from the reviewers' structured answers, never by a model. The review's models have no tools: they cannot run commands, read local files, reach the network or write anything. They read only what the mod fetched from the PR under review (and, for dependency updates, upstream release notes and files on GitHub); what they ask to read is validated first. Content reaches them as JSON labeled as untrusted, screened for injected instructions, with invisible characters stripped. Any error, timeout or unparsable answer blocks the approval; a suspected injection blocks it when no person approves, and is a ⚠ warning when you do. `auto` is still a choice to trust an AI judgment: keep it to repositories where that is acceptable, and keep branch protection and required reviews as the last line
- **The analysis is a hint.** Do not approve on the strength of the risk or impact judgment. Approve runs only after you choose **Approve** in the confirmation dialog, which names the commit on screen. The approval is pinned to that commit, and it is refused if the PR got new commits in the meantime. Turning on "Dismiss stale pull request approvals" in your repositories' branch rules adds a second line of defense
- **Merging.** `m` merges only after you pick a method in its dialog, where Cancel is selected first. A single PR's merge is pinned to the commit on screen. A stack merge goes through `gh stack merge`, which cannot be pinned to commits: its dialog lists every PR that goes, and GitHub still applies your branch rules to each
- **Displayed text is sanitized.** Terminal escape sequences, control characters, bidirectional override characters and invisible characters are stripped from PR titles, author names, check names and model output before they are drawn. The diff (`d`) is drawn by Claude Code's own highlighter, line by line with the same characters stripped (tabs kept), and is never sent to a model. Links open only canonical `https://` URLs. Failed-check links point wherever the CI system says, which may be a third-party site
- **What is sent, and when.** With `analysis` on `auto`, as soon as Claude Code starts (including `claude -p` runs and sessions in other projects) and on every refresh, each review request that has not been analyzed yet is sent to the model Claude Code is configured with (Anthropic, or your Bedrock, Vertex or gateway setup), under your account: its repository and number, author, title, list of changed files, description (first 4,000 characters) and diff (first 30,000 characters). You do not have to open the pane. Follow your organization's rules for work code: narrow it with `org_filter`, or set `analysis` to `when opened` or `off`
- **What is stored locally.** In Claude Code's plugin store (`~/.claude/plugins/store/`): the URLs of your review requests and the state of your own PRs (to notice changes), each analysis (summary, risk, release impact), each AI review's findings, snoozed PRs and which updates you have seen. Analyses of PRs that are no longer open are deleted on the next refresh
- **Fixing CI (`c`).** The fix is an ordinary Claude turn with your session's permissions (your permission mode and allow rules apply), working in a separate worktree, never in your checkout. While it runs, pr-inbox refuses its `git push`, and `gh` merges, reviews, comments and other writes (`gh api` POST/PUT/PATCH/DELETE): those stay with you. The push dialog lists exactly the commits a push would send (those not on the branch as fetched), says when the turn was cut short, and a worktree with commits left from an earlier fix asks before going on. CI logs are written by tools and other people, so the request tells Claude to treat them as data. pr-inbox pushes only after you choose Push in its dialog, to the PR's own branch, never with force; your PRs from forks are left out
- **Access.** All GitHub access goes through `gh`; the mod holds no token. OS notifications go through `osascript` or `notify-send`, with the text passed as arguments, never as script. Commands run as argument lists, without a shell

## Development

```bash
pnpm install
claude --plugin-dir .   # run the working copy; loading once also writes the type declarations to .claude-plugin/types/ (needed by typecheck)
pnpm run check          # validate (--strict) → tsc → Biome → claude plugin test
```

`pnpm run demo` starts Claude Code with the mod against made-up PRs: a fake `gh` (`scripts/demo/gh`) answers every GitHub call, and a fake `ghq` knows no clone, so nothing real is read or written, and approvals and merges go nowhere. The mod's real state is set aside and put back when you `/exit`. It is also how the screenshot is taken.

Tests live in `tests/*.test.ts`. GitHub, the model, the store and the environment are all stubbed, so tests make no network calls.

## License

MIT
