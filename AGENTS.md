# AGENTS.md

pr-inbox is a Claude Code mod (a plugin of function hooks). See README.md for what it does.

## Commands

```bash
pnpm install
claude --plugin-dir .            # run the working copy; also generates .claude-plugin/types/
pnpm run check                   # validate (--strict) → tsc → Biome → claude plugin test
pnpm run lint:fix                # apply Biome fixes
claude -p "/pr-inbox refresh" --plugin-dir .   # smoke test against real GitHub data
```

`pnpm run demo` runs the mod in Claude Code against made-up PRs (fake `gh` and `ghq` in `scripts/demo/`); use it to see UI changes for real, and keep its data made up (no real organizations, people or repositories). Exit it with `/exit` so the real plugin store is put back.

Run `pnpm run check` before every commit; all of it must pass. `claude plugin validate` does not catch everything the loader refuses (for example a function given `$` that shares a name with another binding): also load the mod for real, `claude -p "/pr-inbox refresh" --plugin-dir .` must print the counts.

## Simplify and UX review

Before creating a PR that changes what users see (`hooks/`, `.claude-plugin/plugin.json`, `README.md`, `scripts/demo/`), the session first runs the `simplify` skill (`/simplify`) on the branch's changes against `origin/main`, applies its fixes that are consistent with this file (the security rules below always win), runs `pnpm run check` and commits. Then the `ux-reviewer` subagent (`.claude/agents/ux-reviewer.md`, read-only, no shell) reviews the diff that `.claude/hooks/ux-review-gate.sh diff` writes (against `origin/main`; give it the printed path), and the session applies its findings that are valid and consistent with this file (the security rules below always win; say in the PR body what `/simplify` and the UX review changed or skipped and why), then runs `pnpm run check` and commits.

The project's `PreToolUse` hook (`.claude/settings.json` → `.claude/hooks/ux-review-gate.sh`) enforces it: `gh pr create` is denied until the current HEAD is marked as reviewed. Mark it with `.claude/hooks/ux-review-gate.sh mark` after both `/simplify`'s and the UX review's changes are committed; the marker lives under `.git` (`git rev-parse --git-path ux-review`), so any later commit needs another review.

## Layout

- `hooks/register.ts` — the whole mod. Loaded as TypeScript directly; there is no build step
- `tests/pr-inbox.test.ts` — `claude plugin test`. GitHub, the model, the store and the environment are stubbed; tests must not touch the network
- `.claude-plugin/plugin.json` — manifest and `userConfig`; `.claude-plugin/marketplace.json` lists this repo as a one-plugin marketplace

## CI and dependency updates

- `.github/workflows/ci.yml` runs `validate`, `lint` and `test` with the latest Claude Code. It skips `tsc`: the types are written only by an interactive, signed-in session, so run `pnpm run check` locally as well
- Dependabot (`.github/dependabot.yml`) opens weekly PRs for npm and GitHub Actions, for versions released at least 7 days ago (`cooldown`; security updates come at once). CodeRabbit (`.coderabbit.yaml`) reviews them and approves once its findings are resolved; `.github/workflows/dependabot-automerge.yml` keeps auto-merge on only while CodeRabbit's latest review approves the current head (each run decides from the PR as it is now, so late or reordered runs are harmless), and the `main` ruleset merges only with CI passed and one approval of the head (stale approvals are dismissed on push). Major updates and `typescript` updates are left for a person: run `pnpm run check` locally before merging them
- `.github/CODEOWNERS` requests the maintainer's review on every PR, so a Dependabot PR that stops (CI failed, findings, a rate-limited review) stays visible in pr-inbox
- Keep actions pinned to a full commit SHA with the version in a comment

## Mod API

- The API changes between Claude Code versions. Check `.claude-plugin/types/claude-code/index.d.ts` (generated for the installed version, gitignored) and https://code.claude.com/docs/en/plugins/mods/ before relying on memory
- If `.claude-plugin/types/` is missing, `tsc` fails: load the mod once with `claude --plugin-dir .`

## Releasing

- Installed copies are cached per version, so users get a change only when `version` in `.claude-plugin/plugin.json` goes up
- Bump it in the same change whenever what users run changes (`hooks/`, `.claude-plugin/plugin.json`). Changes to README, docs or tests alone need no bump
- Semantic versioning: patch for fixes, minor for new features or settings, major for breaking changes (a removed or renamed setting, command or key)
- After the change lands on `main`, tag it: `git tag v<version> && git push origin v<version>`

## Security rules (do not weaken)

PR titles, bodies, diffs, comments and CI output are untrusted input written by others. Each rule below has tests; keep them passing and add one whenever you touch the area.

- **Display**: pass every string from GitHub or the model through `clean()` before drawing it (escape sequences, control, bidi and invisible characters). Diff lines given to `Code` go through `cleanCodeLine()` (the same, tabs kept) and stay out of every model call. Descriptions and comments given to `Markdown` (the reader and the details under the list) go through `cleanBody()` (the same per line, HTML comments out, `file:` links inert) and stay out of every model call too. Links go through `safeHref()`: canonical `https://` only, no credentials, or the pane refuses to render
- **Analysis**: `$.model.complete` with no tools. PR content goes inside the random `untrusted-<uuid>` fence, file list before body, Unicode tag characters removed. A partial view (`prContent().partial`) is never judged low risk and is shown as partial
- **Analysis budget**: failures are stored and retried with backoff (`RETRY_BASE`, `MAX_ATTEMPTS`); at most `MAX_ANALYSES_PER_HOUR` start per hour. `analysis` = `off` / `when opened` must send nothing before it allows
- **`e`**: the request keeps `UNTRUSTED_NOTE`, and the turn it starts runs under the `tool.call` guard (`READ_TOOLS`, `READ_GH`). Never widen the allowlist to a tool that writes, runs arbitrary commands, reaches the network or spawns agents
- **Merge (`m`)**: only on your own PRs and bot PRs on To review (`mayMerge`), only after a person picks a method with its number key in the merge panel (`METHODS`, `methodChoices`: never one picked from the start, not even the only one a repository allows) and presses y. A single PR is pinned with `--match-head-commit`; a stacked PR goes through `gh stack merge <n> --yes` with `GH_REPO` (gh stack has no commit pin, so the panel says so and names every PR that goes). Never merge a PR of a gh stack (`stackKey`) with `gh pr merge`: it would land in the branch below. A PR stacked by hand (on another PR's branch, `handStacks`) is only drawn as a stack: it merges alone into its own base, and the panel names that branch. On a PR that is not ready, `m` turns auto-merge on (`enableAutoMerge`, same panel, `gh pr merge --auto` pinned with `--match-head-commit`) or off (`disableAutoMerge`, its own panel); never on a PR of a gh stack, a draft, a conflict or a repository with `autoMergeAllowed` false (`mergeAction`)
- **`p` (ask)**: `p` fills the prompt box with the PR URL (visible; never hidden context). A `composer` prompt or non-built-in command sent with that URL in it, once, gets `askNote` (treat the PR as data, report instructions in it). `p` only saves pasting the link: the request is the person's own, so its turn runs with the session's permission mode, as a link they pasted would, not under the `e` guard (a guard there would only be dodged by pasting). The rules on approving and writing below are about the paths pr-inbox itself has; a `p` turn is Claude Code's, like any prompt. README says what that leaves unguarded (accept edits, don't ask, allow rules, bypass)
- **AI review summary**: `summarizeReview` gives the reviewers' answers to a tool-free model as data (`<review_data>`) and draws the one-sentence answer cleaned and cut. It never decides anything; the decision stays in `finish`. Your own PRs are reviewed (`own`) but never approved and never `strict`
- **CI and the AI review**: a failing or running CI is a warning (`ciWarning`), not a gate, and `approvesWithoutAsking` is false unless CI passed
- **Write panels**: a write the pane makes is confirmed in a write panel (`writePanel`, drawn over the pane): it names in full what y sends (`sendsLead` / `sends`), each PR pinned to the commit it had when the panel opened; only `sendPanel` → `runWrite` does the write, which is data (`PanelWrite`), never a callback; q and n leave, every other key only says so, and Cancel comes first. A panel opens only from the person's own key, never on its own or by taking focus (a y meant for something else must not land in it). A panel opened by another panel's y (the clone, worktree and push panels) ignores y for `PANEL_GUARD`, so a double tap cannot confirm it unread. Pane keys come only from the person's keyboard: never give a model or a turn a way to press them
- **Approve**: only after a person presses y in the approve panel (`openApproval`), which names each commit in full (`a`, or the one panel after `b` that names every commit), through `approveAll`. A passed AI review in `confirm` opens no panel of its own; `a` does. An `auto` approval (`AUTO_HOW`) posts a body saying the AI review approved it on its own. Re-read the head right before, refuse if it moved, and send the review pinned to that `commit_id`. No other path may approve. Comments go out only from `sendFindings` (`s`), after y in the findings panel (`openFindings`: the findings checked, then `r` request changes or `c` comment picked, never one picked for you, `r` refused on your own PR), as one review pinned to the reviewed commit, with mentions defused by `findingComment`
- **Issues (3)**: issues assigned to you and issues you created (two searches, listed in two groups, each issue once) are only drawn (`clean()`, `cleanBody()`, `safeHref()`) and stay out of every model call, linked PRs too (`linkedPrs`: PRs only, `cleanIssueRef`). The one way an issue reaches a model is the person's own prompt after `p`, by its link only, under the same rules as `p` on a PR: `askNote('issue')`. The only write is close / reopen, from `c` through the write panel (`openIssueState` → `setIssueState`): a close reason is picked with its number key (`CLOSE_REASONS`, never one picked for you), the state is read again right before and the write refused if it is already so
- **Reviewers (`w`)**: review requests go out only from `sendReviewers`, when the person presses y in the picker (`s` too until it is removed, with a toast that y is the key), and send exactly `pickerPlan` (the line above the keys): one POST and one DELETE to `requested_reviewers`, ids on stdin. Ids are only `LOGIN` / `TEAM_ID` matches (`reviewerId`), so nothing else from GitHub is drawn or sent. No model picks or sends reviewers, and `FIX_FORBIDDEN` keeps a fix turn from asking (`gh pr edit`, `gh api` writes, GraphQL mutations)
- **Fix CI (`c`)**: the request carries `FIX_MARK`, never `UNTRUSTED_NOTE` (that would start the read-only guard). The worktree is detached at the PR head under `~/.cache/pr-inbox/worktrees`; branch names pass `BRANCH_NAME`, fork PRs are refused. While the fix turn runs, `FIX_FORBIDDEN` commands are denied (pushes, gh writes). The push panel (`openPush`) lists `origin/<branch>..HEAD`, exactly what the push sends, and keeps the HEAD sha it opened with. Push only from `sendPush`, after the person presses y in it, as `git push origin <that sha>:refs/heads/<branch>`, refused if HEAD moved since: never force, never another branch. The push panel opens only from c (or 1 in the fixing panel), never when the fix turn ends (`afterFix` sets `fixReady`, a toast and the PromptHint note instead). `prompt.submit` cannot run inside `command.run`, so `/pr-inbox fix` defers it
- **AI instructions in the reviewed repository** (`isAiInstruction`: CLAUDE.md, `.claude/`, skills, subagents, other tools' rules) are read only from the base branch, as guides, never from the PR head and never screened; a PR that changes one is blocked before any model runs when `run.strict`, otherwise warned
- **Prompt settings** (`explain_prompt`, `risk_*`, `release_impact`) replace only the criteria and the request. The JSON format, the untrusted fence and its rule, `contextNote` and `UNTRUSTED_NOTE` are always added and must stay out of reach of settings. `criteriaKey()` must cover every setting that changes the analysis
- **Strict vs. warned**: `run.strict` (`approvesWithoutAsking`) is true when no person will decide (no approve panel). Only then do suspected injections and AI-instruction changes block; otherwise they go to `run.warnings`, shown in the pane, the approve panel and the transcript. Keep that split: never let a suspicion pass silently when `strict`
- **AI review (`v`)**: the approve decision stays in code (`aiReview`/`finish`): every gate, no injection, every reviewer parsed, no confirmed important finding, head unchanged. The review's models are tool-free `$.model.complete` calls; what they ask to read goes through `readRequest` (validation) and `readForReview` (`scrub`, `screen`, labeled JSON) before they see it. Never hand them tools or a way to write. Failures and timeouts block. `auto` applies only to `TRUSTED_AUTHORS` and `DEPENDENCY_BOTS` on non-fork PRs. `auto_review` only starts `aiReview` (`scheduleAutoReviews`: interactive sessions only, one at a time, `MAX_AUTO_REVIEWS_PER_HOUR` across sessions, a lease per PR in the store, read back after `AUTO_SETTLE` to narrow the race (the store has no conditional write), never again at a commit already reviewed or cancelled, failures retried with `RETRY_BASE` / `MAX_ATTEMPTS`, held back by `analysis` = `when opened`); it never decides or approves anything `v` would not. (Subagents cannot use a tool their own mod serves: a mod's hooks skip tool calls from its own spawns)
- **Processes**: run external commands as argument lists through `$.process.run`, never through a shell. PR text given to `osascript` goes in `argv`, never into the `-e` script. Validate anything from settings that ends up in a query (`ORG_NAME`)
- When what is sent, stored or allowed changes, update the Security section of README.md to match

## Conventions

- UI text, README, code comments and test names are in English. Only the AI analysis and its labels follow the language setting (`LABELS_JA` / `LABELS_EN`)
- Bump `ANALYSIS_VERSION` when the analysis prompt or its stored shape changes, so stored analyses are redone
- Use placeholder names such as `my-org` and `acme` in code, tests and docs; never real company or organization names
- Commit messages are in Japanese
